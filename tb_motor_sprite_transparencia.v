`timescale 1ns/1ps

module tb_motor_sprite_transparencia;

    // ============================================================
    // CLOCK E RESET
    // ============================================================

    reg clk;
    reg reset;

    always #10 clk = ~clk;   // 50 MHz


    // ============================================================
    // INTERFACE DO MOTOR
    // ============================================================

    reg start;

    wire busy;
    wire done;

    // Attribute RAM
    wire [4:0]  attr_rd_addr;
    reg  [31:0] attr_rd_data;

    // Pattern RAM
    wire [13:0] pattern_rd_addr;
    reg  [7:0]  pattern_rd_data;

    // Palette RAM
    wire [8:0] palette_rd_addr;
    reg  [8:0] palette_rd_data;

    // Framebuffer
    wire        fb_we;
    wire [8:0]  fb_wr_x;
    wire [7:0]  fb_wr_y;
    wire [8:0]  fb_wr_data;


    // ============================================================
    // MEMÓRIAS COMPORTAMENTAIS
    //
    // Substituem as memórias altsyncram apenas para simulação.
    // ============================================================

    reg [31:0] attr_mem [0:31];
    reg [7:0]  pattern_mem [0:16383];
    reg [8:0]  palette_mem [0:511];


    // ============================================================
    // MODELOS DE LEITURA DAS MEMÓRIAS
    //
    // Leitura combinacional para simplificar o testbench.
    // ============================================================

    always @(*) begin
        attr_rd_data = attr_mem[attr_rd_addr];
    end

    always @(*) begin
        pattern_rd_data = pattern_mem[pattern_rd_addr];
    end

    always @(*) begin
        palette_rd_data = palette_mem[palette_rd_addr];
    end


    // ============================================================
    // DUT
    // ============================================================

    motor_sprite dut (

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
    // CONTADORES DE TESTE
    // ============================================================

    integer errors;
    integer writes;

    integer i;


    // ============================================================
    // MONITORAMENTO DO FRAMEBUFFER
    //
    // Qualquer fb_we = 1 representa uma escrita.
    //
    // Como todos os pixels da sprite possuem índice 0,
    // nenhuma escrita deveria ocorrer.
    // ============================================================

    always @(posedge clk) begin

        if (fb_we) begin

            writes = writes + 1;

            $display(
                "ERRO: escrita inesperada no framebuffer: x=%0d y=%0d data=%h tempo=%0t",
                fb_wr_x,
                fb_wr_y,
                fb_wr_data,
                $time
            );

        end

    end


    // ============================================================
    // TESTE
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // Inicialização
        // --------------------------------------------------------

        clk    = 1'b0;
        reset  = 1'b1;
        start  = 1'b0;

        errors = 0;
        writes = 0;


        // --------------------------------------------------------
        // Inicializa Attribute RAM
        // --------------------------------------------------------

        for (i = 0; i < 32; i = i + 1) begin
            attr_mem[i] = 32'd0;
        end


        // --------------------------------------------------------
        // Inicializa Pattern RAM
        //
        // Todos os pixels começam transparentes.
        // --------------------------------------------------------

        for (i = 0; i < 16384; i = i + 1) begin
            pattern_mem[i] = 8'd0;
        end


        // --------------------------------------------------------
        // Inicializa Palette RAM
        // --------------------------------------------------------

        for (i = 0; i < 512; i = i + 1) begin
            palette_mem[i] = 9'd0;
        end


        // --------------------------------------------------------
        // CONFIGURAÇÃO DA SPRITE 0
        //
        // Formato:
        //
        // [31]    enable
        // [30:26] priority
        // [25]    flip_v
        // [24]    flip_h
        // [23]    palette_sel
        // [22:17] pattern
        // [16:9]  pos_y
        // [8:0]   pos_x
        //
        // Sprite:
        //
        // enable      = 1
        // priority    = 0
        // flip_v      = 0
        // flip_h      = 0
        // palette     = 0
        // pattern     = 0
        // pos_y       = 50
        // pos_x       = 50
        // --------------------------------------------------------

        attr_mem[0] = {
            1'b1,       // enable
            5'd0,       // priority
            1'b0,       // flip_v
            1'b0,       // flip_h
            1'b0,       // palette_sel
            6'd0,       // pattern
            8'd50,      // pos_y
            9'd50       // pos_x
        };


        $display("====================================================");
        $display("TESTE: TRANSPARENCIA DO MOTOR DE SPRITES");
        $display("====================================================");
        $display("");
        $display("Sprite 0:");
        $display("  Posicao: (50,50)");
        $display("  Prioridade: 0");
        $display("  Pattern: 0");
        $display("  Todos os pixels possuem color_index = 0");
        $display("");
        $display("Resultado esperado:");
        $display("  Nenhuma escrita no framebuffer.");
        $display("");


        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------

        repeat (5) @(posedge clk);

        reset = 1'b0;

        @(posedge clk);


        // --------------------------------------------------------
        // INICIA O MOTOR
        // --------------------------------------------------------

        $display("Iniciando motor_sprite...");

        @(posedge clk);
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;


        // --------------------------------------------------------
        // ESPERA A CONCLUSÃO
        // --------------------------------------------------------

        wait(done == 1'b1);

        @(posedge clk);


        // --------------------------------------------------------
        // VERIFICAÇÃO
        // --------------------------------------------------------

        $display("");
        $display("====================================================");

        if (writes == 0) begin

            $display(
                "PASSOU: nenhum pixel transparente foi escrito no framebuffer."
            );

        end

        else begin

            $display(
                "FALHOU: foram detectadas %0d escrita(s) no framebuffer.",
                writes
            );

            errors = errors + 1;

        end


        $display("====================================================");
        $display("RESULTADO FINAL");
        $display("Escritas detectadas : %0d", writes);
        $display("Falhas detectadas   : %0d", errors);
        $display("====================================================");


        if (errors == 0) begin

            $display("");
            $display(">>> TESTE DE TRANSPARENCIA: PASSOU <<<");

        end

        else begin

            $display("");
            $display(">>> TESTE DE TRANSPARENCIA: FALHOU <<<");

        end


        $stop;

    end


    // ============================================================
    // TIMEOUT DE SEGURANÇA
    // ============================================================

    initial begin

        #500000;

        $display("");
        $display("====================================================");
        $display("TIMEOUT: o motor demorou tempo demais.");
        $display("====================================================");

        $stop;

    end

endmodule

