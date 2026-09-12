`timescale 1ns/1ps

module tb_motor_sprite;

    // ============================================================
    // CLOCK / RESET
    // ============================================================

    reg clk;
    reg reset;

    always #5 clk = ~clk;   // 100 MHz


    // ============================================================
    // INTERFACE COM ATTRIBUTE RAM
    // ============================================================

    wire [4:0]  attr_rd_addr;
    reg  [31:0] attr_rd_data;


    // ============================================================
    // INTERFACE COM PATTERN RAM
    // ============================================================

    wire [13:0] pattern_rd_addr;
    reg  [7:0]  pattern_rd_data;


    // ============================================================
    // INTERFACE COM PALETTE RAM
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

    motor_sprite uut (
        .clk(clk),
        .reset(reset),

        .attr_rd_addr(attr_rd_addr),
        .attr_rd_data(attr_rd_data),

        .pattern_rd_addr(pattern_rd_addr),
        .pattern_rd_data(pattern_rd_data),

        .palette_rd_addr(palette_rd_addr),
        .palette_rd_data(palette_rd_data),

        .fb_we(fb_we),
        .fb_wr_x(fb_wr_x),
        .fb_wr_y(fb_wr_y),
        .fb_wr_data(fb_wr_data),

        .start(start),
        .busy(busy),
        .done(done)
    );


    // ============================================================
    // ATTRIBUTE RAM
    // ============================================================

    reg [31:0] attr_ram [0:31];

    /*
        Formato:

        [31]    enable
        [30:26] priority
        [25]    flip_v
        [24]    flip_h
        [23]    palette
        [22:17] pattern
        [16:9]  pos_y
        [8:0]   pos_x
    */

    always @(*) begin
        attr_rd_data = attr_ram[attr_rd_addr];
    end


    // ============================================================
    // PATTERN RAM
    // ============================================================

    /*
        O motor gera:

        pattern_rd_addr = {tile_id, sub_y, sub_x}

        8 bits tile_id
        3 bits sub_y
        3 bits sub_x

        Total = 14 bits
    */

    always @(*) begin

        // Por padrão, pixel transparente
        pattern_rd_data = 8'd0;

        /*
            Qualquer endereço acessado retorna cor 1.

            Isso faz com que o sprite inteiro seja desenhado.
        */
        if (pattern_rd_addr != 14'd0)
            pattern_rd_data = 8'd1;

    end


    // ============================================================
    // PALETTE RAM
    // ============================================================

    /*
        palette_rd_addr:

        [8]   = palette select
        [7:0] = color index

        Vamos fazer:
        palette 0
        cor 1 -> vermelho = 9'b111_000_000
    */

    always @(*) begin

        case (palette_rd_addr)

            9'b0_00000001:
                palette_rd_data = 9'b111_000_000;

            default:
                palette_rd_data = 9'b000_000_000;

        endcase

    end


    // ============================================================
    // SIMULAÇÃO DO FRAMEBUFFER
    // ============================================================

    integer pixel_count;

    always @(posedge clk) begin

        if (reset) begin
            pixel_count <= 0;
        end

        else if (fb_we) begin

            pixel_count <= pixel_count + 1;

            $display(
                "[FRAMEBUFFER] t=%0t | X=%0d Y=%0d DATA=%09b",
                $time,
                fb_wr_x,
                fb_wr_y,
                fb_wr_data
            );

        end

    end


    // ============================================================
    // INICIALIZAÇÃO DOS SPRITES
    // ============================================================

    integer i;

    initial begin

        // Inicializa todos os sprites como desabilitados
        for (i = 0; i < 32; i = i + 1)
            attr_ram[i] = 32'd0;


        /*
            Sprite 0:

            enable   = 1
            priority = 0
            flip_v   = 0
            flip_h   = 0
            palette  = 0
            pattern  = 0
            pos_x    = 10
            pos_y    = 20

            Portanto:

            sprite começa em (10,20)
            e ocupa 16x16 pixels.
        */

        attr_ram[0] = {
            1'b1,       // enable
            5'd0,       // priority
            1'b0,       // flip_v
            1'b0,       // flip_h
            1'b0,       // palette
            6'd0,       // pattern
            8'd20,      // pos_y
            9'd10       // pos_x
        };


        // Sprite 1 desabilitado
        attr_ram[1] = 32'd0;

        // Demais sprites desabilitados
        for (i = 2; i < 32; i = i + 1)
            attr_ram[i] = 32'd0;

    end


    // ============================================================
    // TESTE
    // ============================================================

    initial begin

        clk   = 1'b0;
        reset = 1'b1;
        start = 1'b0;

        pixel_count = 0;

        // Reset
        #20;

        reset = 1'b0;

        #20;

        // Inicia o motor
        $display("");
        $display("==============================================");
        $display(" INICIANDO MOTOR SPRITE");
        $display("==============================================");
        $display("");

        start = 1'b1;

        #10;

        start = 1'b0;


        // Espera o processamento terminar
        wait(done);

        #20;

        $display("");
        $display("==============================================");
        $display(" MOTOR TERMINOU");
        $display(" Pixels escritos = %0d", pixel_count);
        $display("==============================================");
        $display("");

        #20;

        $stop;

    end


    // ============================================================
    // MONITOR DE CONTROLE
    // ============================================================

    always @(posedge clk) begin

        if (start)
            $display(
                "[START] t=%0t | motor iniciado",
                $time
            );

        if (done)
            $display(
                "[DONE]  t=%0t | motor terminou",
                $time
            );

    end


endmodule