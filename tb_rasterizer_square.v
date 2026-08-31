`timescale 1ns / 1ps

module tb_rasterizer_square;

    reg clk;
    reg reset;
    reg start;
    reg [8:0] v0x, v1x;
    reg [7:0] v0y, v1y;
    reg [8:0] color;

    wire fb_we;
    wire [8:0] fb_wr_x;
    wire [7:0] fb_wr_y;
    wire [8:0] fb_wr_data;
    wire busy;
    wire done;

    // Modelo simples de "framebuffer" só para o testbench:
    // um array que registra cada escrita, pra depois conferirmos
    // se os pixels certos (e só eles) foram marcados.
    reg [8:0] shadow_fb [0:319][0:239];
    integer x, y;
    integer pixels_written;

    rasterizador_quadrado dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .v0x(v0x), .v1x(v1x),
        .v0y(v0y), .v1y(v1y),
        .color(color),
        .fb_we(fb_we),
        .fb_wr_x(fb_wr_x),
        .fb_wr_y(fb_wr_y),
        .fb_wr_data(fb_wr_data),
        .busy(busy),
        .done(done)
    );

    // Clock de 50 MHz (20 ns de período) -- mesmo domínio do sistema
    always #10 clk = ~clk;

    // Captura toda escrita no framebuffer sombra
    always @(posedge clk) begin
        if (fb_we) begin
            shadow_fb[fb_wr_x][fb_wr_y] <= fb_wr_data;
            pixels_written <= pixels_written + 1;
        end
    end

    // Tarefa auxiliar: limpa o framebuffer sombra e dispara um desenho
    task draw_square(
        input [8:0] a_x, input [7:0] a_y,
        input [8:0] b_x, input [7:0] b_y,
        input [8:0] c
    );
        integer i, j;
        begin
            for (i = 0; i < 320; i = i + 1)
                for (j = 0; j < 240; j = j + 1)
                    shadow_fb[i][j] <= 9'h1FF; // valor sentinela = "não escrito"

            pixels_written = 0;

            @(posedge clk);
            v0x <= a_x; v0y <= a_y;
            v1x <= b_x; v1y <= b_y;
            color <= c;
            start <= 1'b1;
            @(posedge clk);
            start <= 1'b0;

            // Espera terminar
            wait (done == 1'b1);
            @(posedge clk); // deixa o done se propagar
        end
    endtask

    // Tarefa auxiliar: verifica se a região [xL:xR, yT:yB] está toda
    // pintada com 'c', e nada fora dela foi tocado (checagem por amostragem)
    task check_region(
        input [8:0] xL, input [8:0] xR,
        input [7:0] yT, input [7:0] yB,
        input [8:0] c
    );
        integer i, j;
        integer expected_count;
        integer errors;
        begin
            errors = 0;
            expected_count = (xR - xL + 1) * (yB - yT + 1);

            for (i = xL; i <= xR; i = i + 1) begin
                for (j = yT; j <= yB; j = j + 1) begin
                    if (shadow_fb[i][j] !== c) begin
                        $display("ERRO: pixel (%0d,%0d) esperado=%h obtido=%h", i, j, c, shadow_fb[i][j]);
                        errors = errors + 1;
                    end
                end
            end

            // Amostra alguns pontos fora da região pra confirmar que não vazou
            if (xL > 0 && shadow_fb[xL-1][yT] !== 9'h1FF) begin
                $display("ERRO: vazamento fora da borda esquerda em (%0d,%0d)", xL-1, yT);
                errors = errors + 1;
            end
            if (xR < 319 && shadow_fb[xR+1][yT] !== 9'h1FF) begin
                $display("ERRO: vazamento fora da borda direita em (%0d,%0d)", xR+1, yT);
                errors = errors + 1;
            end
            if (yT > 0 && shadow_fb[xL][yT-1] !== 9'h1FF) begin
                $display("ERRO: vazamento acima da borda superior em (%0d,%0d)", xL, yT-1);
                errors = errors + 1;
            end
            if (yB < 239 && shadow_fb[xL][yB+1] !== 9'h1FF) begin
                $display("ERRO: vazamento abaixo da borda inferior em (%0d,%0d)", xL, yB+1);
                errors = errors + 1;
            end

            if (pixels_written !== expected_count) begin
                $display("ERRO: quantidade de pixels escritos = %0d, esperado = %0d", pixels_written, expected_count);
                errors = errors + 1;
            end

            if (errors == 0)
                $display("PASSOU: regiao (%0d,%0d)-(%0d,%0d) preenchida corretamente com %0d pixels", xL, yT, xR, yB, pixels_written);
            else
                $display("FALHOU: %0d erro(s) na regiao (%0d,%0d)-(%0d,%0d)", errors, xL, yT, xR, yB);
        end
    endtask

    initial begin
        clk   = 1'b0;
        reset = 1'b1;
        start = 1'b0;
        v0x = 0; v0y = 0; v1x = 0; v1y = 0; color = 0;
        pixels_written = 0;

        repeat (3) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        // Teste 1: quadrado pequeno, cantos "corretos" (v0=sup-esq, v1=inf-dir)
        draw_square(9'd10, 8'd10, 9'd15, 8'd15, 9'b111000000); // vermelho puro
        check_region(9'd10, 9'd15, 8'd10, 8'd15, 9'b111000000);

        // Teste 2: cantos invertidos (v0=inf-dir, v1=sup-esq) -- valida
        // a normalização de xL/xR e cur_y/yMax dentro do módulo
        draw_square(9'd50, 8'd40, 9'd45, 8'd35, 9'b000111000); // verde puro
        check_region(9'd45, 9'd50, 8'd35, 8'd40, 9'b000111000);

        // Teste 3: um único pixel (v0 == v1) -- caso extremo
        draw_square(9'd100, 8'd100, 9'd100, 8'd100, 9'b000000111); // azul puro
        check_region(9'd100, 9'd100, 8'd100, 8'd100, 9'b000000111);

        // Teste 4: quadrado grande, tocando quina da tela lógica (0,0)-(319,239)
        // -- desenho na íntegra seria caro em ciclos de simulação, então
        // usamos um retângulo grande mas não a tela inteira
        draw_square(9'd0, 8'd0, 9'd50, 8'd30, 9'b101010101);
        check_region(9'd0, 9'd50, 8'd0, 8'd30, 9'b101010101);

        $display("Todos os testes concluidos.");
        $stop;
    end

endmodule