module rasterizador_top (
    input  wire        clk,
    input  wire        reset,

    input  wire        start_square,
    input  wire        start_triangle,
    input  wire [8:0]  v0x, v1x, v2x,
    input  wire [7:0]  v0y, v1y, v2y,
    input  wire [7:0]  color_index,
    input  wire        palette_sel,

    output wire [8:0]  palette_rd_addr,
    input  wire [8:0]  palette_rd_data,

    output wire         fb_we,
    output wire [8:0]   fb_wr_x,
    output wire [7:0]   fb_wr_y,
    output wire [8:0]   fb_wr_data,

    output wire         busy,
    output wire         done
);

    wire fb_we_sq, fb_we_tr, done_sq, done_tr, busy_sq, busy_tr;
    wire [8:0] fb_x_sq, fb_x_tr, fb_data_sq, fb_data_tr;
    wire [7:0] fb_y_sq, fb_y_tr;
    wire [8:0] pal_addr_sq, pal_addr_tr;

    rasterizador_quadrado u_square (
        .clk(clk), .reset(reset),
        .start(start_square),
        .v0x(v0x), .v1x(v1x), .v0y(v0y), .v1y(v1y),
        .color_index(color_index), .palette_sel(palette_sel),
        .palette_rd_addr(pal_addr_sq), .palette_rd_data(palette_rd_data),
        .fb_we(fb_we_sq), .fb_wr_x(fb_x_sq), .fb_wr_y(fb_y_sq), .fb_wr_data(fb_data_sq),
        .busy(busy_sq), .done(done_sq)
    );

    rasterizador_triangulo u_triangle (
        .clk(clk), .reset(reset),
        .start(start_triangle),
        .v0x(v0x), .v1x(v1x), .v2x(v2x),
        .v0y(v0y), .v1y(v1y), .v2y(v2y),
        .color_index(color_index), .palette_sel(palette_sel),
        .palette_rd_addr(pal_addr_tr), .palette_rd_data(palette_rd_data),
        .fb_we(fb_we_tr), .fb_wr_x(fb_x_tr), .fb_wr_y(fb_y_tr), .fb_wr_data(fb_data_tr),
        .busy(busy_tr), .done(done_tr)
    );

    assign palette_rd_addr = busy_tr ? pal_addr_tr : pal_addr_sq;

    assign fb_we      = busy_tr ? fb_we_tr     : fb_we_sq;
    assign fb_wr_x    = busy_tr ? fb_x_tr      : fb_x_sq;
    assign fb_wr_y    = busy_tr ? fb_y_tr      : fb_y_sq;
    assign fb_wr_data = busy_tr ? fb_data_tr   : fb_data_sq;
    assign busy       = busy_sq | busy_tr;
    assign done        = done_sq | done_tr;

endmodule