module top_video (
    input  wire        clock,
    input  wire        reset,

    output wire         hsync,
    output wire         vsync,
    output wire         sync,
    output wire         clk,
    output wire         blank,
    output wire [7:0]   red,
    output wire [7:0]   green,
    output wire [7:0]   blue,

    // ---------------- Interface da CPU (memórias) ----------------
    input wire        bg_tile_wr_en,
    input wire [10:0] bg_tile_wr_addr,
    input wire [7:0]  bg_tile_wr_data,

    input wire        bg_pattern_wr_en,
    input wire [13:0] bg_pattern_wr_addr,
    input wire [7:0]  bg_pattern_wr_data,

    input wire        spr_attr_wr_en,
    input wire [4:0]  spr_attr_wr_addr,
    input wire [31:0] spr_attr_wr_data,

    input wire        spr_pattern_wr_en,
    input wire [13:0] spr_pattern_wr_addr,
    input wire [7:0]  spr_pattern_wr_data,

    input wire        palette_wr_en,
    input wire [8:0]  palette_wr_addr,
    input wire [8:0]  palette_wr_data,

    input wire        scroll_wr_en,
    input wire        scroll_sel,
    input wire [8:0]  scroll_wr_data,

    // ---------------- Interface da CPU (comandos de desenho) ----------------
    input wire        rast_start_square,
    input wire        rast_start_triangle,
    input wire [8:0]  rast_v0x, rast_v1x, rast_v2x,
    input wire [7:0]  rast_v0y, rast_v1y, rast_v2y,
    input wire [7:0]  rast_color_index,
    input wire        rast_palette_sel,
    output wire        rast_busy,
    output wire        rast_done,

    // ---------------- Interface da CPU (controle de frame) ----------------
    input  wire        frame_start,      // CPU dispara um novo frame
    input  wire        poly_layer_done,  // CPU sinaliza fim dos comandos de polígono
	 output wire        poly_phase, 
    output wire        frame_done        // compositor terminou o frame inteiro
);

    // ---------------- Pixel clock ----------------
    reg clk_pixel_reg;
    always @(posedge clock or posedge reset) begin
        if (reset) clk_pixel_reg <= 1'b0;
        else       clk_pixel_reg <= ~clk_pixel_reg;
    end
    wire clk_pixel = clk_pixel_reg;

    // ---------------- Framebuffer + VGA ----------------
    wire        fb_we;
    wire [8:0]  fb_wr_x;
    wire [7:0]  fb_wr_y;
    wire [8:0]  fb_wr_data;
    wire [9:0]  next_x, next_y;
    wire [8:0]  fb_color_out;
    wire [8:0]  fb_rd_x = next_x[9:1];
    wire [7:0]  fb_rd_y = next_y[9:1];

    framebuffer framebuffer_inst (
        .clk_sys   (clock),
        .we        (fb_we),
        .wr_x      (fb_wr_x),
        .wr_y      (fb_wr_y),
        .wr_data   (fb_wr_data),
        .clk_pixel (clk_pixel),
        .rd_x      (fb_rd_x),
        .rd_y      (fb_rd_y),
        .q         (fb_color_out)
    );

    vga_driver vga_driver_inst (
        .clock    (clk_pixel),
        .reset    (reset),
        .color_in (fb_color_out),
        .next_x   (next_x),
        .next_y   (next_y),
        .hsync    (hsync),
        .vsync    (vsync),
        .red      (red),
        .green    (green),
        .blue     (blue),
        .sync     (sync),
        .clk      (clk),
        .blank    (blank)
    );

    // ---------------- Palette RAM (única, compartilhada, arbitrada pelo compositor) ----------------
    wire [8:0] pal_rd_addr_arb, pal_rd_data_arb;

    palette_ram palette_ram_inst (
        .clock     (clock),
        .data      (palette_wr_data),
        .wraddress (palette_wr_addr),
        .wren      (palette_wr_en),
        .rdaddress (pal_rd_addr_arb),
        .q         (pal_rd_data_arb)
    );

    // ---------------- Memórias do background ----------------
    wire [10:0] bg_tile_rd_addr;
    wire [7:0]  bg_tile_rd_data;

    bg_tile_ram bg_tile_ram_inst (
        .clock     (clock),
        .data      (bg_tile_wr_data),
        .wraddress (bg_tile_wr_addr),
        .wren      (bg_tile_wr_en),
        .rdaddress (bg_tile_rd_addr),
        .q         (bg_tile_rd_data)
    );

    wire [13:0] bg_pattern_rd_addr;
    wire [7:0]  bg_pattern_rd_data;

    bg_tile_pattern_ram bg_tile_pattern_ram_inst (
        .clock     (clock),
        .data      (bg_pattern_wr_data),
        .wraddress (bg_pattern_wr_addr),
        .wren      (bg_pattern_wr_en),
        .rdaddress (bg_pattern_rd_addr),
        .q         (bg_pattern_rd_data)
    );

    // ---------------- Motor de background ----------------
    wire bg_start, bg_busy, bg_done;
    wire [8:0] bg_pal_addr, bg_pal_data;
    wire       bg_fb_we;
    wire [8:0] bg_fb_x, bg_fb_data;
    wire [7:0] bg_fb_y;

    motor_background motor_background_inst (
        .clk (clock), .reset (reset),
        .scroll_wr_en   (scroll_wr_en),
        .scroll_sel     (scroll_sel),
        .scroll_wr_data (scroll_wr_data),
        .tile_rd_addr   (bg_tile_rd_addr),
        .tile_rd_data   (bg_tile_rd_data),
        .pattern_rd_addr(bg_pattern_rd_addr),
        .pattern_rd_data(bg_pattern_rd_data),
        .palette_rd_addr(bg_pal_addr),
        .palette_rd_data(bg_pal_data),
        .fb_we (bg_fb_we), .fb_wr_x (bg_fb_x), .fb_wr_y (bg_fb_y), .fb_wr_data (bg_fb_data),
        .start (bg_start), .busy (bg_busy), .done (bg_done)
    );

    // ---------------- Subsistema de sprites ----------------
    wire spr_start, spr_busy, spr_done;
    wire [8:0] spr_pal_addr, spr_pal_data;
    wire       spr_fb_we;
    wire [8:0] spr_fb_x, spr_fb_data;
    wire [7:0] spr_fb_y;

    subsistema_sprite sprite_subsystem_inst (
        .clk (clock), .reset (reset),
        .attr_wr_en    (spr_attr_wr_en),
        .attr_wr_addr  (spr_attr_wr_addr),
        .attr_wr_data  (spr_attr_wr_data),
        .pattern_wr_en   (spr_pattern_wr_en),
        .pattern_wr_addr (spr_pattern_wr_addr),
        .pattern_wr_data (spr_pattern_wr_data),
        .palette_rd_addr (spr_pal_addr),
        .palette_rd_data (spr_pal_data),
        .fb_we (spr_fb_we), .fb_wr_x (spr_fb_x), .fb_wr_y (spr_fb_y), .fb_wr_data (spr_fb_data),
        .start (spr_start), .busy (spr_busy), .done (spr_done)
    );

    // ---------------- Rasterizador (comandos individuais da CPU) ----------------
    wire [8:0] poly_pal_addr, poly_pal_data;
    wire       poly_fb_we;
    wire [8:0] poly_fb_x, poly_fb_data;
    wire [7:0] poly_fb_y;

    rasterizador_top rasterizer_top_inst (
        .clk (clock), .reset (reset),
        .start_square   (rast_start_square),
        .start_triangle (rast_start_triangle),
        .v0x(rast_v0x), .v1x(rast_v1x), .v2x(rast_v2x),
        .v0y(rast_v0y), .v1y(rast_v1y), .v2y(rast_v2y),
        .color_index (rast_color_index),
        .palette_sel (rast_palette_sel),
        .palette_rd_addr (poly_pal_addr),
        .palette_rd_data (poly_pal_data),
        .fb_we (poly_fb_we), .fb_wr_x (poly_fb_x), .fb_wr_y (poly_fb_y), .fb_wr_data (poly_fb_data),
        .busy (rast_busy), .done (rast_done)
    );

    // ---------------- Compositor ----------------
    compositor compositor_inst (
        .clk (clock), .reset (reset),
        .start (frame_start), .busy (), .done (frame_done),

        .bg_start (bg_start), .bg_busy (bg_busy), .bg_done (bg_done),
        .poly_layer_done (poly_layer_done),
		  .poly_phase (poly_phase),
        .spr_start (spr_start), .spr_busy (spr_busy), .spr_done (spr_done),

        .palette_rd_addr (pal_rd_addr_arb),
        .palette_rd_data (pal_rd_data_arb),

        .bg_palette_rd_addr   (bg_pal_addr),   .bg_palette_rd_data   (bg_pal_data),
        .poly_palette_rd_addr (poly_pal_addr), .poly_palette_rd_data (poly_pal_data),
        .spr_palette_rd_addr  (spr_pal_addr),  .spr_palette_rd_data  (spr_pal_data),

        .fb_we (fb_we), .fb_wr_x (fb_wr_x), .fb_wr_y (fb_wr_y), .fb_wr_data (fb_wr_data),

        .bg_fb_we (bg_fb_we), .bg_fb_wr_x (bg_fb_x), .bg_fb_wr_y (bg_fb_y), .bg_fb_wr_data (bg_fb_data),
        .poly_fb_we (poly_fb_we), .poly_fb_wr_x (poly_fb_x), .poly_fb_wr_y (poly_fb_y), .poly_fb_wr_data (poly_fb_data),
        .spr_fb_we (spr_fb_we), .spr_fb_wr_x (spr_fb_x), .spr_fb_wr_y (spr_fb_y), .spr_fb_wr_data (spr_fb_data)
    );

endmodule