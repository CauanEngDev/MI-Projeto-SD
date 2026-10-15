`timescale 1ns/1ps

// ============================================================================
// Integracao: motores reais (background, sprites, rasterizador) + engine_mux +
// camada_composicao, com as RAMs modeladas com a mesma latencia das IPs
// (registrador de endereco + registrador de saida = 2 ciclos).
//
// O "programa" e emulado como a unidade de controle faz: engine_sel fixo
// durante a operacao, start de 1 ciclo, espera pelo done.
//
// Cena: fundo (indice 1), retangulo (indice 2) e sprite 16x16 (indice 3), com
// retangulo e sprite sobrepostos. Ordens testadas:
//     A: BG, RECT, SPR   (ordem "correta")
//     B: SPR, RECT, BG   (invertida)
//     C: RECT, SPR, BG   (fundo por ultimo)
//     D: SPR, BG, RECT, RECT (rasterizador repetido)
// O quadro final (banco de escrita) precisa ser identico em todas as ordens e
// igual ao esperado: sprite > retangulo > fundo.
// Tambem verifica que, SEM a camada, a ordem invertida produz outro quadro
// (mostra que o teste detecta o problema).
// ============================================================================
module tb_composicao_ordem_desenho;

    localparam BG = 2'd1, SPR = 2'd2, RAS = 2'd3;

    reg clk = 0;
    reg reset = 1;
    always #5 clk = ~clk;

    // ---- controle emulado ----
    reg [1:0] engine_sel = 0;
    reg       start_bg = 0, start_spr = 0, start_sq = 0;
    reg       clear_all = 0;
    reg       wr_buf_sel = 1;

    // ---- memorias de conteudo ----
    reg [8:0] palette_mem [0:511];
    reg [7:0] tile_mem    [0:2047];
    reg [7:0] tpat_mem    [0:16383];
    reg [7:0] spat_mem    [0:16383];

    // leitura com 2 ciclos de latencia (como o altsyncram das IPs)
    reg [10:0] tile_a_r;   reg [7:0] tile_q;
    reg [13:0] tpat_a_r;   reg [7:0] tpat_q;
    reg [13:0] spat_a_r;   reg [7:0] spat_q;
    reg [8:0]  pal_a_r;    reg [8:0] pal_q;

    wire [10:0] bg_tile_addr;
    wire [13:0] bg_pat_addr, spr_pat_addr;
    wire [8:0]  bg_pal_addr, spr_pal_addr, ras_pal_addr, pal_rd_addr;

    always @(posedge clk) begin
        tile_a_r <= bg_tile_addr;  tile_q <= tile_mem[tile_a_r];
        tpat_a_r <= bg_pat_addr;   tpat_q <= tpat_mem[tpat_a_r];
        spat_a_r <= spr_pat_addr;  spat_q <= spat_mem[spat_a_r];
        pal_a_r  <= pal_rd_addr;   pal_q  <= palette_mem[pal_a_r];
    end

    // ---- motores ----
    wire bg_fb_we, spr_fb_we, ras_fb_we;
    wire [8:0] bg_fb_x, spr_fb_x, ras_fb_x;
    wire [7:0] bg_fb_y, spr_fb_y, ras_fb_y;
    wire [8:0] bg_fb_d, spr_fb_d, ras_fb_d;
    wire done_bg, done_spr, done_ras, ras_invalid;

    // parametros do rasterizador
    reg [8:0] v0x = 100, v1x = 139;
    reg [7:0] v0y = 100, v1y = 139;

    motor_background u_bg (
        .clk(clk), .reset(reset),
        .scroll_wr_en(1'b0), .scroll_sel(1'b0), .scroll_wr_data(9'd0),
        .scroll_auto_en(1'b0), .scroll_auto_axis(1'b0), .scroll_auto_dir(1'b0), .scroll_auto_step(8'd0),
        .tile_rd_addr(bg_tile_addr), .tile_rd_data(tile_q),
        .pattern_rd_addr(bg_pat_addr), .pattern_rd_data(tpat_q),
        .palette_rd_addr(bg_pal_addr), .palette_rd_data(pal_q),
        .fb_we(bg_fb_we), .fb_wr_x(bg_fb_x), .fb_wr_y(bg_fb_y), .fb_wr_data(bg_fb_d),
        .start(start_bg), .busy(), .done(done_bg)
    );

    reg        spos_we = 0, sattr_we = 0;
    reg [4:0]  spr_id = 0;
    reg [16:0] spos_d = 0;
    reg [14:0] sattr_d = 0;

    motor_sprite u_spr (
        .clk(clk), .reset(reset),
        .spos_we(spos_we), .spos_wr_addr(spr_id), .spos_wr_data(spos_d),
        .sattr_we(sattr_we), .sattr_wr_addr(spr_id), .sattr_wr_data(sattr_d),
        .pattern_rd_addr(spr_pat_addr), .pattern_rd_data(spat_q),
        .palette_rd_addr(spr_pal_addr), .palette_rd_data(pal_q),
        .fb_we(spr_fb_we), .fb_wr_x(spr_fb_x), .fb_wr_y(spr_fb_y), .fb_wr_data(spr_fb_d),
        .start(start_spr), .busy(), .done(done_spr)
    );

    rasterizador_top u_ras (
        .clk(clk), .reset(reset),
        .start_square(start_sq), .start_triangle(1'b0),
        .v0x(v0x), .v1x(v1x), .v2x(9'd0),
        .v0y(v0y), .v1y(v1y), .v2y(8'd0),
        .color_index(8'd2), .palette_sel(1'b0),
        .palette_rd_addr(ras_pal_addr), .palette_rd_data(pal_q),
        .fb_we(ras_fb_we), .fb_wr_x(ras_fb_x), .fb_wr_y(ras_fb_y), .fb_wr_data(ras_fb_d),
        .busy(), .done(done_ras), .invalid_cmd(ras_invalid)
    );

    // ---- mux + camada de composicao ----
    wire        mux_we;  wire [8:0] mux_x; wire [7:0] mux_y; wire [8:0] mux_d;
    wire        fb_we;   wire [8:0] fb_x;  wire [7:0] fb_y;  wire [8:0] fb_d;
    wire        init_busy, blocked;

    engine_mux u_mux (
        .engine_sel(engine_sel),
        .bg_pal_addr(bg_pal_addr),   .bg_fb_we(bg_fb_we),   .bg_fb_x(bg_fb_x),   .bg_fb_y(bg_fb_y),   .bg_fb_data(bg_fb_d),
        .spr_pal_addr(spr_pal_addr), .spr_fb_we(spr_fb_we), .spr_fb_x(spr_fb_x), .spr_fb_y(spr_fb_y), .spr_fb_data(spr_fb_d),
        .ras_pal_addr(ras_pal_addr), .ras_fb_we(ras_fb_we), .ras_fb_x(ras_fb_x), .ras_fb_y(ras_fb_y), .ras_fb_data(ras_fb_d),
        .pal_rd_addr(pal_rd_addr),
        .fb_we(mux_we), .fb_wr_x(mux_x), .fb_wr_y(mux_y), .fb_wr_data(mux_d)
    );

    camada_composicao u_comp (
        .clk(clk), .reset(reset), .clear_all(clear_all), .wr_buf_sel(wr_buf_sel),
        .engine_sel(engine_sel),
        .in_we(mux_we), .in_x(mux_x), .in_y(mux_y), .in_data(mux_d),
        .fb_we(fb_we), .fb_wr_x(fb_x), .fb_wr_y(fb_y), .fb_wr_data(fb_d),
        .init_busy(init_busy), .blocked(blocked)
    );

    // ---- framebuffers de teste: com a camada (comp) e sem ela (raw) ----
    reg [8:0] fb_comp [0:76799];
    reg [8:0] fb_raw  [0:76799];
    integer   n_blocked = 0;

    always @(posedge clk) begin
        if (fb_we)  fb_comp[fb_y * 320 + fb_x]   <= fb_d;
        if (mux_we) fb_raw [mux_y * 320 + mux_x] <= mux_d;
        if (blocked) n_blocked = n_blocked + 1;
    end

    // ---- cores ----
    localparam [8:0] C_BG  = 9'b000_001_000;
    localparam [8:0] C_RAS = 9'b111_000_000;
    localparam [8:0] C_SPR = 9'b000_000_111;

    // ---- execucao de uma "instrucao de desenho" ----
    task draw;
        input [1:0] sel;
        integer guard;
        begin
            @(negedge clk);
            engine_sel = sel;
            start_bg  = (sel == BG);
            start_spr = (sel == SPR);
            start_sq  = (sel == RAS);
            @(negedge clk);
            start_bg = 0; start_spr = 0; start_sq = 0;
            guard = 0;
            while (!((sel == BG && done_bg) || (sel == SPR && done_spr) || (sel == RAS && (done_ras || ras_invalid)))
                   && guard < 3_000_000) begin
                @(negedge clk);
                guard = guard + 1;
            end
            if (guard >= 3_000_000) begin
                $display("TIMEOUT aguardando o motor %0d", sel);
                $finish;
            end
            // a busca leva alguns ciclos para trocar de instrucao
            repeat (4) @(negedge clk);
            engine_sel = 0;
            repeat (2) @(negedge clk);
        end
    endtask

    task novo_quadro;
        integer i;
        begin
            @(negedge clk); clear_all = 1;
            @(negedge clk); clear_all = 0;
            while (init_busy) @(negedge clk);
            repeat (4) @(negedge clk);
            for (i = 0; i < 76800; i = i + 1) begin fb_comp[i] = 9'h1FF; fb_raw[i] = 9'h1FF; end
        end
    endtask

    // ---- esperado ----
    function [8:0] esperado;
        input integer x, y;
        begin
            if (x >= 120 && x < 136 && y >= 120 && y < 136)      esperado = C_SPR;
            else if (x >= 100 && x <= 139 && y >= 100 && y <= 139) esperado = C_RAS;
            else                                                   esperado = C_BG;
        end
    endfunction

    reg [8:0] ref_img [0:76799];       // quadro da ordem A
    integer errors = 0;

    task conferir;
        input [399:0] nome;
        input         comparar_com_ref;
        integer x, y, e_exp, e_ref;
        begin
            e_exp = 0; e_ref = 0;
            for (y = 0; y < 240; y = y + 1)
                for (x = 0; x < 320; x = x + 1) begin
                    if (fb_comp[y*320+x] !== esperado(x, y)) e_exp = e_exp + 1;
                    if (comparar_com_ref && fb_comp[y*320+x] !== ref_img[y*320+x]) e_ref = e_ref + 1;
                end
            if (e_exp != 0 || e_ref != 0) begin
                errors = errors + 1;
                $display("ERRO  %0s: %0d pixels diferentes do esperado, %0d diferentes da ordem A", nome, e_exp, e_ref);
            end
            else
                $display("ok    %0s: quadro correto (sprite > retangulo > fundo)", nome);
        end
    endtask

    integer i, diff_raw;

    initial begin
        // conteudo das memorias
        for (i = 0; i < 512;   i = i + 1) palette_mem[i] = 9'd0;
        for (i = 0; i < 2048;  i = i + 1) tile_mem[i]    = 8'd0;   // tilemap todo no padrao 0
        for (i = 0; i < 16384; i = i + 1) begin tpat_mem[i] = 8'd0; spat_mem[i] = 8'd0; end
        palette_mem[1] = C_BG;  palette_mem[2] = C_RAS;  palette_mem[3] = C_SPR;
        for (i = 0; i < 64;  i = i + 1) tpat_mem[i] = 8'd1;        // padrao 0 do fundo: indice 1
        for (i = 0; i < 256; i = i + 1) spat_mem[i] = 8'd3;        // padrao 0 do sprite: indice 3
        for (i = 0; i < 76800; i = i + 1) begin fb_comp[i] = 9'h1FF; fb_raw[i] = 9'h1FF; end

        repeat (4) @(negedge clk);
        reset = 0;
        @(negedge clk);
        while (init_busy) @(negedge clk);
        repeat (4) @(negedge clk);

        // sprite 0 em (120,120), padrao 0, prioridade 1, habilitado
        @(negedge clk);
        spr_id = 0; spos_d = {8'd120, 9'd120}; sattr_d = {1'b1, 5'd1, 1'b0, 1'b0, 1'b0, 6'd0};
        spos_we = 1; sattr_we = 1;
        @(negedge clk);
        spos_we = 0; sattr_we = 0;

        // ---------------- Ordem A: BG, RECT, SPR ----------------
        draw(BG); draw(RAS); draw(SPR);
        for (i = 0; i < 76800; i = i + 1) ref_img[i] = fb_comp[i];
        conferir("ordem A (BG, RECT, SPR)", 0);

        // ---------------- Ordem B: SPR, RECT, BG ----------------
        novo_quadro;
        draw(SPR); draw(RAS); draw(BG);
        conferir("ordem B (SPR, RECT, BG)", 1);
        diff_raw = 0;
        for (i = 0; i < 76800; i = i + 1) if (fb_raw[i] !== ref_img[i]) diff_raw = diff_raw + 1;
        $display("      sem a camada, a ordem B daria %0d pixels errados (fundo cobrindo sprite/retangulo)", diff_raw);
        if (diff_raw == 0) begin errors = errors + 1; $display("ERRO  o teste nao detecta a inversao de ordem"); end

        // ---------------- Ordem C: RECT, SPR, BG ----------------
        novo_quadro;
        draw(RAS); draw(SPR); draw(BG);
        conferir("ordem C (RECT, SPR, BG)", 1);

        // ---------------- Ordem D: SPR, BG, RECT, RECT, BG ----------------
        novo_quadro;
        draw(SPR); draw(BG); draw(RAS); draw(RAS); draw(BG);
        conferir("ordem D (SPR, BG, RECT, RECT, BG)", 1);

        $display("");
        $display("pixels descartados por prioridade (total): %0d", n_blocked);
        if (errors == 0) $display("tb_composicao_ordem_desenho: TODOS OS TESTES PASSARAM");
        else             $display("tb_composicao_ordem_desenho: %0d ERRO(S)", errors);
        $finish;
    end

endmodule
