module LSU #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32   // padrão Avalon-MM; só os 9 LSBs importam pro tile
)(
    input  wire                  clock,
    input  wire                  reset,

    // ---- Avalon-MM Slave (lado do processador/HPS) ----
    input  wire [ADDR_WIDTH-1:0] avs_address,
    input  wire                  avs_write,
    input  wire [DATA_WIDTH-1:0] avs_writedata,
    input  wire                  avs_read,
    output reg  [DATA_WIDTH-1:0] avs_readdata,
    output wire                  avs_waitrequest,

    // ---- Porta para a RAM de tiles do background ----
    output wire                  bg_we,
    output wire [10:0]           bg_write_addr,
    output wire [8:0]            bg_write_data

    // ---- Reservado para expansão futura ----
    // sprite_we, sprite_write_addr, sprite_write_data,
    // palette_we, palette_write_addr, palette_write_data
);

    // Mapa de endereços: 4 bits mais altos = região, resto = offset
    localparam REGION_BACKGROUND = 4'h0;
    localparam REGION_SPRITE     = 4'h1; // reservado, não implementado
    localparam REGION_PALETTE    = 4'h2; // reservado, não implementado

    wire [3:0]  region = avs_address[ADDR_WIDTH-1 -: 4];
    wire [10:0] offset = avs_address[10:0];

    // Memória de porta única, resposta em 1 ciclo -> sem wait states
    assign avs_waitrequest = 1'b0;

    // ---- Decodificação de escrita ----
    assign bg_we         = avs_write && (region == REGION_BACKGROUND);
    assign bg_write_addr = offset;
    assign bg_write_data = avs_writedata[8:0];

    // ---- Leitura (readback ainda não implementado) ----
    always @(posedge clock) begin
        if (reset)
            avs_readdata <= {DATA_WIDTH{1'b0}};
        else if (avs_read) begin
            case (region)
                REGION_BACKGROUND: avs_readdata <= {DATA_WIDTH{1'b0}}; // TODO
                default:            avs_readdata <= {DATA_WIDTH{1'b0}};
            endcase
        end
    end

endmodule