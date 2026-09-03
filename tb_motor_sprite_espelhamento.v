`timescale 1ns/1ps

module tb_motor_sprite_espelhamento;

    // ============================================================
    // CLOCK / RESET
    // ============================================================

    reg clk;
    reg reset;

    always #10 clk = ~clk;


    // ============================================================
    // CONTROLE
    // ============================================================

    reg start;

    wire busy;
    wire done;


    // ============================================================
    // INTERFACE ATTRIBUTE RAM
    // ============================================================

    wire [4:0] attr_rd_addr;
    reg  [31:0] attr_rd_data;


    // ============================================================
    // INTERFACE PATTERN RAM
    // ============================================================

    wire [13:0] pattern_rd_addr;
    reg  [7:0] pattern_rd_data;


    // ============================================================
    // INTERFACE PALETTE RAM
    // ============================================================

    wire [8:0] palette_rd_addr;
    reg  [8:0] palette_rd_data;


    // ============================================================
    // INTERFACE FRAMEBUFFER
    // ============================================================

    wire       fb_we;
    wire [8:0] fb_wr_x;
    wire [7:0] fb_wr_y;
    wire [8:0] fb_wr_data;


    // ============================================================
    // MEMÓRIAS COMPORTAMENTAIS
    // ============================================================

    reg [31:0] attr_mem [0:31];

    reg [7:0] pattern_mem [0:16383];

    reg [8:0] palette_mem [0:511];


    // ============================================================
    // IMAGEM GERADA PELO MOTOR
    //
    // Usada apenas pelo testbench para registrar as escritas.
    // ============================================================

    reg [8:0] framebuffer_test [0:319][0:239];


    // ============================================================
    // LEITURA COMBINACIONAL DAS MEMÓRIAS
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
    // CONTADORES
    // ============================================================

    integer errors;
    integer writes;
    integer i;
    integer x;
    integer y;


    // ============================================================
    // REGISTRA TODAS AS ESCRITAS DO MOTOR
    // ============================================================

    always @(posedge clk) begin

        if (fb_we) begin

            writes = writes + 1;

            framebuffer_test[fb_wr_x][fb_wr_y] <= fb_wr_data;

            $display(
                "WRITE: (%0d,%0d) = %03h",
                fb_wr_x,
                fb_wr_y,
                fb_wr_data
            );

        end

    end


    // ============================================================
    // LIMPA MEMÓRIAS
    // ============================================================

    task clear_memories;

        integer k;

        begin

            for (k = 0; k < 32; k = k + 1)
                attr_mem[k] = 32'd0;

            for (k = 0; k < 16384; k = k + 1)
                pattern_mem[k] = 8'd0;

            for (k = 0; k < 512; k = k + 1)
                palette_mem[k] = 9'd0;

        end

    endtask


    // ============================================================
    // LIMPA FRAMEBUFFER DE TESTE
    // ============================================================

    task clear_framebuffer;

        integer xx;
        integer yy;

        begin

            for (xx = 0; xx < 320; xx = xx + 1) begin

                for (yy = 0; yy < 240; yy = yy + 1) begin

                    framebuffer_test[xx][yy] = 9'd0;

                end

            end

        end

    endtask


    // ============================================================
    // CONFIGURA PADRÃO 16x16
    //
    // Padrão:
    //
    // X...............
    // X...............
    // X...............
    // X...............
    // X...............
    // X...............
    // X...............
    // X...............
    // X...............
    // X...............
    // X...............
    // X...............
    // X...............
    // X...............
    // X...............
    // XXXXXXXXXXXXXXXX
    //
    // X = índice de cor 1
    // . = índice de cor 0 (transparente)
    //
    // São utilizados quatro tiles 8x8:
    //
    // tile 0 -> superior esquerdo
    // tile 1 -> superior direito
    // tile 2 -> inferior esquerdo
    // tile 3 -> inferior direito
    // ============================================================

    task configure_pattern;

        integer px;
        integer py;
        integer tile_id;
        integer sub_x;
        integer sub_y;

        begin

            // Primeiro deixa toda a memória transparente.

            for (px = 0; px < 16384; px = px + 1)
                pattern_mem[px] = 8'd0;


            // Monta os quatro tiles.

            for (py = 0; py < 16; py = py + 1) begin

                for (px = 0; px < 16; px = px + 1) begin

                    // Barra vertical esquerda
                    // ou barra horizontal inferior.

                    if ((px == 0) || (py == 15)) begin

                        tile_id =
                            ((py >= 8) ? 2 : 0) +
                            ((px >= 8) ? 1 : 0);

                        sub_x = px % 8;
                        sub_y = py % 8;

                        pattern_mem[
                            (tile_id * 64) +
                            (sub_y * 8) +
                            sub_x
                        ] = 8'd1;

                    end

                end

            end

        end

    endtask


    // ============================================================
    // CONFIGURA PALETA
    //
    // Índice 1 -> branco
    // ============================================================

    task configure_palette;

        begin

            palette_mem[0] = 9'b000000000;

            palette_mem[1] = 9'b111111111;

        end

    endtask


    // ============================================================
    // CONFIGURA SPRITE
    // ============================================================

    task configure_sprite;

        input flip_h;
        input flip_v;

        begin

            attr_mem[0] = {
                1'b1,       // enable
                5'd0,       // priority
                flip_v,     // flip_v
                flip_h,     // flip_h
                1'b0,       // palette_sel
                6'd0,       // pattern
                8'd50,      // pos_y
                9'd50       // pos_x
            };

        end

    endtask


    // ============================================================
    // EXECUTA MOTOR
    // ============================================================

    task run_sprite;

        begin

            writes = 0;

            @(posedge clk);

            start <= 1'b1;

            @(posedge clk);

            start <= 1'b0;

            wait(done == 1'b1);

            @(posedge clk);

        end

    endtask


    // ============================================================
    // VERIFICA RESULTADO DO CENÁRIO
    //
    // Calcula matematicamente onde cada pixel opaco deveria
    // aparecer considerando flip_h e flip_v.
    // ============================================================

    task verify_sprite;

        input flip_h;
        input flip_v;

        integer sx;
        integer sy;

        integer src_x;
        integer src_y;

        integer expected_x;
        integer expected_y;

        integer expected;

        begin

            $display("");
            $display("Verificando imagem gerada...");


            // Percorre toda a sprite original.

            for (sy = 0; sy < 16; sy = sy + 1) begin

                for (sx = 0; sx < 16; sx = sx + 1) begin

                    // Pixel opaco do padrão original.

                    if ((sx == 0) || (sy == 15))
                        expected = 1;
                    else
                        expected = 0;


                    // ------------------------------------------------
                    // Transformação horizontal
                    // ------------------------------------------------

                    if (flip_h)
                        src_x = 15 - sx;
                    else
                        src_x = sx;


                    // ------------------------------------------------
                    // Transformação vertical
                    // ------------------------------------------------

                    if (flip_v)
                        src_y = 15 - sy;
                    else
                        src_y = sy;


                    // ------------------------------------------------
                    // Destino na tela
                    // ------------------------------------------------

                    expected_x = 50 + sx;
                    expected_y = 50 + sy;


                    // ------------------------------------------------
                    // Se o pixel deveria ser opaco,
                    // esperamos branco no framebuffer.
                    // ------------------------------------------------

                    if (expected != 0) begin

                        if (framebuffer_test[expected_x][expected_y]
                            !== 9'b111111111) begin

                            $display(
                                "ERRO: pixel esperado em (%0d,%0d), encontrado %03h",
                                expected_x,
                                expected_y,
                                framebuffer_test[
                                    expected_x
                                ][
                                    expected_y
                                ]
                            );

                            errors = errors + 1;

                        end

                    end

                    // ------------------------------------------------
                    // Se deveria ser transparente, não esperamos
                    // escrita.
                    // ------------------------------------------------

                    else begin

                        if (framebuffer_test[expected_x][expected_y]
                            !== 9'b000000000) begin

                            $display(
                                "ERRO: pixel transparente em (%0d,%0d) foi escrito como %03h",
                                expected_x,
                                expected_y,
                                framebuffer_test[
                                    expected_x
                                ][
                                    expected_y
                                ]
                            );

                            errors = errors + 1;

                        end

                    end

                end

            end

        end

    endtask


    // ============================================================
    // CENÁRIO 1
    //
    // SPRITE ORIGINAL
    // ============================================================

    task test_baseline;

        begin

            $display("");
            $display("====================================================");
            $display("CENARIO 1: SPRITE ORIGINAL");
            $display("====================================================");

            clear_memories();

            clear_framebuffer();

            configure_pattern();

            configure_palette();

            configure_sprite(
                1'b0,
                1'b0
            );


            run_sprite();


            // O padrão possui:
            //
            // 16 pixels da coluna
            // + 15 pixels restantes da linha
            //
            // = 31 pixels.

            if (writes != 31) begin

                $display(
                    "ERRO: foram geradas %0d escritas; esperado = 31",
                    writes
                );

                errors = errors + 1;

            end

            else begin

                $display(
                    "PASSOU: quantidade de pixels opacos = %0d",
                    writes
                );

            end


            verify_sprite(
                1'b0,
                1'b0
            );

        end

    endtask


    // ============================================================
    // CENÁRIO 2
    //
    // FLIP HORIZONTAL
    // ============================================================

    task test_flip_h;

        begin

            $display("");
            $display("====================================================");
            $display("CENARIO 2: FLIP HORIZONTAL");
            $display("====================================================");

            clear_memories();

            clear_framebuffer();

            configure_pattern();

            configure_palette();

            configure_sprite(
                1'b1,
                1'b0
            );


            run_sprite();


            if (writes != 31) begin

                $display(
                    "ERRO: foram geradas %0d escritas; esperado = 31",
                    writes
                );

                errors = errors + 1;

            end

            else begin

                $display(
                    "PASSOU: quantidade de pixels apos flip_h = %0d",
                    writes
                );

            end


            // Com flip_h, a barra vertical esquerda
            // deve aparecer no lado direito da sprite.

            for (y = 50; y <= 65; y = y + 1) begin

                if (framebuffer_test[65][y] !== 9'b111111111) begin

                    $display(
                        "ERRO flip_h: esperado pixel em (%0d,%0d)",
                        65,
                        y
                    );

                    errors = errors + 1;

                end

            end


            // A linha inferior continua horizontal.

            for (x = 50; x <= 65; x = x + 1) begin

                if (framebuffer_test[x][65] !== 9'b111111111) begin

                    $display(
                        "ERRO flip_h: esperado pixel em (%0d,%0d)",
                        x,
                        65
                    );

                    errors = errors + 1;

                end

            end


            $display("Verificacao de flip_h concluida.");

        end

    endtask


    // ============================================================
    // CENÁRIO 3
    //
    // FLIP VERTICAL
    // ============================================================

    task test_flip_v;

        begin

            $display("");
            $display("====================================================");
            $display("CENARIO 3: FLIP VERTICAL");
            $display("====================================================");

            clear_memories();

            clear_framebuffer();

            configure_pattern();

            configure_palette();

            configure_sprite(
                1'b0,
                1'b1
            );


            run_sprite();


            if (writes != 31) begin

                $display(
                    "ERRO: foram geradas %0d escritas; esperado = 31",
                    writes
                );

                errors = errors + 1;

            end

            else begin

                $display(
                    "PASSOU: quantidade de pixels apos flip_v = %0d",
                    writes
                );

            end


            // Com flip_v, a linha inferior original
            // deve aparecer no topo.

            for (x = 50; x <= 65; x = x + 1) begin

                if (framebuffer_test[x][50] !== 9'b111111111) begin

                    $display(
                        "ERRO flip_v: esperado pixel em (%0d,%0d)",
                        x,
                        50
                    );

                    errors = errors + 1;

                end

            end


            // A barra vertical passa para a parte inferior.

            for (y = 50; y <= 65; y = y + 1) begin

                if (framebuffer_test[50][y] !== 9'b111111111) begin

                    $display(
                        "ERRO flip_v: esperado pixel em (%0d,%0d)",
                        50,
                        y
                    );

                    errors = errors + 1;

                end

            end


            $display("Verificacao de flip_v concluida.");

        end

    endtask


    // ============================================================
    // CENÁRIO 4
    //
    // FLIP HORIZONTAL + VERTICAL
    // ============================================================

    task test_flip_hv;

        begin

            $display("");
            $display("====================================================");
            $display("CENARIO 4: FLIP HORIZONTAL + VERTICAL");
            $display("====================================================");

            clear_memories();

            clear_framebuffer();

            configure_pattern();

            configure_palette();

            configure_sprite(
                1'b1,
                1'b1
            );


            run_sprite();


            if (writes != 31) begin

                $display(
                    "ERRO: foram geradas %0d escritas; esperado = 31",
                    writes
                );

                errors = errors + 1;

            end

            else begin

                $display(
                    "PASSOU: quantidade de pixels apos flip_hv = %0d",
                    writes
                );

            end


            // Com flip_h + flip_v:
            //
            // barra vertical -> direita
            // barra horizontal -> topo


            for (y = 50; y <= 65; y = y + 1) begin

                if (framebuffer_test[65][y] !== 9'b111111111) begin

                    $display(
                        "ERRO flip_hv: esperado pixel em (%0d,%0d)",
                        65,
                        y
                    );

                    errors = errors + 1;

                end

            end


            for (x = 50; x <= 65; x = x + 1) begin

                if (framebuffer_test[x][50] !== 9'b111111111) begin

                    $display(
                        "ERRO flip_hv: esperado pixel em (%0d,%0d)",
                        x,
                        50
                    );

                    errors = errors + 1;

                end

            end


            $display("Verificacao de flip_hv concluida.");

        end

    endtask


    // ============================================================
    // TESTE PRINCIPAL
    // ============================================================

    initial begin

        clk   = 1'b0;
        reset = 1'b1;
        start = 1'b0;

        errors = 0;
        writes = 0;


        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------

        repeat (5)
            @(posedge clk);

        reset = 1'b0;

        @(posedge clk);


        // --------------------------------------------------------
        // EXECUTA TESTES
        // --------------------------------------------------------

        test_baseline;

        test_flip_h;

        test_flip_v;

        test_flip_hv;


        // --------------------------------------------------------
        // RESULTADO FINAL
        // --------------------------------------------------------

        $display("");
        $display("====================================================");
        $display("RESULTADO FINAL - ESPELHAMENTO");
        $display("====================================================");

        $display(
            "Falhas detectadas: %0d",
            errors
        );

        $display("====================================================");


        if (errors == 0) begin

            $display("");
            $display(">>> TESTE DE ESPELHAMENTO: PASSOU <<<");
            $display("");

        end

        else begin

            $display("");
            $display(">>> TESTE DE ESPELHAMENTO: FALHOU <<<");
            $display("");

        end


        $stop;

    end


    // ============================================================
    // TIMEOUT
    // ============================================================

    initial begin

        #500000;

        $display("");
        $display("====================================================");
        $display("TIMEOUT");
        $display("O motor_sprite nao terminou.");
        $display("====================================================");

        $stop;

    end

endmodule

