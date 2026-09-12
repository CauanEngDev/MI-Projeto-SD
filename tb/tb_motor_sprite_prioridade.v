`timescale 1ns/1ps

module tb_motor_sprite_prioridade;

    // ============================================================
    // SINAIS DO DUT
    // ============================================================

    reg clk;
    reg reset;
    reg start;

    wire [4:0] attr_rd_addr;
    reg  [31:0] attr_rd_data;

    wire [13:0] pattern_rd_addr;
    reg  [7:0] pattern_rd_data;

    wire [8:0] palette_rd_addr;
    reg  [8:0] palette_rd_data;

    wire fb_we;
    wire [8:0] fb_wr_x;
    wire [7:0] fb_wr_y;
    wire [8:0] fb_wr_data;

    wire busy;
    wire done;

    // ============================================================
    // MEMÓRIAS COMPORTAMENTAIS
    // ============================================================

    reg [31:0] attr_mem [0:31];
    reg [7:0]  pattern_mem [0:16383];
    reg [8:0]  palette_mem [0:511];

    integer i;
    integer x;
    integer y;

    // ============================================================
    // FRAMEBUFFER DE TESTE
    // ============================================================

    reg [8:0] framebuffer_test [0:319][0:239];

    integer total_writes;
    integer sprite0_writes;
    integer sprite1_writes;
    integer errors;

    // ============================================================
    // INSTANCIA DO MOTOR DE SPRITES
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
    // CLOCK
    // ============================================================

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end

    // ============================================================
    // MEMÓRIA DE ATRIBUTOS
    // ============================================================

    always @(*) begin
        attr_rd_data = attr_mem[attr_rd_addr];
    end

    // ============================================================
    // MEMÓRIA DE PATTERN
    // ============================================================

    always @(*) begin
        pattern_rd_data = pattern_mem[pattern_rd_addr];
    end

    // ============================================================
    // MEMÓRIA DE PALETA
    // ============================================================

    always @(*) begin
        palette_rd_data = palette_mem[palette_rd_addr];
    end

    // ============================================================
    // CAPTURA DO FRAMEBUFFER
    // ============================================================

    always @(posedge clk) begin

        if (fb_we) begin

            framebuffer_test[fb_wr_x][fb_wr_y] <= fb_wr_data;

            total_writes = total_writes + 1;

            if (fb_wr_data == 9'b111_000_000)
                sprite0_writes = sprite0_writes + 1;

            if (fb_wr_data == 9'b000_000_111)
                sprite1_writes = sprite1_writes + 1;

            $display(
                "WRITE #%0d: X=%0d Y=%0d DATA=%09b",
                total_writes,
                fb_wr_x,
                fb_wr_y,
                fb_wr_data
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

        total_writes   = 0;
        sprite0_writes = 0;
        sprite1_writes = 0;
        errors         = 0;

        start = 1'b0;
        reset = 1'b1;

        // --------------------------------------------------------
        // Inicializa memórias
        // --------------------------------------------------------

        for (i = 0; i < 32; i = i + 1)
            attr_mem[i] = 32'd0;

        for (i = 0; i < 16384; i = i + 1)
            pattern_mem[i] = 8'd1;

        for (i = 0; i < 512; i = i + 1)
            palette_mem[i] = 9'd0;

        // --------------------------------------------------------
        // PALETAS
        // --------------------------------------------------------
        //
        // Palette 0:
        // índice 1 = vermelho
        //
        // Palette 1:
        // índice 1 = azul
        //
        // --------------------------------------------------------

        palette_mem[9'd1] = 9'b111_000_000;

        palette_mem[9'd257] = 9'b000_000_111;

        // --------------------------------------------------------
        // Inicializa framebuffer
        // --------------------------------------------------------

        for (x = 0; x < 320; x = x + 1) begin

            for (y = 0; y < 240; y = y + 1) begin

                framebuffer_test[x][y] = 9'd0;

            end

        end

        // ========================================================
        // SPRITE 0
        // ========================================================
        //
        // prioridade = 0
        // posição     = (50,50)
        // palette     = 0
        //
        // ========================================================

        attr_mem[0] = {
            1'b1,       // enable
            5'd0,       // priority
            1'b0,       // flip_v
            1'b0,       // flip_h
            1'b0,       // palette
            6'd0,       // pattern
            8'd50,      // pos_y
            9'd50       // pos_x
        };

        // ========================================================
        // SPRITE 1
        // ========================================================
        //
        // prioridade = 1
        // posição     = (50,50)
        // palette     = 1
        //
        // ========================================================

        attr_mem[1] = {
            1'b1,       // enable
            5'd1,       // prioridade 1
            1'b0,       // flip_v
            1'b0,       // flip_h
            1'b1,       // palette
            6'd0,       // pattern
            8'd50,      // pos_y
            9'd50       // pos_x
        };

        // ========================================================
        // RESET
        // ========================================================

        #30;

        reset = 1'b0;

        #20;

        // ========================================================
        // CABEÇALHO
        // ========================================================

        $display("");
        $display("====================================================");
        $display("TESTE: PRIORIDADE DOS SPRITES");
        $display("====================================================");

        $display("");
        $display("Sprite 0:");
        $display("  Posicao    : (50,50)");
        $display("  Prioridade : 0");
        $display("  Cor        : VERMELHO");
        $display("");

        $display("Sprite 1:");
        $display("  Posicao    : (50,50)");
        $display("  Prioridade : 1");
        $display("  Cor        : AZUL");
        $display("");

        $display("Os dois sprites ocupam a mesma regiao.");
        $display("");

        $display("Resultado esperado:");
        $display("  Sprite 0 escreve 256 pixels.");
        $display("  Sprite 1 escreve 256 pixels.");
        $display("  Total = 512 escritas.");
        $display("  Framebuffer final = AZUL.");
        $display("");

        // ========================================================
        // INICIA MOTOR
        // ========================================================

        start = 1'b1;

        #10;

        start = 1'b0;

        // ========================================================
        // ESPERA CONCLUSÃO
        // ========================================================

        wait(done);

        #20;

        // ========================================================
        // VERIFICA CONTADORES
        // ========================================================

        $display("");
        $display("====================================================");
        $display("VERIFICACAO DAS ESCRITAS");
        $display("====================================================");

        $display("Escritas totais   : %0d", total_writes);
        $display("Sprite 0          : %0d", sprite0_writes);
        $display("Sprite 1          : %0d", sprite1_writes);

        // --------------------------------------------------------
        // Total
        // --------------------------------------------------------

        if (total_writes != 512) begin

            $display("");
            $display("ERRO: esperado 512 escritas.");

            errors = errors + 1;

        end
        else begin

            $display("");
            $display("PASSOU: total de escritas = 512.");

        end

        // --------------------------------------------------------
        // Sprite 0
        // --------------------------------------------------------

        if (sprite0_writes != 256) begin

            $display("ERRO: Sprite 0 deveria escrever 256 pixels.");

            errors = errors + 1;

        end
        else begin

            $display("PASSOU: Sprite 0 escreveu 256 pixels.");

        end

        // --------------------------------------------------------
        // Sprite 1
        // --------------------------------------------------------

        if (sprite1_writes != 256) begin

            $display("ERRO: Sprite 1 deveria escrever 256 pixels.");

            errors = errors + 1;

        end
        else begin

            $display("PASSOU: Sprite 1 escreveu 256 pixels.");

        end

        // ========================================================
        // VERIFICA FRAMEBUFFER
        // ========================================================

        $display("");
        $display("====================================================");
        $display("VERIFICANDO FRAMEBUFFER FINAL");
        $display("====================================================");

        for (x = 50; x <= 65; x = x + 1) begin

            for (y = 50; y <= 65; y = y + 1) begin

                if (framebuffer_test[x][y] !== 9'b000_000_111) begin

                    $display(
                        "ERRO: framebuffer[%0d][%0d] = %09b, esperado AZUL",
                        x,
                        y,
                        framebuffer_test[x][y]
                    );

                    errors = errors + 1;

                end

            end

        end

        // ========================================================
        // RESULTADO
        // ========================================================

        if (errors == 0) begin

            $display("");
            $display("PASSOU: todos os pixels possuem a cor");
            $display("do sprite de maior prioridade.");

        end

        $display("");
        $display("====================================================");

        if (errors == 0) begin

            $display(">>> TESTE DE PRIORIDADE: PASSOU <<<");

        end
        else begin

            $display(">>> TESTE DE PRIORIDADE: FALHOU <<<");
            $display("Quantidade de erros: %0d", errors);

        end

        $display("====================================================");

        #20;

        $stop;

    end

endmodule