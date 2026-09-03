module top_video (
    input  wire        clock,
    input  wire        reset,

    // ============================================================
    // VGA
    // ============================================================
    output wire        hsync,
    output wire        vsync,
    output wire        sync,
    output wire        clk,
    output wire        blank,
    output wire [7:0]  red,
    output wire [7:0]  green,
    output wire [7:0]  blue,

    // ============================================================
    // CPU: Background
    // ============================================================
    input wire        bg_tile_wr_en,
    input wire [10:0] bg_tile_wr_addr,
    input wire [7:0]  bg_tile_wr_data,

    input wire        bg_pattern_wr_en,
    input wire [13:0] bg_pattern_wr_addr,
    input wire [7:0]  bg_pattern_wr_data,

    // ============================================================
    // CPU: Sprites
    // ============================================================
    input wire        spr_attr_wr_en,
    input wire [4:0]  spr_attr_wr_addr,
    input wire [31:0] spr_attr_wr_data,

    input wire        spr_pattern_wr_en,
    input wire [13:0] spr_pattern_wr_addr,
    input wire [7:0]  spr_pattern_wr_data,

    // ============================================================
    // CPU: Palette
    // ============================================================
    input wire        palette_wr_en,
    input wire [8:0]  palette_wr_addr,
    input wire [8:0]  palette_wr_data,

    // ============================================================
    // CPU: Scroll
    // ============================================================
    input wire        scroll_wr_en,
    input wire        scroll_sel,
    input wire [8:0]  scroll_wr_data,
	 
	 input wire        scroll_auto_en,
	 input wire        scroll_auto_axis,
	 input wire        scroll_auto_dir,
	 input wire [7:0]  scroll_auto_step,

    // ============================================================
    // Rasterizador
    // ============================================================
    input wire        rast_start_square,
    input wire        rast_start_triangle,

    input wire [8:0]  rast_v0x,
    input wire [8:0]  rast_v1x,
    input wire [8:0]  rast_v2x,

    input wire [7:0]  rast_v0y,
    input wire [7:0]  rast_v1y,
    input wire [7:0]  rast_v2y,

    input wire [7:0]  rast_color_index,
    input wire        rast_palette_sel,

    output wire       rast_busy,
    output wire       rast_done,
	 output wire       rast_invalid_cmd, 

    // ============================================================
    // Controle de frame
    // ============================================================
    input  wire       frame_start,

    // Vem do test_driver
    input  wire       poly_layer_done,

    // Vai para o test_driver
    output wire       poly_phase,

    // Frame efetivamente apresentado após VBlank
    output reg        frame_done
);

    // ============================================================
    // PLL
    // 50 MHz -> 25 MHz
    // ============================================================

    wire clk_pixel;
    wire pll_locked;

    pll01 pll01_inst (
        .refclk   (clock),
        .rst      (reset),
        .outclk_0 (clk_pixel),
        .locked   (pll_locked)
    );

    // ============================================================
    // VGA
    // ============================================================

    wire [9:0] next_x;
    wire [9:0] next_y;

    wire [8:0] fb_color_out;

    wire [8:0] fb_rd_x;
    wire [7:0] fb_rd_y;

    assign fb_rd_x = next_x[9:1];
    assign fb_rd_y = next_y[9:1];

    wire vblank_tick;

    vga_driver vga_driver_inst (
        .clock    (clk_pixel),
        .reset    (reset | ~pll_locked),

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
        .blank    (blank),

        .vblank_tick (vblank_tick)
    );

    // ============================================================
    // Sincronização do VBlank
    //
    // vblank_tick está no domínio clk_pixel.
    // O controle do frame está no domínio clock.
    // ============================================================

    reg vblank_sync0;
    reg vblank_sync1;
    reg vblank_sync1_d;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            vblank_sync0   <= 1'b0;
            vblank_sync1   <= 1'b0;
            vblank_sync1_d <= 1'b0;
        end
        else begin
            vblank_sync0   <= vblank_tick;
            vblank_sync1   <= vblank_sync0;
            vblank_sync1_d <= vblank_sync1;
        end
    end

    wire vblank_event;

    assign vblank_event = vblank_sync1 & ~vblank_sync1_d;

    // ============================================================
    // DOUBLE BUFFER
    //
    // rd_buf_sel = banco atualmente exibido pelo VGA
    // wr_buf_sel = banco onde o próximo frame será desenhado
    //
    // Inicialmente:
    //   VGA lê banco 0
    //   renderização escreve banco 1
    // ============================================================

    reg rd_buf_sel;
    reg wr_buf_sel;

    // ============================================================
    // FRAMEBUFFER
    // ============================================================

    wire       fb_we;
    wire [8:0] fb_wr_x;
    wire [7:0] fb_wr_y;
    wire [8:0] fb_wr_data;

    framebuffer framebuffer_inst (
        .clk_sys    (clock),

        .we         (fb_we),
        .wr_x       (fb_wr_x),
        .wr_y       (fb_wr_y),
        .wr_data    (fb_wr_data),
        .wr_buf_sel (wr_buf_sel),

        .clk_pixel  (clk_pixel),

        .rd_x       (fb_rd_x),
        .rd_y       (fb_rd_y),
        .rd_buf_sel (rd_buf_sel),

        .q          (fb_color_out)
    );

    // ============================================================
    // PALETTE RAM
    // ============================================================

    wire [8:0] palette_rd_addr;
    wire [8:0] palette_rd_data;

    palette_ram palette_ram_inst (
        .clock     (clock),

        .data      (palette_wr_data),
        .wraddress (palette_wr_addr),
        .wren      (palette_wr_en),

        .rdaddress (palette_rd_addr),
        .q         (palette_rd_data)
    );

    // ============================================================
    // BACKGROUND RAM
    // ============================================================

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

    // ============================================================

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

    // ============================================================
    // MOTOR BACKGROUND
    // ============================================================

    wire        bg_start;
    wire        bg_busy;
    wire        bg_done;

    wire [8:0]  bg_palette_rd_addr;
    wire [8:0]  bg_palette_rd_data;

    wire        bg_fb_we;
    wire [8:0]  bg_fb_wr_x;
    wire [7:0]  bg_fb_wr_y;
    wire [8:0]  bg_fb_wr_data;

    motor_background motor_background_inst (
        .clk   (clock),
        .reset (reset),

        .scroll_wr_en   (scroll_wr_en),
        .scroll_sel     (scroll_sel),
        .scroll_wr_data (scroll_wr_data),
		  
		  .scroll_auto_en   (scroll_auto_en),
		  .scroll_auto_axis (scroll_auto_axis),
		  .scroll_auto_dir  (scroll_auto_dir),
        .scroll_auto_step (scroll_auto_step),

        .tile_rd_addr   (bg_tile_rd_addr),
        .tile_rd_data   (bg_tile_rd_data),

        .pattern_rd_addr (bg_pattern_rd_addr),
        .pattern_rd_data (bg_pattern_rd_data),

        .palette_rd_addr (bg_palette_rd_addr),
        .palette_rd_data (bg_palette_rd_data),

        .fb_we      (bg_fb_we),
        .fb_wr_x    (bg_fb_wr_x),
        .fb_wr_y    (bg_fb_wr_y),
        .fb_wr_data (bg_fb_wr_data),

        .start (bg_start),
        .busy  (bg_busy),
        .done  (bg_done)
    );

    // ============================================================
    // SPRITE ATTRIBUTE RAM
    // ============================================================

    wire [4:0]  spr_attr_rd_addr;
    wire [31:0] spr_attr_rd_data;

    sprite_attribute_ram sprite_attribute_ram_inst (
        .clock     (clock),

        .data      (spr_attr_wr_data),
        .wraddress (spr_attr_wr_addr),
        .wren      (spr_attr_wr_en),

        .rdaddress (spr_attr_rd_addr),
        .q         (spr_attr_rd_data)
    );

    // ============================================================
    // SPRITE PATTERN RAM
    // ============================================================

    wire [13:0] spr_pattern_rd_addr;
    wire [7:0]  spr_pattern_rd_data;

    sprite_pattern_ram sprite_pattern_ram_inst (
        .clock     (clock),

        .data      (spr_pattern_wr_data),
        .wraddress (spr_pattern_wr_addr),
        .wren      (spr_pattern_wr_en),

        .rdaddress (spr_pattern_rd_addr),
        .q         (spr_pattern_rd_data)
    );

    // ============================================================
    // MOTOR SPRITE
    // ============================================================

    wire        spr_start;
    wire        spr_busy;
    wire        spr_done;

    wire [8:0]  spr_palette_rd_addr;
    wire [8:0]  spr_palette_rd_data;

    wire        spr_fb_we;
    wire [8:0]  spr_fb_wr_x;
    wire [7:0]  spr_fb_wr_y;
    wire [8:0]  spr_fb_wr_data;
	 
	 

    motor_sprite motor_sprite_inst (
        .clk   (clock),
        .reset (reset),

        .attr_rd_addr (spr_attr_rd_addr),
        .attr_rd_data (spr_attr_rd_data),

        .pattern_rd_addr (spr_pattern_rd_addr),
        .pattern_rd_data (spr_pattern_rd_data),

        .palette_rd_addr (spr_palette_rd_addr),
        .palette_rd_data (spr_palette_rd_data),

        .fb_we      (spr_fb_we),
        .fb_wr_x    (spr_fb_wr_x),
        .fb_wr_y    (spr_fb_wr_y),
        .fb_wr_data (spr_fb_wr_data),

        .start (spr_start),
        .busy  (spr_busy),
        .done  (spr_done)
    );

    // ============================================================
    // RASTERIZADOR
    // ============================================================

    wire [8:0] poly_palette_rd_addr;
    wire [8:0] poly_palette_rd_data;

    wire       poly_fb_we;
    wire [8:0] poly_fb_wr_x;
    wire [7:0] poly_fb_wr_y;
    wire [8:0] poly_fb_wr_data;

    rasterizador_top rasterizer_top_inst (
        .clk   (clock),
        .reset (reset),

        .start_square   (rast_start_square),
        .start_triangle (rast_start_triangle),

        .v0x (rast_v0x),
        .v1x (rast_v1x),
        .v2x (rast_v2x),

        .v0y (rast_v0y),
        .v1y (rast_v1y),
        .v2y (rast_v2y),

        .color_index (rast_color_index),
        .palette_sel (rast_palette_sel),

        .palette_rd_addr (poly_palette_rd_addr),
        .palette_rd_data (poly_palette_rd_data),

        .fb_we      (poly_fb_we),
        .fb_wr_x    (poly_fb_wr_x),
        .fb_wr_y    (poly_fb_wr_y),
        .fb_wr_data (poly_fb_wr_data),

        .busy (rast_busy),
        .done (rast_done),
		  .invalid_cmd (rast_invalid_cmd) 
    );

    // ============================================================
    // COMPOSITOR
    //
    // Sequência:
    //
    // IDLE
    //   ↓
    // BACKGROUND
    //   ↓
    // POLÍGONOS
    //   ↓
    // SPRITES
    //   ↓
    // DONE
    //
    // ============================================================

    wire compositor_busy;
    wire compositor_done;

    compositor compositor_inst (
        .clk   (clock),
        .reset (reset),

        .start (frame_start),
        .busy  (compositor_busy),
        .done  (compositor_done),

        // ---------------- Controle dos motores ----------------

        .bg_start (bg_start),
        .bg_busy  (bg_busy),
        .bg_done  (bg_done),

        .poly_start     (poly_start_internal),
        .poly_busy      (rast_busy),
        .poly_layer_done(poly_layer_done),

        .spr_start (spr_start),
        .spr_busy  (spr_busy),
        .spr_done  (spr_done),

        // ---------------- Palette ----------------

        .palette_rd_addr (palette_rd_addr),
        .palette_rd_data (palette_rd_data),

        .bg_palette_rd_addr   (bg_palette_rd_addr),
        .bg_palette_rd_data   (bg_palette_rd_data),

        .poly_palette_rd_addr (poly_palette_rd_addr),
        .poly_palette_rd_data (poly_palette_rd_data),

        .spr_palette_rd_addr  (spr_palette_rd_addr),
        .spr_palette_rd_data  (spr_palette_rd_data),

        // ---------------- Framebuffer ----------------

        .fb_we      (fb_we),
        .fb_wr_x    (fb_wr_x),
        .fb_wr_y    (fb_wr_y),
        .fb_wr_data (fb_wr_data),

        .poly_phase (poly_phase),

        .bg_fb_we      (bg_fb_we),
        .bg_fb_wr_x    (bg_fb_wr_x),
        .bg_fb_wr_y    (bg_fb_wr_y),
        .bg_fb_wr_data (bg_fb_wr_data),

        .poly_fb_we      (poly_fb_we),
        .poly_fb_wr_x    (poly_fb_wr_x),
        .poly_fb_wr_y    (poly_fb_wr_y),
        .poly_fb_wr_data (poly_fb_wr_data),

        .spr_fb_we      (spr_fb_we),
        .spr_fb_wr_x    (spr_fb_wr_x),
        .spr_fb_wr_y    (spr_fb_wr_y),
        .spr_fb_wr_data (spr_fb_wr_data)
    );

    // ============================================================
    // CONTROLE DO DOUBLE BUFFER
    //
    // O compositor pode terminar muito antes do VBlank.
    // Portanto:
    //
    // compositor_done = frame pronto para apresentação
    //
    // vblank_event = momento seguro para trocar o banco.
    //
    // Só depois dos dois eventos:
    //
    //     troca banco
    //     frame_done = 1
    //
    // ============================================================

    reg frame_render_done;
	 
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            rd_buf_sel      <= 1'b0;
            wr_buf_sel      <= 1'b1;
            frame_render_done <= 1'b0;
            frame_done      <= 1'b0;
        end
        else begin
            frame_done <= 1'b0;

            // Frame inteiro foi renderizado
            if (compositor_done) begin
                frame_render_done <= 1'b1;
            end

            // Só troca o banco durante o VBlank
            if (vblank_event && frame_render_done) begin
                rd_buf_sel <= wr_buf_sel;
                wr_buf_sel <= rd_buf_sel;

                frame_render_done <= 1'b0;
                frame_done <= 1'b1;
            end
        end
    end

endmodule