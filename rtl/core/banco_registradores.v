// Banco de registradores do coprocessador grafico
// Espaco de enderecamento unificado (0-43):
//   0-30  registradores gerais (escrita so via Rd)
//   31    XZR (le 0, escrita descartada)
//   32    sem uso (le 0)       34-35 sem uso (leem 0)
//   33    STATUS (somente leitura, vem de status_in)
//   36    FLAGS  {30'b0, N, Z} (escrito apenas pela ULA)
//   37    V0X (9 bits)   38 V0Y (8 bits)
//   39    V1X (9 bits)   40 V1Y (8 bits)
//   41    V2X (9 bits)   42 V2Y (8 bits)
//   43    COLOR {palette_sel, indice} (9 bits)
//   44-63 sem uso (leem 0, escrita descartada)
//
// Os registradores 37-43 alimentam direto o rasterizador (DRAW_RECT usa
// V0/V1, DRAW_TRI usa V0/V1/V2; ambos usam COLOR). Sao escritos pela ULA
// como qualquer outro (PASS, ADD, ...) e lidos como registradores comuns.
// Guardam so a largura do campo; a leitura devolve o valor zero-extendido.
//
// Rd com 6 bits: Rd = {instrucao[14], instrucao[25:21]}. O bit 14 estava
// reservado no formato A; programas antigos (bit 14 = 0) seguem validos.
//
// Leituras combinacionais (2 portas), escrita sincrona, sem forwarding.

module banco_registradores (
    input  wire         clk,
    input  wire         reset,
    input  wire [31:0]  instrucao,

    // Escrita em Rd, vinda do write-back da ULA
    input  wire         write_enable,
    input  wire [31:0]  write_data,

    // Portas de leitura
    output wire [31:0]  read_data_a,
    output wire [31:0]  read_data_b,

    // Parametros do rasterizador (registradores 37-43)
    output wire [8:0]   v0x,
    output wire [7:0]   v0y,
    output wire [8:0]   v1x,
    output wire [7:0]   v1y,
    output wire [8:0]   v2x,
    output wire [7:0]   v2y,
    output wire [7:0]   color_index,
    output wire         palette_sel,

    // STATUS e escrito pelo hardware (nao armazenado aqui)
    input  wire [31:0]  status_in,

    // FLAGS: captura z e n da ULA quando flags_we = 1 (ligar em done)
    input  wire         flags_we,
    input  wire         flag_z,
    input  wire         flag_n,

    output wire [31:0]  flags
);

    // Enderecos dos registradores dedicados
    localparam [5:0] R_V0X   = 6'd37,
                     R_V0Y   = 6'd38,
                     R_V1X   = 6'd39,
                     R_V1Y   = 6'd40,
                     R_V2X   = 6'd41,
                     R_V2Y   = 6'd42,
                     R_COLOR = 6'd43;

    reg [31:0] registradores [0:30];
    reg [8:0]  reg_v0x, reg_v1x, reg_v2x;
    reg [7:0]  reg_v0y, reg_v1y, reg_v2y;
    reg [8:0]  reg_color;
    reg        reg_z;
    reg        reg_n;

    // Decodificacao dos campos conforme o layout do documento
    //   Formato A (ULA): Rd=[14,25:21] (6 bits), Rn=[20:15], Rm=[5:0]
    //   Formato G:       Ra=[26:21], Rb=[20:15]
    wire [4:0] opcode = instrucao[31:27];
    wire       is_alu = (opcode >= 5'b00001) && (opcode <= 5'b00110);

    wire [5:0] campo_rd = {instrucao[14], instrucao[25:21]};
    wire [5:0] campo_ra = is_alu ? instrucao[20:15] : instrucao[26:21];
    wire [5:0] campo_rb = is_alu ? instrucao[5:0]   : instrucao[20:15];

    // Leitura: vetor com todo o espaco de enderecos (0-63)
    wire [31:0] rf [0:63];

    genvar g;
    generate
        for (g = 0; g < 31; g = g + 1) begin : G_RF_GERAL
            assign rf[g] = registradores[g];
        end
        for (g = 44; g < 64; g = g + 1) begin : G_RF_SEM_USO
            assign rf[g] = 32'b0;
        end
    endgenerate

    assign rf[31] = 32'b0;
    assign rf[32] = 32'b0;
    assign rf[33] = status_in;
    assign rf[34] = 32'b0;
    assign rf[35] = 32'b0;
    assign rf[36] = {30'b0, reg_n, reg_z};
    assign rf[37] = {23'b0, reg_v0x};
    assign rf[38] = {24'b0, reg_v0y};
    assign rf[39] = {23'b0, reg_v1x};
    assign rf[40] = {24'b0, reg_v1y};
    assign rf[41] = {23'b0, reg_v2x};
    assign rf[42] = {24'b0, reg_v2y};
    assign rf[43] = {23'b0, reg_color};

    assign read_data_a = rf[campo_ra];
    assign read_data_b = rf[campo_rb];

    // Saidas dedicadas ao rasterizador
    assign v0x         = reg_v0x;
    assign v0y         = reg_v0y;
    assign v1x         = reg_v1x;
    assign v1y         = reg_v1y;
    assign v2x         = reg_v2x;
    assign v2y         = reg_v2y;
    assign color_index = reg_color[7:0];
    assign palette_sel = reg_color[8];

    assign flags = {30'b0, reg_n, reg_z};

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 31; i = i + 1)
                registradores[i] <= 32'b0;
            reg_v0x   <= 9'b0;  reg_v0y <= 8'b0;
            reg_v1x   <= 9'b0;  reg_v1y <= 8'b0;
            reg_v2x   <= 9'b0;  reg_v2y <= 8'b0;
            reg_color <= 9'b0;
            reg_z     <= 1'b0;
            reg_n     <= 1'b0;
        end
        else begin
            if (write_enable) begin
                if (campo_rd < 6'd31)
                    registradores[campo_rd[4:0]] <= write_data;
                else begin
                    case (campo_rd)
                        R_V0X:   reg_v0x   <= write_data[8:0];
                        R_V0Y:   reg_v0y   <= write_data[7:0];
                        R_V1X:   reg_v1x   <= write_data[8:0];
                        R_V1Y:   reg_v1y   <= write_data[7:0];
                        R_V2X:   reg_v2x   <= write_data[8:0];
                        R_V2Y:   reg_v2y   <= write_data[7:0];
                        R_COLOR: reg_color <= write_data[8:0];
                        default: ;   // 31-36 e 44-63: escrita descartada
                    endcase
                end
            end

            if (flags_we) begin
                reg_z <= flag_z;
                reg_n <= flag_n;
            end
        end
    end

endmodule