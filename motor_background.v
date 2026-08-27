module motor_background (
    input  wire       clock,

    // Porta de leitura (rendering)
    input  wire [8:0] logical_x,
    input  wire [7:0] logical_y,
    output wire [8:0] color_out,

    // Escrita do background (região 0 da LSU)
    input  wire        bg_we,
    input  wire [10:0] bg_write_addr,
    input  wire [7:0]  bg_write_data,

    // Escrita da paleta (região 3 da LSU)
    input  wire        pal_we,
    input  wire [7:0]  pal_write_addr,
    input  wire [8:0]  pal_write_data
);
    localparam TILES_PER_ROW = 40;

    wire [5:0]  tile_col  = logical_x[8:3];
    wire [4:0]  tile_row  = logical_y[7:3];
    wire [10:0] tile_addr = tile_row * TILES_PER_ROW + tile_col;

    wire [7:0] palette_index; // saída da tile RAM = índice de paleta

    bg_tile_ram u_bg_tile_ram (
        .clock      (clock),
        .data       (bg_write_data),
        .wraddress  (bg_write_addr),
        .wren       (bg_we),
        .rdaddress  (tile_addr),
        .rden       (1'b1),
        .q          (palette_index)
    );

    palette_ram u_palette_ram (
        .clock      (clock),
        .data       (pal_write_data),
        .wraddress  (pal_write_addr),
        .wren       (pal_we),
        .rdaddress  (palette_index),
        .rden       (1'b1),
        .q          (color_out)
    );

endmodule