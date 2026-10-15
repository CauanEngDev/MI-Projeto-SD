`timescale 1ns/1ps

// ============================================================================
// Teste unitario da camada_composicao (escritas roteirizadas)
//   T1  sprite antes do background: o background e descartado
//   T2  mesma camada sobrescreve; camada inferior nao; superior sim
//   T3  hazard: escritas de camadas diferentes em ciclos consecutivos/proximos
//   T4  troca de bancos: o mapa do banco que volta a ser de escrita esta limpo
//   T5  clear_all libera pixels protegidos
//   T6  escritas durante a limpeza sao descartadas
// ============================================================================
module tb_camada_composicao;

    localparam BG  = 2'd1, SPR = 2'd2, RAS = 2'd3;

    reg         clk = 0;
    reg         reset = 1;
    reg         clear_all = 0;
    reg         wr_buf_sel = 1;     // mesmo valor de reset do coprocessador_top
    reg  [1:0]  engine_sel = 0;
    reg         in_we = 0;
    reg  [8:0]  in_x = 0;
    reg  [7:0]  in_y = 0;
    reg  [8:0]  in_data = 0;

    wire        fb_we;
    wire [8:0]  fb_wr_x;
    wire [7:0]  fb_wr_y;
    wire [8:0]  fb_wr_data;
    wire        init_busy, blocked;

    camada_composicao dut (
        .clk(clk), .reset(reset), .clear_all(clear_all), .wr_buf_sel(wr_buf_sel),
        .engine_sel(engine_sel),
        .in_we(in_we), .in_x(in_x), .in_y(in_y), .in_data(in_data),
        .fb_we(fb_we), .fb_wr_x(fb_wr_x), .fb_wr_y(fb_wr_y), .fb_wr_data(fb_wr_data),
        .init_busy(init_busy), .blocked(blocked)
    );

    always #5 clk = ~clk;

    // Modelo do framebuffer (2 bancos); banco = wr_buf_sel no instante da escrita
    reg [8:0] fbm [0:1][0:76799];
    integer k;
    initial for (k = 0; k < 76800; k = k + 1) begin fbm[0][k] = 9'd0; fbm[1][k] = 9'd0; end

    integer n_fb_writes = 0;
    integer n_blocked   = 0;
    always @(posedge clk) begin
        if (fb_we) begin
            fbm[wr_buf_sel][fb_wr_y * 320 + fb_wr_x] <= fb_wr_data;
            n_fb_writes = n_fb_writes + 1;
        end
        if (blocked) n_blocked = n_blocked + 1;
    end

    integer errors = 0;

    task check;
        input [255:0] nome;
        input         bank;
        input [8:0]   x;
        input [7:0]   y;
        input [8:0]   esperado;
        begin
            if (fbm[bank][y * 320 + x] !== esperado) begin
                errors = errors + 1;
                $display("ERRO  %0s: banco %0d (%0d,%0d) = %0d, esperado %0d",
                         nome, bank, x, y, fbm[bank][y * 320 + x], esperado);
            end
        end
    endtask

    // Uma escrita por ciclo (deixa in_we = 1 para permitir escritas seguidas)
    task put;
        input [1:0] sel;
        input [8:0] x;
        input [7:0] y;
        input [8:0] d;
        begin
            @(negedge clk);
            engine_sel = sel; in_we = 1; in_x = x; in_y = y; in_data = d;
        end
    endtask

    task idle;
        input integer n;
        integer j;
        begin
            @(negedge clk);
            in_we = 0; engine_sel = 0;
            for (j = 1; j < n; j = j + 1) @(negedge clk);
        end
    endtask

    task esperar_init;
        begin
            while (init_busy) @(negedge clk);
            idle(4);
        end
    endtask

    task esperar_varredura;
        begin
            repeat (76900) @(negedge clk);
        end
    endtask

    integer g;

    initial begin
        repeat (4) @(negedge clk);
        reset = 0;
        @(negedge clk);
        if (!init_busy) begin errors = errors + 1; $display("ERRO: init_busy deveria subir apos o reset"); end
        esperar_init;

        // --------------------------------------------------------------
        // T1: sprite primeiro, background depois
        // --------------------------------------------------------------
        put(SPR, 10, 10, 9'd111);
        idle(8);
        put(BG,  10, 10, 9'd001);
        idle(8);
        check("T1 sprite fica sobre o BG", 1, 10, 10, 9'd111);
        if (n_blocked !== 1) begin errors = errors + 1; $display("ERRO T1: bloqueios = %0d (esperado 1)", n_blocked); end

        // --------------------------------------------------------------
        // T2: mesma camada sobrescreve; inferior nao; superior sim
        // --------------------------------------------------------------
        put(RAS, 11, 10, 9'd010);
        idle(8);
        put(RAS, 11, 10, 9'd011);
        idle(8);
        check("T2 RAS sobrescreve RAS", 1, 11, 10, 9'd011);
        put(BG,  11, 10, 9'd001);
        idle(8);
        check("T2 BG nao cobre RAS", 1, 11, 10, 9'd011);
        put(SPR, 11, 10, 9'd100);
        idle(8);
        check("T2 SPR cobre RAS", 1, 11, 10, 9'd100);
        put(RAS, 11, 10, 9'd010);
        idle(8);
        check("T2 RAS nao cobre SPR", 1, 11, 10, 9'd100);
        put(BG,  12, 10, 9'd001);
        put(BG,  12, 10, 9'd002);
        idle(8);
        check("T2 BG sobrescreve BG", 1, 12, 10, 9'd002);

        // --------------------------------------------------------------
        // T3: hazard - sprite e depois BG/RAS com 0..4 ciclos de intervalo
        //     (0 = ciclos consecutivos, exercita o encaminhamento de S2/S3)
        // --------------------------------------------------------------
        for (g = 0; g <= 4; g = g + 1) begin
            put(SPR, 20 + g, 20, 9'd100 + g);
            if (g > 0) idle(g);
            put(BG,  20 + g, 20, 9'd001);
            put(RAS, 20 + g, 20, 9'd010);
            idle(8);
            check("T3 sprite vence BG/RAS proximos", 1, 20 + g, 20, 9'd100 + g);
        end
        // BG, RAS, SPR em ciclos consecutivos: a cada escrita a camada sobe
        put(BG,  30, 20, 9'd001);
        put(RAS, 30, 20, 9'd002);
        put(SPR, 30, 20, 9'd003);
        put(RAS, 30, 20, 9'd004);
        put(BG,  30, 20, 9'd005);
        idle(8);
        check("T3 BG>RAS>SPR consecutivos", 1, 30, 20, 9'd003);

        // --------------------------------------------------------------
        // T4: troca de bancos
        //     (10,10) esta protegido por sprite no banco 1; apos a troca o
        //     banco 0 e o de escrita e o mapa dele esta limpo
        // --------------------------------------------------------------
        @(negedge clk); wr_buf_sel = 0;           // frame_swap do top
        idle(4);
        put(BG, 10, 10, 9'd001);                  // banco 0, mapa limpo
        idle(8);
        check("T4 banco 0 aceita BG", 0, 10, 10, 9'd001);
        esperar_varredura;                         // mapa do banco 1 e zerado
        @(negedge clk); wr_buf_sel = 1;           // proxima troca
        idle(4);
        put(BG, 10, 10, 9'd007);                  // banco 1 voltou: mapa limpo
        idle(8);
        check("T4 banco 1 limpo apos varredura", 1, 10, 10, 9'd007);
        put(SPR, 10, 10, 9'd100);
        idle(8);
        check("T4 sprite no banco 1", 1, 10, 10, 9'd100);

        // --------------------------------------------------------------
        // T5: clear_all libera pixels protegidos
        // --------------------------------------------------------------
        @(negedge clk); clear_all = 1;
        @(negedge clk); clear_all = 0;
        esperar_init;
        put(BG, 10, 10, 9'd009);
        idle(8);
        check("T5 BG apos clear_all", 1, 10, 10, 9'd009);

        // --------------------------------------------------------------
        // T6: escritas durante a limpeza sao descartadas
        // --------------------------------------------------------------
        put(SPR, 40, 40, 9'd100);
        idle(8);
        n_fb_writes = 0;
        @(negedge clk); clear_all = 1;
        in_we = 1; engine_sel = BG; in_x = 41; in_y = 40; in_data = 9'd001;
        @(negedge clk); clear_all = 0;
        in_x = 42; in_data = 9'd001;
        @(negedge clk); in_x = 43;
        @(negedge clk); in_we = 0;
        esperar_init;
        if (n_fb_writes !== 0) begin
            errors = errors + 1;
            $display("ERRO T6: %0d escritas passaram durante a limpeza", n_fb_writes);
        end
        put(BG, 40, 40, 9'd001);                  // mapa limpo: BG volta a poder escrever
        idle(8);
        check("T6 mapa zerado apos limpeza", 1, 40, 40, 9'd001);

        $display("");
        if (errors == 0) $display("tb_camada_composicao: TODOS OS TESTES PASSARAM (bloqueios contados: %0d)", n_blocked);
        else             $display("tb_camada_composicao: %0d ERRO(S)", errors);
        $finish;
    end

    // Guarda contra travamento
    initial begin
        #(10 * 600000);
        $display("TIMEOUT");
        $finish;
    end

endmodule
