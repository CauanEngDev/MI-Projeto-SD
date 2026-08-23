module isa_decoder(
    input wire        clk,
    input wire        reset,
    input wire [31:0] cmd_data, // Instrução do usuário
    input wire        cmd_valid,

    // Interface com a Memória da paleta
    output reg        pal_we, // Write Enable, 0 = apenas leitura, 1 = escrita. Protege de corrupções quando fizer outras escritas.
    output reg [7:0]  pal_addr,
    output reg [15:0] pal_color,

    // Interface com o Motor do Background / TiledMap
    output reg        tiledmap_we,
    output reg [5:0]  tiledmap_x,
    output reg [4:0]  tiledmap_y,
    output reg [7:0]  tiledmap_tile_id,
    output reg [8:0]  bg_scroll_x,
    output reg [7:0]  bg_scroll_x,
    output reg        bg_scroll_update,

    
)
endmodule