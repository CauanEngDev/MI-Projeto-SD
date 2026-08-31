`timescale 1ns / 1ps

module tb_rasterizer_triangle;

    reg clk;
    reg reset;
    reg start;
    reg [8:0] v0x, v1x, v2x;
    reg [7:0] v0y, v1y, v2y;
    reg [8:0] color;

    wire fb_we;
    wire [8:0] fb_wr_x;
    wire [7:0] fb_wr_y;
    wire [8:0] fb_wr_data;
    wire busy;
    wire done;

    // Registra, por linha (Y), o menor e maior X escrito -- isso é o
    // suficiente para comparar contra o preenchimento esperado (scanline
    // fill sempre escreve um intervalo contíguo [xL,xR] por linha).
    reg [8:0] row_min [0:239];
    reg [8:0] row_max [0:239];
    reg       row_touched [0:239];
    integer   pixels_written;
    integer   i;

    rasterizador_triangulo #(.FX_BITS(8)) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .v0x(v0x), .v1x(v1x), .v2x(v2x),
        .v0y(v0y), .v1y(v1y), .v2y(v2y),
        .color(color),
        .fb_we(fb_we),
        .fb_wr_x(fb_wr_x),
        .fb_wr_y(fb_wr_y),
        .fb_wr_data(fb_wr_data),
        .busy(busy),
        .done(done)
    );

    always #10 clk = ~clk; // 50 MHz

    always @(posedge clk) begin
        if (fb_we) begin
            if (!row_touched[fb_wr_y]) begin
                row_touched[fb_wr_y] <= 1'b1;
                row_min[fb_wr_y] <= fb_wr_x;
                row_max[fb_wr_y] <= fb_wr_x;
            end else begin
                if (fb_wr_x < row_min[fb_wr_y]) row_min[fb_wr_y] <= fb_wr_x;
                if (fb_wr_x > row_max[fb_wr_y]) row_max[fb_wr_y] <= fb_wr_x;
            end
            pixels_written <= pixels_written + 1;
        end
    end

    task clear_rows;
        integer k;
        begin
            for (k = 0; k < 240; k = k + 1) begin
                row_touched[k] = 1'b0;
                row_min[k] = 9'd0;
                row_max[k] = 9'd0;
            end
            pixels_written = 0;
        end
    endtask

    task draw_triangle(
        input [8:0] ax, input [7:0] ay,
        input [8:0] bx, input [7:0] by,
        input [8:0] cx, input [7:0] cy,
        input [8:0] c
    );
        begin
            clear_rows;
            @(posedge clk);
            v0x <= ax; v0y <= ay;
            v1x <= bx; v1y <= by;
            v2x <= cx; v2y <= cy;
            color <= c;
            start <= 1'b1;
            @(posedge clk);
            start <= 1'b0;
            wait (done == 1'b1);
            @(posedge clk);
        end
    endtask

    // Verificação por geometria: recalcula, em ponto flutuante, o
    // intervalo [xL,xR] esperado para cada linha Y usando interpolação
    // linear entre as arestas do triângulo (mesmo modelo que o hardware
    // implementa, só que sem erro de truncamento de ponto fixo).
    // Tolerância de +-1 pixel por borda absorve diferenças de
    // arredondamento entre ponto flutuante e Q9.8 truncado.
    task check_triangle(
        input [8:0] ax, input [7:0] ay,
        input [8:0] bx, input [7:0] by,
        input [8:0] cx, input [7:0] cy,
        input integer tolerance
    );
        real sx0r, sx1r, sx2r;
        integer sy0i, sy1i, sy2i;
        real tax, tbx, tcx;
        integer tay, tby, tcy;
        real x_long, x_short;
        real slope_long, slope_short;
        integer y;
        integer errors;
        real exp_xL, exp_xR, tmp;
        begin
            errors = 0;

            // Ordena por Y (mesma regra do módulo: v0<=v1<=v2)
            if (ay <= by) begin
                if (by <= cy) begin
                    tax=ax; tay=ay; tbx=bx; tby=by; tcx=cx; tcy=cy;
                end else if (ay <= cy) begin
                    tax=ax; tay=ay; tbx=cx; tby=cy; tcx=bx; tcy=by;
                end else begin
                    tax=cx; tay=cy; tbx=ax; tby=ay; tcx=bx; tcy=by;
                end
            end else begin
                if (ay <= cy) begin
                    tax=bx; tay=by; tbx=ax; tby=ay; tcx=cx; tcy=cy;
                end else if (by <= cy) begin
                    tax=bx; tay=by; tbx=cx; tby=cy; tcx=ax; tcy=ay;
                end else begin
                    tax=cx; tay=cy; tbx=bx; tby=by; tcx=ax; tcy=ay;
                end
            end

            sy0i = tay; sy1i = tby; sy2i = tcy;

            if (sy2i == sy0i) begin
                $display("AVISO: triangulo degenerado (todos os Y iguais), pulando checagem geometrica");
            end else begin
                slope_long = (tcx - tax) / (sy2i - sy0i);

                for (y = sy0i; y <= sy2i; y = y + 1) begin
                    x_long = tax + slope_long * (y - sy0i);

                    if (y < sy1i) begin
                        if (sy1i == sy0i) x_short = tax;
                        else begin
                            slope_short = (tbx - tax) / (sy1i - sy0i);
                            x_short = tax + slope_short * (y - sy0i);
                        end
                    end else begin
                        if (sy2i == sy1i) x_short = tbx;
                        else begin
                            slope_short = (tcx - tbx) / (sy2i - sy1i);
                            x_short = tbx + slope_short * (y - sy1i);
                        end
                    end

                    exp_xL = (x_long < x_short) ? x_long : x_short;
                    exp_xR = (x_long < x_short) ? x_short : x_long;

                    if (!row_touched[y]) begin
                        $display("ERRO: linha y=%0d esperava preenchimento [%.1f,%.1f], mas nao foi escrita", y, exp_xL, exp_xR);
                        errors = errors + 1;
                    end else begin
                        if ($itor(row_min[y]) < exp_xL - tolerance || $itor(row_min[y]) > exp_xL + tolerance) begin
                            $display("ERRO: linha y=%0d xL obtido=%0d esperado~=%.1f", y, row_min[y], exp_xL);
                            errors = errors + 1;
                        end
                        if ($itor(row_max[y]) < exp_xR - tolerance || $itor(row_max[y]) > exp_xR + tolerance) begin
                            $display("ERRO: linha y=%0d xR obtido=%0d esperado~=%.1f", y, row_max[y], exp_xR);
                            errors = errors + 1;
                        end
                    end
                end
            end

            if (errors == 0)
                $display("PASSOU: triangulo (%0d,%0d)-(%0d,%0d)-(%0d,%0d), %0d pixels escritos", ax,ay,bx,by,cx,cy, pixels_written);
            else
                $display("FALHOU: triangulo (%0d,%0d)-(%0d,%0d)-(%0d,%0d), %0d erro(s)", ax,ay,bx,by,cx,cy, errors);
        end
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        start = 1'b0;
        v0x=0; v0y=0; v1x=0; v1y=0; v2x=0; v2y=0; color=0;
        clear_rows;

        repeat (3) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        // Teste 1: triangulo "normal", sem aresta horizontal, ponta pra cima
        draw_triangle(9'd30, 8'd10, 9'd10, 8'd50, 9'd50, 8'd50, 9'b111000000);
        check_triangle(9'd30, 8'd10, 9'd10, 8'd50, 9'd50, 8'd50, 1);

        // Teste 2: aresta superior horizontal (sy0 == sy1) -- ponta pra baixo
        draw_triangle(9'd10, 8'd10, 9'd50, 8'd10, 9'd30, 8'd50, 9'b000111000);
        check_triangle(9'd10, 8'd10, 9'd50, 8'd10, 9'd30, 8'd50, 1);

        // Teste 3: aresta inferior horizontal (sy1 == sy2) -- ponta pra cima
        draw_triangle(9'd30, 8'd10, 9'd10, 8'd50, 9'd50, 8'd50, 9'b000000111);
        check_triangle(9'd30, 8'd10, 9'd10, 8'd50, 9'd50, 8'd50, 1);

        // Teste 4: aresta quase vertical (dx pequeno, dy grande)
        draw_triangle(9'd100, 8'd10, 9'd102, 8'd100, 9'd150, 8'd60, 9'b101010101);
        check_triangle(9'd100, 8'd10, 9'd102, 8'd100, 9'd150, 8'd60, 1);

        // Teste 5: aresta quase horizontal (dx grande, dy pequeno)
        draw_triangle(9'd10, 8'd80, 9'd200, 8'd82, 9'd100, 8'd120, 9'b110011001);
        check_triangle(9'd10, 8'd80, 9'd200, 8'd82, 9'd100, 8'd120, 1);

        // Teste 6: triangulo pequeno/degenerado -- 1 linha de altura
        draw_triangle(9'd200, 8'd200, 9'd210, 8'd200, 9'd205, 8'd201, 9'b011011011);
        check_triangle(9'd200, 8'd200, 9'd210, 8'd200, 9'd205, 8'd201, 1);

        $display("Todos os testes concluidos.");
        $stop;
    end

endmodule