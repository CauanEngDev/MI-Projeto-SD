// ============================================================================
// ESCRAVO AVALON-MM - INTERFACE HPS <-> FILA DE COMANDOS (BUSCA PASSIVA)
// ----------------------------------------------------------------------------
// O que e: a "cola" entre a ponte Lightweight HPS-FPGA (Avalon-MM) e a
// fila_comandos do coprocessador. O ARM faz um acesso de 32 bits a um endereco
// da ponte; este modulo traduz esse acesso em sinais da fila (cmd_wr/cmd_data)
// e devolve o estado do coprocessador na leitura.
//
//   HPS --(Avalon-MM)--> [ avalon_cmd_slave ] --(cmd_wr, cmd_data)--> fila
//                              |   ^
//                              |   +-- cmd_full, cmd_empty, st_*, frame_swap
//                              +-- sw_reset --> reset da fila e da busca
//
// MAPA DE REGISTRADORES (offsets em bytes a partir da base do componente;
// address e endereco de PALAVRA, entao offset = address * 4)
//
//   0x00  CMD     (W)  Cada escrita empurra uma palavra de 32 bits da ISA na
//                      fila. Se a fila estiver cheia (ou em reset por
//                      software) a palavra e DESCARTADA e o bit OVERFLOW do
//                      STATUS e setado. Leitura: 0.
//
//   0x04  STATUS  (R)  [0]     FULL        fila cheia
//                      [1]     EMPTY       fila vazia
//                      [2]     RUNNING     busca nao esta em HALT
//                      [3]     WAITING     instrucao lancada aguardando motor
//                      [4]     VBLANK      apagamento vertical em andamento
//                      [5]     ERROR       opcode invalido / comando rejeitado
//                                          (trava; vem do topo)
//                      [6]     OVERFLOW    escrita descartada em CMD (trava)
//                      [7]     INIT_BUSY   mapas de camadas sendo zerados
//                      [8]     PLL_LOCKED  PLL do VGA travado
//                      [15:9]  0
//                      [31:16] FRAME_COUNT contador de frame_swap (da a volta
//                                          em 65536). Util para o ARM
//                                          sincronizar com os quadros.
//
//   0x08  CTRL    (W)  [0] SOFT_RESET  reseta fila e busca por RESET_CICLOS
//                                      ciclos; tambem zera OVERFLOW e
//                                      FRAME_COUNT.
//                      [1] CLEAR_FLAGS zera OVERFLOW.
//                      Leitura: 0.
//
//   0x0C  ID      (R)  constante ID (confere que a ponte LW esta funcionando
//                      e que o bitstream carregado e o esperado).
//
// REGRAS DE USO (driver no ARM):
//   - Acessos de 32 bits e alinhados (sem byteenable, sem acesso a bytes).
//   - Antes de cada escrita em CMD, ler STATUS e esperar FULL = 0. O modulo
//     NAO usa waitrequest de proposito: com a fila cheia e o video parado
//     (PLL sem lock, vblank que nao chega) a busca para de consumir, e um
//     waitrequest preso travaria o barramento do ARM.
//   - ERROR e OVERFLOW sao travas: so saem com SOFT_RESET (ERROR so sai com
//     o reset do topo; ver nota abaixo) ou CLEAR_FLAGS (so OVERFLOW).
//
// PROPRIEDADES DA INTERFACE (componente customizado no Platform Designer):
//   - Avalon Memory Mapped Slave, clock = CLOCK_50 (mesmo da logica do
//     coprocessador; sem cruzamento de dominio de clock).
//   - Reset: ativo em 1 (alinhado ao "reset" do coprocessador). Se o Qsys
//     entregar reset_n, inverta na instancia.
//   - readLatency = 1 (readdata registrado, sem readdatavalid),
//     writeWaitTime = 0, readWaitTime = 0, sem waitrequest.
//   - addressUnits = WORDS, 2 bits de endereco, dados de 32 bits.
//
// LIGACAO NO TOPO:
//   - cmd_wr/cmd_data/cmd_full/cmd_empty: portas homonimas do coprocessador.
//   - sw_reset: fazer OR com o reset da fila e da busca no topo (o reset da
//     fila hoje e so o da placa). O reset dos motores e das RAMs pode ficar
//     como esta.
//   - st_error: err_latch do topo (invalid_opcode | cmd_error). Ele so e
//     limpo pelo reset da placa; para limpar por software, inclua sw_reset
//     na condicao de reset do err_latch no topo.
// ============================================================================

module avalon_cmd_slave #(
    parameter [31:0] ID           = 32'hC0DE_0001, // identificacao lida em 0x0C
    parameter        RESET_CICLOS = 4              // duracao do sw_reset (>= 1)
) (
    input  wire        clk,
    input  wire        reset,          // reset sincrono (ativo em 1)

    // ------------------------------------------------------------------------
    // Lado Avalon-MM (escravo)
    // ------------------------------------------------------------------------
    input  wire [1:0]  address,        // endereco de palavra (offset / 4)
    input  wire        write,
    input  wire [31:0] writedata,
    input  wire        read,
    output reg  [31:0] readdata,       // valido 1 ciclo apos read (latencia 1)

    // ------------------------------------------------------------------------
    // Lado do coprocessador (fila de comandos)
    // ------------------------------------------------------------------------
    output wire        cmd_wr,         // grava cmd_data na fila
    output wire [31:0] cmd_data,
    input  wire        cmd_full,
    input  wire        cmd_empty,

    // ------------------------------------------------------------------------
    // Status vindo do topo (todos no dominio de clk)
    // ------------------------------------------------------------------------
    input  wire        st_running,
    input  wire        st_waiting,
    input  wire        st_vblank,
    input  wire        st_error,
    input  wire        st_init_busy,
    input  wire        st_pll_locked,
    input  wire        frame_swap,     // pulso de troca de buffers

    // ------------------------------------------------------------------------
    // Reset por software (nivel alto durante RESET_CICLOS ciclos)
    // ------------------------------------------------------------------------
    output wire        sw_reset
);

    // ------------------------------------------------------------------------
    // Enderecos (em palavras)
    // ------------------------------------------------------------------------
    localparam [1:0] ADDR_CMD    = 2'd0;
    localparam [1:0] ADDR_STATUS = 2'd1;
    localparam [1:0] ADDR_CTRL   = 2'd2;
    localparam [1:0] ADDR_ID     = 2'd3;

    // ------------------------------------------------------------------------
    // Decodificacao dos acessos de escrita
    // ------------------------------------------------------------------------
    wire wr_cmd  = write & (address == ADDR_CMD);
    wire wr_ctrl = write & (address == ADDR_CTRL);

    wire ctrl_soft_reset  = wr_ctrl & writedata[0];
    wire ctrl_clear_flags = wr_ctrl & writedata[1];

    // ------------------------------------------------------------------------
    // Reset por software: pulso esticado por RESET_CICLOS ciclos.
    // Esticar garante que a fila e a busca (que dependem de reset sincrono)
    // vejam o reset por tempo suficiente.
    // ------------------------------------------------------------------------
    localparam CNT_W = $clog2(RESET_CICLOS + 1);

    reg [CNT_W-1:0] rst_cnt;

    always @(posedge clk) begin
        if (reset)
            rst_cnt <= {CNT_W{1'b0}};
        else if (ctrl_soft_reset)
            rst_cnt <= RESET_CICLOS[CNT_W-1:0];
        else if (rst_cnt != {CNT_W{1'b0}})
            rst_cnt <= rst_cnt - 1'b1;
    end

    assign sw_reset = (rst_cnt != {CNT_W{1'b0}});

    // ------------------------------------------------------------------------
    // Escrita na fila
    // Gate: so passa a palavra se ha espaco e nao ha reset por software em
    // andamento. A fila ja ignora escrita com full, mas filtrar aqui permite
    // detectar e sinalizar o descarte (OVERFLOW).
    // ------------------------------------------------------------------------
    assign cmd_wr   = wr_cmd & ~cmd_full & ~sw_reset;
    assign cmd_data = writedata;

    // ------------------------------------------------------------------------
    // OVERFLOW (trava): escrita em CMD que foi descartada.
    // Prioridade: limpeza (reset, SOFT_RESET, CLEAR_FLAGS) > novo descarte.
    // ------------------------------------------------------------------------
    reg overflow;

    always @(posedge clk) begin
        if (reset)
            overflow <= 1'b0;
        else if (ctrl_soft_reset | ctrl_clear_flags)
            overflow <= 1'b0;
        else if (wr_cmd & (cmd_full | sw_reset))
            overflow <= 1'b1;
    end

    // ------------------------------------------------------------------------
    // FRAME_COUNT: quantos frame_swap ja ocorreram desde o reset
    // ------------------------------------------------------------------------
    reg [15:0] frame_count;

    always @(posedge clk) begin
        if (reset | ctrl_soft_reset)
            frame_count <= 16'd0;
        else if (frame_swap)
            frame_count <= frame_count + 1'b1;
    end

    // ------------------------------------------------------------------------
    // Palavra de STATUS
    // ------------------------------------------------------------------------
    wire [31:0] status_word = {
        frame_count,        // [31:16]
        7'b0,               // [15:9]
        st_pll_locked,      // [8]
        st_init_busy,       // [7]
        overflow,           // [6]
        st_error,           // [5]
        st_vblank,          // [4]
        st_waiting,         // [3]
        st_running,         // [2]
        cmd_empty,          // [1]
        cmd_full            // [0]
    };

    // ------------------------------------------------------------------------
    // Leitura (readdata registrado: latencia 1)
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (read) begin
            case (address)
                ADDR_STATUS: readdata <= status_word;
                ADDR_ID:     readdata <= ID;
                default:     readdata <= 32'd0;   // CMD e CTRL leem 0
            endcase
        end
    end

endmodule