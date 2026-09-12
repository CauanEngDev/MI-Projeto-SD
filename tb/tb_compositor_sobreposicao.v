`timescale 1ns/1ps

module tb_compositor_sobreposicao;

    // ============================================================
    // CLOCK / RESET
    // ============================================================

    reg clk;
    reg reset;
    reg start;

    // ============================================================
    // INTERFACE DO COMPOSITOR
    // ============================================================

    wire busy;
    wire done;

    wire bg_start;
    wire poly_start;
    wire spr_start;

    reg bg_busy;
    reg bg_done;

    reg poly_busy;
    reg poly_layer_done;

    reg spr_busy;
    reg spr_done;

    wire [8:0] palette_rd_addr;
    reg  [8:0] palette_rd_data;

    wire [8:0] bg_palette_rd_data;
    wire [8:0] poly_palette_rd_data;
    wire [8:0] spr_palette_rd_data;

    wire bg_fb_we;
    wire [8:0] bg_fb_wr_x;
    wire [7:0] bg_fb_wr_y;
    wire [8:0] bg_fb_wr_data;

    wire poly_fb_we;
    wire [8:0] poly_fb_wr_x;
    wire [7:0] poly_fb_wr_y;
    wire [8:0] poly_fb_wr_data;

    wire spr_fb_we;
    wire [8:0] spr_fb_wr_x;
    wire [7:0] spr_fb_wr_y;
    wire [8:0] spr_fb_wr_data;

    wire fb_we;
    wire [8:0] fb_wr_x;
    wire [7:0] fb_wr_y;
    wire [8:0] fb_wr_data;

    wire poly_phase;

    // ============================================================
    // FRAMEBUFFER COMPORTAMENTAL
    // ============================================================

    reg [8:0] framebuffer_test [0:319][0:239];

    integer x;
    integer y;

    integer total_writes;
    integer bg_writes;
    integer poly_writes;
    integer spr_writes;

    integer errors;

    // ============================================================
    // COMPOSITOR
    // ============================================================

    compositor uut (

        .clk(clk),
        .reset(reset),

        .start(start),
        .busy(busy),
        .done(done),

        .bg_start(bg_start),
        .bg_busy(bg_busy),
        .bg_done(bg_done),

        .poly_start(poly_start),
        .poly_busy(poly_busy),
        .poly_layer_done(poly_layer_done),

        .spr_start(spr_start),
        .spr_busy(spr_busy),
        .spr_done(spr_done),

        .palette_rd_addr(palette_rd_addr),
        .palette_rd_data(palette_rd_data),

        .bg_palette_rd_addr(9'd0),
        .bg_palette_rd_data(bg_palette_rd_data),

        .poly_palette_rd_addr(9'd0),
        .poly_palette_rd_data(poly_palette_rd_data),

        .spr_palette_rd_addr(9'd0),
        .spr_palette_rd_data(spr_palette_rd_data),

        .fb_we(fb_we),
        .fb_wr_x(fb_wr_x),
        .fb_wr_y(fb_wr_y),
        .fb_wr_data(fb_wr_data),

        .poly_phase(poly_phase),

        .bg_fb_we(bg_fb_we),
        .bg_fb_wr_x(bg_fb_wr_x),
        .bg_fb_wr_y(bg_fb_wr_y),
        .bg_fb_wr_data(bg_fb_wr_data),

        .poly_fb_we(poly_fb_we),
        .poly_fb_wr_x(poly_fb_wr_x),
        .poly_fb_wr_y(poly_fb_wr_y),
        .poly_fb_wr_data(poly_fb_wr_data),

        .spr_fb_we(spr_fb_we),
        .spr_fb_wr_x(spr_fb_wr_x),
        .spr_fb_wr_y(spr_fb_wr_y),
        .spr_fb_wr_data(spr_fb_wr_data)
    );

    // ============================================================
    // CLOCK
    // ============================================================

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end

    // ============================================================
    // PALETA
    // ============================================================

    always @(*) begin

        palette_rd_data = 9'd0;

    end

    // ============================================================
    // BACKGROUND
    //
    // Gera uma camada de 16x16 pixels.
    //
    // Cor:
    // 001_110_000
    //
    // ============================================================

    reg bg_generating;

    reg [4:0] bg_x;
    reg [4:0] bg_y;

    assign bg_fb_we =
        bg_generating &&
        (bg_x < 16) &&
        (bg_y < 16);

    assign bg_fb_wr_x = 9'd100 + bg_x;
    assign bg_fb_wr_y = 8'd100 + bg_y;

    assign bg_fb_wr_data = 9'b001_110_000;

    always @(posedge clk) begin

        if (reset) begin

            bg_busy      <= 1'b0;
            bg_done      <= 1'b0;
            bg_generating <= 1'b0;

            bg_x <= 0;
            bg_y <= 0;

        end
        else begin

            bg_done <= 1'b0;

            if (bg_start && !bg_busy) begin

                bg_busy       <= 1'b1;
                bg_generating <= 1'b1;

                bg_x <= 0;
                bg_y <= 0;

            end
            else if (bg_generating) begin

                if (bg_x == 15) begin

                    bg_x <= 0;

                    if (bg_y == 15) begin

                        bg_y <= 0;

                        bg_generating <= 1'b0;
                        bg_busy       <= 1'b0;

                        bg_done <= 1'b1;

                    end
                    else begin

                        bg_y <= bg_y + 1'b1;

                    end

                end
                else begin

                    bg_x <= bg_x + 1'b1;

                end

            end

        end

    end

    // ============================================================
    // POLÍGONO
    //
    // Também escreve exatamente os mesmos 16x16 pixels.
    //
    // Cor:
    // 111_000_000
    //
    // ============================================================

    reg poly_generating;

    reg [4:0] poly_x;
    reg [4:0] poly_y;

    assign poly_fb_we =
        poly_generating &&
        (poly_x < 16) &&
        (poly_y < 16);

    assign poly_fb_wr_x = 9'd100 + poly_x;
    assign poly_fb_wr_y = 8'd100 + poly_y;

    assign poly_fb_wr_data = 9'b111_000_000;

    always @(posedge clk) begin

        if (reset) begin

            poly_busy       <= 1'b0;
            poly_layer_done <= 1'b0;
            poly_generating <= 1'b0;

            poly_x <= 0;
            poly_y <= 0;

        end
        else begin

            poly_layer_done <= 1'b0;

            if (poly_start && !poly_busy) begin

                poly_busy       <= 1'b1;
                poly_generating <= 1'b1;

                poly_x <= 0;
                poly_y <= 0;

            end
            else if (poly_generating) begin

                if (poly_x == 15) begin

                    poly_x <= 0;

                    if (poly_y == 15) begin

                        poly_y <= 0;

                        poly_generating <= 1'b0;
                        poly_busy       <= 1'b0;

                        poly_layer_done <= 1'b1;

                    end
                    else begin

                        poly_y <= poly_y + 1'b1;

                    end

                end
                else begin

                    poly_x <= poly_x + 1'b1;

                end

            end

        end

    end

    // ============================================================
    // SPRITE
    //
    // Também escreve exatamente os mesmos 16x16 pixels.
    //
    // Cor:
    // 000_000_111
    //
    // ============================================================

    reg spr_generating;

    reg [4:0] spr_x;
    reg [4:0] spr_y;

    assign spr_fb_we =
        spr_generating &&
        (spr_x < 16) &&
        (spr_y < 16);

    assign spr_fb_wr_x = 9'd100 + spr_x;
    assign spr_fb_wr_y = 8'd100 + spr_y;

    assign spr_fb_wr_data = 9'b000_000_111;

    always @(posedge clk) begin

        if (reset) begin

            spr_busy       <= 1'b0;
            spr_done       <= 1'b0;
            spr_generating <= 1'b0;

            spr_x <= 0;
            spr_y <= 0;

        end
        else begin

            spr_done <= 1'b0;

            if (spr_start && !spr_busy) begin

                spr_busy       <= 1'b1;
                spr_generating <= 1'b1;

                spr_x <= 0;
                spr_y <= 0;

            end
            else if (spr_generating) begin

                if (spr_x == 15) begin

                    spr_x <= 0;

                    if (spr_y == 15) begin

                        spr_y <= 0;

                        spr_generating <= 1'b0;
                        spr_busy       <= 1'b0;

                        spr_done <= 1'b1;

                    end
                    else begin

                        spr_y <= spr_y + 1'b1;

                    end

                end
                else begin

                    spr_x <= spr_x + 1'b1;

                end

            end

        end

    end

    // ============================================================
    // CAPTURA DO FRAMEBUFFER
    //
    // fb_we é a saída efetivamente arbitrada pelo compositor.
    //
    // ============================================================

    always @(posedge clk) begin

        if (fb_we) begin

            framebuffer_test[fb_wr_x][fb_wr_y] <= fb_wr_data;

            total_writes = total_writes + 1;

            if (poly_phase == 1'b0 && bg_busy)
                bg_writes = bg_writes + 1;

            else if (poly_phase == 1'b1 && poly_busy)
                poly_writes = poly_writes + 1;

            else if (spr_busy)
                spr_writes = spr_writes + 1;

            $display(
                "FB WRITE: X=%0d Y=%0d DATA=%09b",
                fb_wr_x,
                fb_wr_y,
                fb_wr_data
            );

        end

    end

    // ============================================================
    // TESTE PRINCIPAL
    // ============================================================

    initial begin

        // --------------------------------------------------------
        // Inicialização
        // --------------------------------------------------------

        total_writes = 0;
        bg_writes    = 0;
        poly_writes  = 0;
        spr_writes   = 0;
        errors       = 0;

        start = 1'b0;
        reset = 1'b1;

        // --------------------------------------------------------
        // Inicializa framebuffer
        // --------------------------------------------------------

        for (x = 0; x < 320; x = x + 1) begin

            for (y = 0; y < 240; y = y + 1) begin

                framebuffer_test[x][y] = 9'd0;

            end

        end

        // --------------------------------------------------------
        // Reset
        // --------------------------------------------------------

        #30;

        reset = 1'b0;

        #20;

        // ========================================================
        // CABEÇALHO
        // ========================================================

        $display("");
        $display("====================================================");
        $display("TESTE: SOBREPOSICAO DAS TRES CAMADAS");
        $display("====================================================");

        $display("");
        $display("Regiao utilizada:");
        $display("  X = 100..115");
        $display("  Y = 100..115");
        $display("  Tamanho = 16x16");
        $display("");

        $display("Camadas:");
        $display("  Background -> VERDE");
        $display("  Poligono   -> VERMELHO");
        $display("  Sprite     -> AZUL");
        $display("");

        $display("Ordem esperada:");
        $display("  Background -> Poligono -> Sprite");
        $display("");

        $display("Resultado esperado:");
        $display("  256 escritas do Background");
        $display("  256 escritas do Poligono");
        $display("  256 escritas do Sprite");
        $display("  768 escritas totais");
        $display("");

        // ========================================================
        // INICIA COMPOSIÇÃO
        // ========================================================

        start = 1'b1;

        #10;

        start = 1'b0;

        // ========================================================
        // ESPERA FINALIZAÇÃO
        // ========================================================

        wait(done);

        #20;

        // ========================================================
        // VERIFICA QUANTIDADE DE ESCRITAS
        // ========================================================

        $display("");
        $display("====================================================");
        $display("VERIFICACAO DAS ESCRITAS");
        $display("====================================================");

        $display("Total de escritas: %0d", total_writes);
        $display("Background       : %0d", bg_writes);
        $display("Poligono         : %0d", poly_writes);
        $display("Sprite           : %0d", spr_writes);

        // ========================================================
        // TESTE TOTAL
        // ========================================================

        if (total_writes != 768) begin

            $display("");
            $display("ERRO: total de escritas deveria ser 768.");

            errors = errors + 1;

        end
        else begin

            $display("");
            $display("PASSOU: 768 escritas realizadas.");

        end

        // ========================================================
        // VERIFICA BACKGROUND
        // ========================================================

        if (bg_writes != 256) begin

            $display("ERRO: Background deveria escrever 256 pixels.");

            errors = errors + 1;

        end
        else begin

            $display("PASSOU: Background escreveu 256 pixels.");

        end

        // ========================================================
        // VERIFICA POLÍGONO
        // ========================================================

        if (poly_writes != 256) begin

            $display("ERRO: Poligono deveria escrever 256 pixels.");

            errors = errors + 1;

        end
        else begin

            $display("PASSOU: Poligono escreveu 256 pixels.");

        end

        // ========================================================
        // VERIFICA SPRITE
        // ========================================================

        if (spr_writes != 256) begin

            $display("ERRO: Sprite deveria escrever 256 pixels.");

            errors = errors + 1;

        end
        else begin

            $display("PASSOU: Sprite escreveu 256 pixels.");

        end

        // ========================================================
        // VERIFICA RESULTADO FINAL DO FRAMEBUFFER
        // ========================================================

        $display("");
        $display("====================================================");
        $display("VERIFICANDO FRAMEBUFFER FINAL");
        $display("====================================================");

        for (x = 100; x <= 115; x = x + 1) begin

            for (y = 100; y <= 115; y = y + 1) begin

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

        if (errors == 0) begin

            $display("");
            $display("PASSOU: todos os pixels finais sao AZUIS.");
            $display("A sobreposicao das tres camadas ocorreu corretamente.");

        end

        // ========================================================
        // RESULTADO FINAL
        // ========================================================

        $display("");
        $display("====================================================");

        if (errors == 0) begin

            $display(">>> TESTE DE SOBREPOSICAO: PASSOU <<<");

        end
        else begin

            $display(">>> TESTE DE SOBREPOSICAO: FALHOU <<<");
            $display("Quantidade de erros: %0d", errors);

        end

        $display("====================================================");

        #20;

        $stop;

    end

endmodule