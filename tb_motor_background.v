`timescale 1ns/1ps

module tb_motor_background;

    // ============================================================
    // CLOCK / RESET
    // ============================================================
    reg clk;
    reg reset;

    always #10 clk = ~clk;   // 50 MHz


    // ============================================================
    // SCROLL
    // ============================================================
    reg       scroll_wr_en;
    reg       scroll_sel;
    reg [8:0] scroll_wr_data;

    reg       scroll_auto_en;
    reg       scroll_auto_axis;
    reg       scroll_auto_dir;
    reg [7:0] scroll_auto_step;


    // ============================================================
    // RAM - TILE
    // ============================================================
    wire [10:0] tile_rd_addr;
    reg  [7:0]  tile_rd_data;


    // ============================================================
    // RAM - PATTERN
    // ============================================================
    wire [13:0] pattern_rd_addr;
    reg  [7:0]  pattern_rd_data;


    // ============================================================
    // RAM - PALETTE
    // ============================================================
    wire [8:0] palette_rd_addr;
    reg  [8:0] palette_rd_data;


    // ============================================================
    // FRAMEBUFFER
    // ============================================================
    wire       fb_we;
    wire [8:0] fb_wr_x;
    wire [7:0] fb_wr_y;
    wire [8:0] fb_wr_data;


    // ============================================================
    // CONTROLE
    // ============================================================
    reg  start;

    wire busy;
    wire done;


    // ============================================================
    // DUT
    // ============================================================
    motor_background uut (
        .clk   (clk),
        .reset (reset),

        .scroll_wr_en   (scroll_wr_en),
        .scroll_sel     (scroll_sel),
        .scroll_wr_data (scroll_wr_data),

        .scroll_auto_en   (scroll_auto_en),
        .scroll_auto_axis (scroll_auto_axis),
        .scroll_auto_dir  (scroll_auto_dir),
        .scroll_auto_step (scroll_auto_step),

        .tile_rd_addr (tile_rd_addr),
        .tile_rd_data (tile_rd_data),

        .pattern_rd_addr (pattern_rd_addr),
        .pattern_rd_data (pattern_rd_data),

        .palette_rd_addr (palette_rd_addr),
        .palette_rd_data (palette_rd_data),

        .fb_we      (fb_we),
        .fb_wr_x    (fb_wr_x),
        .fb_wr_y    (fb_wr_y),
        .fb_wr_data (fb_wr_data),

        .start (start),
        .busy  (busy),
        .done  (done)
    );


    // ============================================================
    // RAM DE TILES
    //
    // Modelo síncrono simples:
    // endereço é aplicado pelo DUT;
    // dado fica disponível no clock seguinte.
    // ============================================================
    reg [7:0] tile_mem [0:1199];

    always @(posedge clk) begin
        tile_rd_data <= tile_mem[tile_rd_addr];
    end


    // ============================================================
    // RAM DE PATTERNS
    // ============================================================
    reg [7:0] pattern_mem [0:16383];

    always @(posedge clk) begin
        pattern_rd_data <= pattern_mem[pattern_rd_addr];
    end


    // ============================================================
    // RAM DE PALETTE
    // ============================================================
    reg [8:0] palette_mem [0:511];

    always @(posedge clk) begin
        palette_rd_data <= palette_mem[palette_rd_addr];
    end


    // ============================================================
    // INICIALIZAÇÃO DAS MEMÓRIAS
    // ============================================================
    integer i;

    initial begin

        for (i = 0; i < 1200; i = i + 1)
            tile_mem[i] = 8'd0;

        for (i = 0; i < 16384; i = i + 1)
            pattern_mem[i] = 8'd1;

        for (i = 0; i < 512; i = i + 1)
            palette_mem[i] = 9'b111_000_000;

    end


    // ============================================================
    // CLOCK
    // ============================================================
    initial begin
        clk = 1'b0;
    end


    // ============================================================
    // TESTE
    // ============================================================
    integer frame_count;
    integer expected_scroll;


    initial begin

        // --------------------------------------------------------
        // Valores iniciais
        // --------------------------------------------------------
        reset = 1'b1;

        scroll_wr_en   = 1'b0;
        scroll_sel     = 1'b0;
        scroll_wr_data = 9'd0;

        // AUTOMÁTICO:
        // horizontal
        // direita
        // 1 pixel/frame
        scroll_auto_en   = 1'b1;
        scroll_auto_axis = 1'b0;
        scroll_auto_dir  = 1'b0;
        scroll_auto_step = 8'd1;

        start = 1'b0;

        frame_count = 0;
        expected_scroll = 1;


        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------
        #100;
        reset = 1'b0;

        $display("");
        $display("==============================================");
        $display(" TESTE MOTOR BACKGROUND - SCROLL AUTOMATICO");
        $display("==============================================");
        $display("Modo      : Horizontal");
        $display("Direcao   : Direita");
        $display("Step      : 1 pixel/frame");
        $display("==============================================");
        $display("");


        // --------------------------------------------------------
        // FRAME 1
        // --------------------------------------------------------
        @(posedge clk);
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;

        wait(done);

        #1;

        frame_count = frame_count + 1;

        $display(
            "FRAME %0d terminado | scroll_x = %0d | frame_scroll_x = %0d",
            frame_count,
            uut.scroll_x,
            uut.frame_scroll_x
        );


        // --------------------------------------------------------
        // FRAMES SEGUINTES
        // --------------------------------------------------------
        repeat (4) begin

            @(posedge clk);
            start <= 1'b1;

            @(posedge clk);
            start <= 1'b0;

            wait(done);

            #1;

            frame_count = frame_count + 1;

            $display(
                "FRAME %0d terminado | scroll_x = %0d | frame_scroll_x = %0d",
                frame_count,
                uut.scroll_x,
                uut.frame_scroll_x
            );

        end


        // --------------------------------------------------------
        // RESULTADO
        // --------------------------------------------------------
        $display("");
        $display("==============================================");
        $display(" TESTE FINALIZADO");
        $display("==============================================");

        if (uut.scroll_x == 9'd5) begin
            $display("PASS: scroll_x chegou a 5 pixels.");
            $display("PASS: scroll automatico esta avancando.");
        end
        else begin
            $display("FAIL: scroll_x esperado = 5");
            $display("      scroll_x encontrado = %0d", uut.scroll_x);
        end

        $display("==============================================");
        $display("");

        $stop;

    end


    // ============================================================
    // MONITOR DE ESCRITA NO FRAMEBUFFER
    // ============================================================
    always @(posedge clk) begin

        if (fb_we) begin

            // Mostra alguns pixels para confirmar que
            // o background realmente esta sendo escrito.
            if ((fb_wr_x == 9'd0) && (fb_wr_y == 8'd0)) begin

                $display(
                    "  FB WRITE: x=%0d y=%0d data=%03h",
                    fb_wr_x,
                    fb_wr_y,
                    fb_wr_data
                );

            end

        end

    end

endmodule
