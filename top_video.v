module top_video (
    input  wire clock,       // Clock de 50 MHz da DE1-SoC
    input  wire reset,

    output wire hsync,
    output wire vsync,
    output wire sync,
    output wire clk,
    output wire blank,

    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue
);

    // ============================================================
    // PLL
    // CLOCK: 50 MHz -> 25 MHz
    // ============================================================

    wire clock_25;
    wire pll_locked;

    pll01 pll_inst (
        .refclk   (clock),
        .rst      (reset),
        .outclk_0 (clock_25),
        .locked   (pll_locked)
    );


    // ============================================================
    // RESET DO SISTEMA VGA
    // Mantém o VGA em reset enquanto o PLL não estiver estável
    // ============================================================

    wire vga_reset;

    assign vga_reset = reset | ~pll_locked;


    // ============================================================
    // COORDENADAS DO PIXEL
    // ============================================================

    wire [9:0] next_x;
    wire [9:0] next_y;


    // ============================================================
    // CONVERSÃO PARA RESOLUÇÃO LÓGICA 320x240
    //
    // Cada pixel lógico ocupa uma área de 2x2 pixels físicos
    // ============================================================

    wire [8:0] logical_x;
    wire [7:0] logical_y;

    assign logical_x = next_x[9:1];
    assign logical_y = next_y[8:1];


    // ============================================================
    // COR GERADA PELA MEMÓRIA DE TILES
    // Formato: RRRGGGBBB
    // ============================================================

    wire [8:0] color_out;


    // ============================================================
    // TILE MEMORY
    // ============================================================

    motor_background mem (

        .clock     (clock_25),

        .logical_x (logical_x),
        .logical_y (logical_y),

        .color_out (color_out)

    );


    // ============================================================
    // VGA DRIVER
    // ============================================================

    vga_driver vga (

        .clock    (clock_25),
        .reset    (vga_reset),

        .color_in (color_out),

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

endmodule