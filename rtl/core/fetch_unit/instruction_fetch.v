// ============================================================================
// INSTRUCTION FETCH - COPROCESSADOR GRAFICO
// ----------------------------------------------------------------------------
// Reaproveita Program_counter, Adder e instruction_memory sem alteracao.
//
// Busca ativa: a unidade mantem o PC e o endereco da memoria por conta propria
// e apresenta a instrucao corrente a cada ciclo. O PC (em bytes, PC + 4) so
// avanca quando a instrucao corrente termina.
//
// Politica de execucao (sem instrucoes de desvio):
//   - Instrucoes de um ciclo (ULA, SET_*, WRITE_*, SCROLL_BG, NOP):
//       executam no primeiro ciclo valido e o PC avanca no mesmo ciclo.
//   - Bloqueantes por DONE (DRAW_RECT, DRAW_TRI, DRAW_BG, DRAW_SPRITES):
//       um pulso "execute" dispara o motor e o PC espera engine_done.
//   - WAIT_VBLANK: o PC espera a proxima borda de subida de vblank.
//   - HALT: encerra o programa. Com LOOP_AUTO = 1 o programa reinicia sozinho
//       no proximo vblank; com LOOP_AUTO = 0 so retoma com "start" ou reset.
//   - Fim da memoria sem HALT: tratado como HALT (o PC nao da a volta).
//   - Opcodes reservados (10100 a 11111): tratados como NOP e sinalizados.
//
// Double buffer: o HALT marca o fim do frame. Quando o vblank chega, a saida
// frame_swap pulsa e o topo troca os bancos do framebuffer, de modo que o
// programa nao precisa de uma instrucao de troca.
//
// Reinicio automatico (LOOP_AUTO = 1): como o reinicio ja acontece na borda
// de vblank, o programa NAO deve comecar com WAIT_VBLANK (esperaria um frame
// inteiro a mais). Use WAIT_VBLANK apenas no meio do programa.
//
// Programa: sem HPS, o conteudo vem do init_file (.mif) da instruction_memory.
//
// Suposicoes sobre sinais externos:
//   - engine_done e um pulso (ou nivel que cai ao aceitar novo disparo) e
//     chega pelo menos 1 ciclo depois do pulso "execute".
//   - vblank ja esta sincronizado ao dominio de clk.
// ============================================================================

// ------------------------------------------------------------------------
// Opcodes que a unidade de busca precisa reconhecer. Os demais opcodes
// validos executam em um ciclo e o PC avanca.
// ------------------------------------------------------------------------
`include "rtl/include/isa.vh"

module unidade_de_busca_de_instrucoes #(
    parameter LAT_MEM      = 2, // latencia de leitura da instruction_memory:
                                //   2 = com registrador de saida em q (como gerada)
                                //   1 = sem registrador de saida
    parameter INICIAR_AUTO = 1, // 1: executa logo apos o reset
                                // 0: espera o pulso "start"
    parameter LOOP_AUTO    = 1  // 1: reinicia o programa no proximo vblank apos
                                //    HALT ou fim da memoria
                                // 0: so reinicia com "start" ou reset
) (
    input  wire        clk,            // clock do sistema
    input  wire        reset,          // reset sincrono (ativo em 1)

    // Controle externo
    input  wire        start,          // pulso: volta o PC a 0 e inicia
                                       // (ex.: botao da placa)

    // Handshake com os motores e com o VGA
    input  wire        engine_done,    // fim da operacao do motor atual
                                       // (vem da unidade de controle)
    input  wire        vblank,         // 1 durante o apagamento vertical

    // Saidas para a unidade de controle e para o banco de registradores
    output wire [15:0] pc,             // contador de programa (em bytes)
    output wire [31:0] instruction,    // instrucao corrente
    output wire        execute,        // pulso de 1 ciclo: lancar a instrucao

    // Status
    output wire        frame_swap,     // pulso: frame pronto e vblank chegou
                                       // (trocar os bancos do framebuffer)
    output wire        running,        // 1 enquanto o programa roda
    output wire        waiting,        // 1 enquanto o PC espera um evento
    output wire        invalid_opcode  // pulso: opcode reservado executado
);

    // ------------------------------------------------------------------------
    // Estado interno
    // ------------------------------------------------------------------------
    reg halted;     // 1 = busca parada
    reg prog_done;  // 1 = programa terminou (HALT ou fim da memoria); habilita
                    //     o reinicio automatico. Fica 0 enquanto espera o
                    //     primeiro "start" (INICIAR_AUTO = 0).
    reg issued;     // 1 = a instrucao corrente ja foi lancada e esta em espera
    reg vblank_d;   // vblank atrasado 1 ciclo, para detectar a borda
    reg bubble;     // 1 = saida da memoria ainda nao corresponde ao PC atual

    // ------------------------------------------------------------------------
    // Classificacao da instrucao corrente pelo opcode (bits 31:27)
    // ------------------------------------------------------------------------
    wire [4:0] opcode = instruction[31:27];

    // Instrucoes que seguram o PC ate engine_done
    wire is_blocking = (opcode == DRR)  ||
                       (opcode == DRT)  ||
                       (opcode == DRB)  ||
                       (opcode == DRS);

    wire is_wait_vblank = (opcode == WVB); // espera borda de vblank
    wire is_halt        = (opcode == HALT);        // encerra o programa
    wire is_invalid     = (opcode >  HALT);        // opcode reservado

    // ------------------------------------------------------------------------
    // Borda de subida de vblank (inicio do apagamento vertical)
    // ------------------------------------------------------------------------
    wire vblank_rise = vblank & ~vblank_d;

    // ------------------------------------------------------------------------
    // Reinicio do programa: pulso start externo ou reinicio automatico
    // (programa terminado + proxima borda de vblank).
    // ------------------------------------------------------------------------
    wire auto_restart = (LOOP_AUTO != 0) & prog_done & vblank_rise;
    wire restart      = start | auto_restart;

    // ------------------------------------------------------------------------
    // Pulso de execucao
    // "active" bloqueia a execucao durante reset, durante o reinicio (a saida
    // da memoria ainda e a instrucao antiga), enquanto a busca esta parada e
    // durante a bolha de latencia da memoria. O pulso sai uma unica vez por
    // instrucao, no primeiro ciclo valido (issued = 0).
    // ------------------------------------------------------------------------
    wire active = ~halted & ~reset & ~restart & ~bubble;
    assign execute = active & ~issued;

    // ------------------------------------------------------------------------
    // Conclusao da instrucao corrente (condicao para o PC avancar)
    //   - bloqueante: apos lancada (issued) e com engine_done = 1
    //   - WAIT_VBLANK: na borda de subida de vblank
    //   - HALT: nunca avanca
    //   - demais: conclui no proprio ciclo de execucao
    // ------------------------------------------------------------------------
    wire finished = is_blocking    ? (issued & engine_done) :
                    is_wait_vblank ? vblank_rise            :
                    is_halt        ? 1'b0                   :
                                     execute;

    wire advance = active & finished;

    // ------------------------------------------------------------------------
    // Proximo PC (em bytes)
    //   - reset ou restart: volta a 0
    //   - advance: PC + 4, exceto na ultima palavra (nao da a volta; o
    //     programa termina)
    //   - caso contrario: mantem (stall)
    // ------------------------------------------------------------------------
    wire [15:0] pc_plus4;
    wire        last_word = &pc[15:2]; // PC na ultima palavra da memoria
    wire [15:0] pc_next = (reset | restart)         ? 16'd0    :
                          (advance & ~last_word)    ? pc_plus4 :
                                                      pc;

    // Program Counter (modulo original)
    Program_counter pc_register(
        .clk(clk),
        .reset(reset),
        .in(pc_next),
        .out(pc)
    );

    // PC + 4 (modulo original)
    Adder pc_adder(
        .a(pc),
        .b(16'd4),
        .out(pc_plus4)
    );

    // ------------------------------------------------------------------------
    // Memoria de instrucoes (modulo original, 16384 x 32 bits), somente leitura.
    // O endereco enviado e o do PROXIMO PC: a memoria registra o endereco
    // na mesma borda em que o PC e atualizado, o que elimina uma bolha de
    // latencia.
    // ------------------------------------------------------------------------
    instruction_memory instruction_mem(
        .address(pc_next[15:2]),   // bytes -> indice da palavra
        .clock(clk),
        .data(32'b0),
        .wren(1'b0),
        .q(instruction)
    );

    // ------------------------------------------------------------------------
    // Bolha de latencia
    // Com LAT_MEM = 2 (q registrado), apos cada mudanca de PC a instrucao
    // correta so aparece em q um ciclo depois. Esse ciclo e marcado como
    // bolha e nada executa nele. Com LAT_MEM = 1 nao ha bolha.
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset | restart | advance)
            bubble <= (LAT_MEM == 2);
        else
            bubble <= 1'b0;
    end

    // ------------------------------------------------------------------------
    // Registradores de estado (halted, prog_done, issued, vblank_d)
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        vblank_d <= vblank;

        if (reset) begin
            issued    <= 1'b0;
            halted    <= (INICIAR_AUTO == 0);
            prog_done <= 1'b0;
        end
        else if (restart) begin
            issued    <= 1'b0;
            halted    <= 1'b0;
            prog_done <= 1'b0;
        end
        else begin
            // Ao avancar, a proxima instrucao ainda nao foi lancada. Ao lancar
            // uma instrucao que fica em espera, marca-se como issued.
            if (advance)
                issued <= 1'b0;
            else if (execute)
                issued <= 1'b1;

            // HALT e fim da memoria encerram o programa
            if (execute & is_halt) begin
                halted    <= 1'b1;
                prog_done <= 1'b1;
            end
            if (advance & last_word) begin
                halted    <= 1'b1;
                prog_done <= 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Saidas de status
    // ------------------------------------------------------------------------
    // Pulso de troca de buffers: o programa terminou (HALT) e o vblank chegou.
    // E o mesmo instante do reinicio automatico, entao o proximo frame ja sera
    // desenhado no banco trocado.
    assign frame_swap     = auto_restart & ~start & ~reset;

    assign running        = ~halted;
    assign waiting        = issued & ~halted;
    assign invalid_opcode = execute & is_invalid;

endmodule