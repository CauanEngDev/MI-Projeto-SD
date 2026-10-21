// ============================================================================
// UNIDADE DE BUSCA PASSIVA - COPROCESSADOR GRAFICO
// ----------------------------------------------------------------------------
// Busca passiva: as instrucoes nao vem de uma memoria interna. O HPS (ARM)
// escreve palavras de 32 bits da ISA numa FIFO (via MMIO) e esta unidade as
// consome uma por vez. Nao existe PC: o HPS faz o papel dele. A cabeca da
// FIFO (modo show-ahead) funciona como registrador de instrucao e fica
// estavel ate a instrucao terminar.
//
// Substitui a unidade_de_busca_de_instrucoes (busca ativa: ROM + PC) com as
// mesmas saidas para a unidade de controle, entao o resto do coprocessador
// nao muda e a ISA e preservada.
//
// Politica de execucao (a mesma da busca ativa):
//   - Instrucoes de um ciclo (ULA, SET_*, WRITE_*, SCROLL_BG, NOP):
//       executam no primeiro ciclo valido e saem da FIFO no mesmo ciclo.
//   - Bloqueantes por DONE (DRAW_RECT, DRAW_TRI, DRAW_BG, DRAW_SPRITES):
//       um pulso "execute" dispara o motor e a instrucao fica na cabeca da
//       FIFO ate engine_done.
//   - WAIT_VBLANK: segura a busca ate a proxima borda de subida de vblank.
//   - HALT: fim do quadro. A busca para; na proxima borda de vblank o HALT e
//       descartado da FIFO, frame_swap pulsa e a busca segue com as palavras
//       do proximo quadro.
//   - Opcodes invalidos (maiores que HALT): nao disparam nada, sao descartados
//       e sinalizam invalid_opcode. Isso inclui os desvios B e B_COND (10100 e
//       10101): sem PC nao ha para onde desviar, eles so valem na busca ativa.
//
// FIFO vazia: a busca apenas espera. Se a FIFO esvaziar no meio de um quadro,
// o frame_swap so ocorre quando o HALT chegar, e a tela continua mostrando o
// quadro anterior (sem tearing).
//
// Double buffer: o HALT marca o fim do quadro e o frame_swap pulsa no vblank
// seguinte (o topo troca os bancos do framebuffer). Como o banco de tras guarda
// o quadro de dois frames atras, o programa do HPS deve redesenhar a tela
// inteira a cada quadro (comecar por DRAW_BG ou por um DRAW_RECT que a cubra).
//
// Requisitos da FIFO:
//   - Modo show-ahead: fifo_q mostra a cabeca da fila sem precisar de rdreq.
//   - fifo_empty = 0 implica fifo_q valido no mesmo ciclo.
//
// Portas sem uso: "start" e "flags" existem so para manter a mesma interface
// da busca ativa (a troca no topo e apenas o nome da instancia). Sao ignoradas.
//
// Suposicoes sobre sinais externos:
//   - engine_done e um pulso (ou nivel que cai ao aceitar novo disparo) e
//     chega pelo menos 1 ciclo depois do pulso "execute".
//   - vblank ja esta sincronizado ao dominio de clk.
// ============================================================================

'include "rtl/core/include/isa.vh"

module unidade_de_busca_passiva (
    input  wire        clk,            // clock do sistema
    input  wire        reset,          // reset sincrono (ativo em 1)

    // Controle externo
    input  wire        start,          // nao usado (compatibilidade com a busca
                                       // ativa)

    // Handshake com os motores e com o VGA
    input  wire        engine_done,    // fim da operacao do motor atual
                                       // (vem da unidade de controle)
    input  wire        vblank,         // 1 durante o apagamento vertical
    input  wire [3:0]  flags,          // nao usado: so os desvios usavam, e
                                       // eles nao existem na busca passiva

    // Interface com a FIFO de comandos (escrita feita pelo HPS via MMIO)
    input  wire        fifo_empty,     // 1 = nao ha instrucao na FIFO
    input  wire [31:0] fifo_q,         // cabeca da FIFO (show-ahead)
    output wire        fifo_rd,        // pop: descarta a instrucao da cabeca

    // Saidas para a unidade de controle e para o banco de registradores
    output wire [15:0] pc,             // sempre 0 (nao ha PC; mantido para
                                       // compatibilidade com o topo)
    output wire [31:0] instruction,    // instrucao corrente (cabeca da FIFO)
    output wire        execute,        // pulso de 1 ciclo: lancar a instrucao

    // Status
    output wire        frame_swap,     // pulso: frame pronto e vblank chegou
                                       // (trocar os bancos do framebuffer)
    output wire        running,        // 1 enquanto a busca nao esta em HALT
    output wire        waiting,        // 1 enquanto uma instrucao lancada espera
                                       // a conclusao
    output wire        invalid_opcode  // pulso: opcode invalido executado
);

    // ------------------------------------------------------------------------
    // Opcodes que a unidade de busca precisa reconhecer. Os demais opcodes
    // validos executam em um ciclo e saem da FIFO no mesmo ciclo.
    // ------------------------------------------------------------------------
    localparam [4:0] DRR    = 5'b01000;
    localparam [4:0] DRT     = 5'b01001;
    localparam [4:0] DRB      = 5'b10000;
    localparam [4:0] DRS = 5'b10001;
    localparam [4:0] WVB  = 5'b10010;
    localparam [4:0] HALT         = 5'b10011; // ultimo opcode valido

    // ------------------------------------------------------------------------
    // Estado interno
    // ------------------------------------------------------------------------
    reg halted;     // 1 = busca parada (HALT executado, esperando o vblank)
    reg prog_done;  // 1 = HALT executado: o quadro acabou e falta o vblank para
                    //     fecha-lo (habilita o "libera")
    reg issued;     // 1 = a instrucao corrente ja foi lancada e esta em espera
    reg vblank_d;   // vblank atrasado 1 ciclo, para detectar a borda

    // ------------------------------------------------------------------------
    // Classificacao da instrucao corrente pelo opcode (bits 31:27)
    // ------------------------------------------------------------------------
    wire [4:0] opcode = instruction[31:27];

    // Instrucoes que seguram a FIFO ate engine_done
    wire is_blocking = (opcode == DRR)    ||
                       (opcode == DRT)    ||
                       (opcode == DRB)    ||
                       (opcode == DRS);

    wire is_wait_vblank = (opcode == WVB);  // espera borda de vblank
    wire is_halt        = (opcode == HALT); // encerra o quadro
    wire is_invalid     = (opcode >  HALT);

    // ------------------------------------------------------------------------
    // Borda de subida de vblank (inicio do apagamento vertical)
    // ------------------------------------------------------------------------
    wire vblank_rise = vblank & ~vblank_d;

    // ------------------------------------------------------------------------
    // Liberacao do HALT: o quadro terminou (HALT executado) e o vblank chegou.
    // E o instante de descartar o HALT da FIFO, trocar os buffers e seguir
    // para o proximo quadro. Substitui o "restart" da busca ativa.
    // ------------------------------------------------------------------------
    wire libera = prog_done & vblank_rise;

    // ------------------------------------------------------------------------
    // Pulso de execucao
    // "active" so permite executar com instrucao disponivel (FIFO nao vazia),
    // fora de reset e fora do HALT. O pulso sai uma unica vez por instrucao,
    // no primeiro ciclo valido (issued = 0).
    // ------------------------------------------------------------------------
    wire active = ~halted & ~reset & ~fifo_empty;
    assign execute = active & ~issued;

    // ------------------------------------------------------------------------
    // Conclusao da instrucao corrente (condicao para sair da FIFO)
    //   - bloqueante: apos lancada (issued) e com engine_done = 1
    //   - WAIT_VBLANK: na borda de subida de vblank
    //   - HALT: nunca conclui aqui (sai da FIFO pelo "libera")
    //   - demais: conclui no proprio ciclo de execucao
    // ------------------------------------------------------------------------
    wire finished = is_blocking    ? (issued & engine_done) :
                    is_wait_vblank ? vblank_rise            :
                    is_halt        ? 1'b0                   :
                                     execute;

    wire advance = active & finished;

    // ------------------------------------------------------------------------
    // Registradores de estado (halted, prog_done, issued, vblank_d)
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        vblank_d <= vblank;

        if (reset) begin
            issued    <= 1'b0;
            halted    <= 1'b0;
            prog_done <= 1'b0;
        end
        else if (libera) begin
            // Quadro fechado: a proxima instrucao da FIFO ainda nao foi lancada
            issued    <= 1'b0;
            halted    <= 1'b0;
            prog_done <= 1'b0;
        end
        else begin
            // Ao concluir, a proxima instrucao ainda nao foi lancada. Ao lancar
            // uma instrucao que fica em espera, marca-se como issued.
            if (advance)
                issued <= 1'b0;
            else if (execute)
                issued <= 1'b1;

            // HALT encerra o quadro: para a busca ate o proximo vblank
            if (execute & is_halt) begin
                halted    <= 1'b1;
                prog_done <= 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Saidas
    // ------------------------------------------------------------------------
    // A cabeca da FIFO e a instrucao corrente (estavel ate o pop).
    assign instruction = fifo_q;

    // Pop da FIFO: instrucao concluida (advance) ou, no vblank, descarte do
    // HALT que esta na cabeca (libera). Os dois nunca ocorrem juntos, pois
    // advance exige ~halted e libera exige o HALT ja executado.
    assign fifo_rd = advance | libera;

    // Nao ha PC na busca passiva
    assign pc = 16'd0;

    // Pulso de troca de buffers: o quadro terminou (HALT) e o vblank chegou.
    // E o mesmo instante do "libera", entao o proximo quadro ja sera desenhado
    // no banco trocado.
    assign frame_swap = libera & ~reset;

    assign running        = ~halted;
    assign waiting        = issued & ~halted;
    assign invalid_opcode = execute & is_invalid;

endmodule