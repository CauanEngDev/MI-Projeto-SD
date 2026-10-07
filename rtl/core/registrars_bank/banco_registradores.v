// Banco de registradores do coprocessador grafico
// Espaco de enderecamento unificado (0-36):
//   0-30  registradores gerais (escrita so via Rd)
//   31    XZR (le 0, escrita descartada)
//   32    CTRL         33  STATUS (somente leitura aqui, vem de status_in)
//   34    SCROLL       35  RASTER_CTRL
//   36    FLAGS        {30'b0, N, Z}
// Leituras combinacionais (2 portas), escrita sincrona, sem forwarding.

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
    wire       is_alu = (opcode >= 5'b00001) && (opcode <= 5'b00110);

    wire [4:0] campo_rd = instrucao[25:21];
    wire [5:0] campo_ra = is_alu ? instrucao[20:15] : instrucao[26:21];
    wire [5:0] campo_rb = is_alu ? instrucao[5:0]   : instrucao[20:15];

    function [31:0] ler;
        input [5:0] addr;
        begin
            case (addr)
                6'd31:   ler = 32'b0;
                6'd32:   ler = reg_ctrl;
                6'd33:   ler = status_in;
                6'd34:   ler = reg_scroll;
                6'd35:   ler = reg_raster;
                6'd36:   ler = {30'b0, reg_n, reg_z};
                default: ler = (addr < 6'd31) ? registradores[addr[4:0]] : 32'b0;
            endcase
        end
    endfunction

    assign read_data_a = ler(campo_ra);
    assign read_data_b = ler(campo_rb);

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