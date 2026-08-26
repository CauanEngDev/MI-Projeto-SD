`timescale 1ns/1ps

module tb_vga_driver;

    // ============================================================
    // Sinais do DUT
    // ============================================================

    reg clock;
    reg reset;

    reg [8:0] color_in;

    wire [9:0] next_x;
    wire [9:0] next_y;

    wire hsync;
    wire vsync;

    wire [7:0] red;
    wire [7:0] green;
    wire [7:0] blue;

    wire sync;
    wire clk;
    wire blank;


    // ============================================================
    // Instância do VGA DRIVER
    // ============================================================

    vga_driver uut (
        .clock(clock),
        .reset(reset),
        .color_in(color_in),

        .next_x(next_x),
        .next_y(next_y),

        .hsync(hsync),
        .vsync(vsync),

        .red(red),
        .green(green),
        .blue(blue),

        .sync(sync),
        .clk(clk),
        .blank(blank)
    );


    // ============================================================
    // Clock de 25 MHz
    //
    // Período = 40 ns
    // ============================================================

    initial begin
        clock = 1'b0;

        forever #20 clock = ~clock;
    end


    // ============================================================
    // Estímulos
    // ============================================================

    initial begin

        // Vermelho:
        // RRR GGG BBB
        color_in = 9'b111_000_000;

        // Reset ativo
        reset = 1'b1;

        #100;

        // Libera reset
        reset = 1'b0;


        // ========================================================
        // 1 frame VGA
        //
        // 800 pixels × 525 linhas × 40 ns
        // = 16,8 ms
        //
        // Vamos simular aproximadamente 2 frames.
        // ========================================================

        #34000000;


        $display("---------------------------------------------");
        $display("Fim da simulacao");
        $display("---------------------------------------------");

        $stop;

    end


    // ============================================================
    // Monitoramento
    // ============================================================

    always @(posedge clock) begin

        if (!reset) begin

            // Mostra mudanças importantes no sincronismo

            if (hsync === 1'b0)
                $display(
                    "HSYNC ativo: tempo=%0t ns | X=%d | Y=%d",
                    $time,
                    next_x,
                    next_y
                );

            if (vsync === 1'b0)
                $display(
                    "VSYNC ativo: tempo=%0t ns | X=%d | Y=%d",
                    $time,
                    next_x,
                    next_y
                );

        end

    end

endmodule