// Banco de registradores do coprocessador grafico
// Espaco de enderecamento unificado (0-36):
//   0-30  registradores gerais (escrita so via Rd)
//   31    XZR (le 0, escrita descartada)
//   32    CTRL         33  STATUS (somente leitura aqui, vem de status_in)
//   34    SCROLL       35  RASTER_CTRL
//   36    FLAGS        {30'b0, N, Z}
// Leituras combinacionais (2 portas), escrita sincrona, sem forwarding.

`include "rtl/include/isa.vh"

module banco_registradores (
    input  wire         clk,
    input  wire         reset,
    input  wire [31:0]  instrucao,

    // Escrita em Rd (0-30), vinda do write-back
    input  wire         write_enable,
    input  wire [31:0]  write_data,

    // Portas de leitura
    output wire [31:0]  read_data_a,
    output wire [31:0]  read_data_b,

    // R7..R0 concatenados, para o rasterizador capturar os argumentos
    output wire [255:0] args,

    // Registradores de controle: cada um tem sua propria porta de escrita;
    // quem as aciona (HPS via LSU, instrucao) e decidido fora deste modulo
    input  wire         ctrl_we,
    input  wire [31:0]  ctrl_wdata,
    input  wire         scroll_we,
    input  wire [31:0]  scroll_wdata,
    input  wire         raster_we,
    input  wire [31:0]  raster_wdata,

    // STATUS e escrito pelo hardware (nao armazenado aqui)
    input  wire [31:0]  status_in,

    // FLAGS: captura z e n da ULA quando flags_we = 1 (ligar em done)
    input  wire         flags_we,
    input  wire         flag_z,
    input  wire         flag_n,

    output wire [31:0]  ctrl,
    output wire [31:0]  scroll,
    output wire [31:0]  raster_ctrl,
    output wire [31:0]  flags
);

    reg [31:0] registradores [0:30];
    reg [31:0] reg_ctrl;
    reg [31:0] reg_scroll;
    reg [31:0] reg_raster;
    reg        reg_z;
    reg        reg_n;

    // Decodificacao dos campos conforme o layout do documento
    //   Formato A (ULA): Rd=[25:21], Rn=[20:15], Rm=[5:0]
    //   Formato G:       Ra=[26:21], Rb=[20:15]
    wire [4:0] opcode = instrucao[31:27];
    wire       is_alu = (opcode >= ADD) && (opcode <= PASS);

    wire [4:0] campo_rd = instrucao[25:21];
    wire [5:0] campo_ra = is_alu ? instrucao[20:15] : instrucao[26:21];
    wire [5:0] campo_rb = is_alu ? instrucao[5:0]   : instrucao[20:15];

    // Leitura: vetor com todo o espaco de enderecos (0-63). Cada posicao e
    // ligada por assign a um registrador fixo, de modo que a saida acompanha
    // qualquer mudanca de valor (inclusive em simulacao).
    //   0-30 gerais | 31 XZR | 32 CTRL | 33 STATUS | 34 SCROLL |
    //   35 RASTER_CTRL | 36 FLAGS | 37-63 sem uso (leem 0)
    wire [31:0] rf [0:63];

    genvar g;
    generate
        for (g = 0; g < 31; g = g + 1) begin : G_RF_GERAL
            assign rf[g] = registradores[g];
        end
        for (g = 37; g < 64; g = g + 1) begin : G_RF_SEM_USO
            assign rf[g] = 32'b0;
        end
    endgenerate

    assign rf[31] = 32'b0;
    assign rf[32] = reg_ctrl;
    assign rf[33] = status_in;
    assign rf[34] = reg_scroll;
    assign rf[35] = reg_raster;
    assign rf[36] = {30'b0, reg_n, reg_z};

    assign read_data_a = rf[campo_ra];
    assign read_data_b = rf[campo_rb];

    assign args = {registradores[7], registradores[6], registradores[5], registradores[4],
                   registradores[3], registradores[2], registradores[1], registradores[0]};

    assign ctrl        = reg_ctrl;
    assign scroll      = reg_scroll;
    assign raster_ctrl = reg_raster;
    assign flags       = {30'b0, reg_n, reg_z};

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 31; i = i + 1)
                registradores[i] <= 32'b0;
            reg_ctrl   <= 32'b0;
            reg_scroll <= 32'b0;
            reg_raster <= 32'b0;
            reg_z      <= 1'b0;
            reg_n      <= 1'b0;
        end
        else begin
            if (write_enable && campo_rd != 5'd31)
                registradores[campo_rd] <= write_data;

            if (ctrl_we)   reg_ctrl   <= ctrl_wdata;
            if (scroll_we) reg_scroll <= scroll_wdata;
            if (raster_we) reg_raster <= raster_wdata;

            if (flags_we) begin
                reg_z <= flag_z;
                reg_n <= flag_n;
            end
        end
    end

endmodule