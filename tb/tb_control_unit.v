`timescale 1ns/1ps

// Testbench para os modulos unidade_de_controle e engine_mux.
// Compilar junto com rtl/core/control_unit/unidade_de_controle.v.
module tb_control_unit;

    reg  [31:0] instruction;
    reg         execute;
    reg  [31:0] reg_a, reg_b;
    reg         alu_done;
    reg         done_bg, done_sprite, done_raster, raster_invalid;

    wire        alu_valid;
    wire [2:0]  alu_op;
    wire [31:0] alu_b;
    wire [4:0]  alu_shamt;
    wire        rf_write_enable, flags_we;
    wire        pal_we;
    wire [8:0]  pal_wr_addr, pal_wr_data;
    wire        tile_we;
    wire [10:0] tile_wr_addr;
    wire [7:0]  tile_wr_data;
    wire        tpat_we;
    wire [13:0] tpat_wr_addr;
    wire [7:0]  tpat_wr_data;
    wire        spat_we;
    wire [13:0] spat_wr_addr;
    wire [7:0]  spat_wr_data;
    wire        spos_we;
    wire [4:0]  spos_wr_addr;
    wire [16:0] spos_wr_data;
    wire        sattr_we;
    wire [4:0]  sattr_wr_addr;
    wire [14:0] sattr_wr_data;
    wire        scroll_wr_en, scroll_sel;
    wire [8:0]  scroll_wr_data;
    wire        scroll_auto_en, scroll_auto_axis, scroll_auto_dir;
    wire [7:0]  scroll_auto_step;
    wire        start_bg, start_sprite, start_square, start_triangle;
    wire [1:0]  engine_sel;
    wire        engine_done, cmd_error;

    integer tests_passed = 0;
    integer tests_failed = 0;

    unidade_de_controle dut (
        .instruction(instruction), .execute(execute),
        .reg_a(reg_a), .reg_b(reg_b),
        .alu_valid(alu_valid), .alu_op(alu_op), .alu_b(alu_b),
        .alu_shamt(alu_shamt), .alu_done(alu_done),
        .rf_write_enable(rf_write_enable), .flags_we(flags_we),
        .pal_we(pal_we), .pal_wr_addr(pal_wr_addr), .pal_wr_data(pal_wr_data),
        .tile_we(tile_we), .tile_wr_addr(tile_wr_addr), .tile_wr_data(tile_wr_data),
        .tpat_we(tpat_we), .tpat_wr_addr(tpat_wr_addr), .tpat_wr_data(tpat_wr_data),
        .spat_we(spat_we), .spat_wr_addr(spat_wr_addr), .spat_wr_data(spat_wr_data),
        .spos_we(spos_we), .spos_wr_addr(spos_wr_addr), .spos_wr_data(spos_wr_data),
        .sattr_we(sattr_we), .sattr_wr_addr(sattr_wr_addr), .sattr_wr_data(sattr_wr_data),
        .scroll_wr_en(scroll_wr_en), .scroll_sel(scroll_sel),
        .scroll_wr_data(scroll_wr_data), .scroll_auto_en(scroll_auto_en),
        .scroll_auto_axis(scroll_auto_axis), .scroll_auto_dir(scroll_auto_dir),
        .scroll_auto_step(scroll_auto_step),
        .start_bg(start_bg), .start_sprite(start_sprite),
        .start_square(start_square), .start_triangle(start_triangle),
        .done_bg(done_bg), .done_sprite(done_sprite), .done_raster(done_raster),
        .raster_invalid(raster_invalid), .engine_sel(engine_sel),
        .engine_done(engine_done), .cmd_error(cmd_error)
    );

    // Sinais de teste independentes para o mux.
    reg [1:0] mux_engine_sel;
    reg [8:0] bg_pal_addr, spr_pal_addr, ras_pal_addr;
    reg bg_fb_we, spr_fb_we, ras_fb_we;
    reg [8:0] bg_fb_x, spr_fb_x, ras_fb_x;
    reg [7:0] bg_fb_y, spr_fb_y, ras_fb_y;
    reg [8:0] bg_fb_data, spr_fb_data, ras_fb_data;
    wire [8:0] mux_pal_rd_addr, mux_fb_wr_x, mux_fb_wr_data;
    wire [7:0] mux_fb_wr_y;
    wire mux_fb_we;

    engine_mux mux_dut (
        .engine_sel(mux_engine_sel),
        .bg_pal_addr(bg_pal_addr), .bg_fb_we(bg_fb_we), .bg_fb_x(bg_fb_x),
        .bg_fb_y(bg_fb_y), .bg_fb_data(bg_fb_data),
        .spr_pal_addr(spr_pal_addr), .spr_fb_we(spr_fb_we), .spr_fb_x(spr_fb_x),
        .spr_fb_y(spr_fb_y), .spr_fb_data(spr_fb_data),
        .ras_pal_addr(ras_pal_addr), .ras_fb_we(ras_fb_we), .ras_fb_x(ras_fb_x),
        .ras_fb_y(ras_fb_y), .ras_fb_data(ras_fb_data),
        .pal_rd_addr(mux_pal_rd_addr), .fb_we(mux_fb_we),
        .fb_wr_x(mux_fb_wr_x), .fb_wr_y(mux_fb_wr_y), .fb_wr_data(mux_fb_wr_data)
    );

    task check;
        input condition;
        input [8*120-1:0] message;
        begin
            if (condition) begin
                tests_passed = tests_passed + 1;
                $display("[PASS] %0s", message);
            end else begin
                tests_failed = tests_failed + 1;
                $display("[FAIL] %0s", message);
            end
        end
    endtask

    task set_instruction;
        input [4:0] opcode;
        input       immediate;
        input [11:0] imm;
        begin
            instruction = {opcode, immediate, 14'b0, imm};
            #1;
        end
    endtask

    initial begin
        $display("====================================================");
        $display(" Testbench: unidade_de_controle e engine_mux");
        $display("====================================================");

        instruction = 0; execute = 0; reg_a = 0; reg_b = 0; alu_done = 0;
        done_bg = 0; done_sprite = 0; done_raster = 0; raster_invalid = 0;
        mux_engine_sel = 0;
        bg_pal_addr = 9'h011; bg_fb_we = 1; bg_fb_x = 9'h012; bg_fb_y = 8'h13; bg_fb_data = 9'h101;
        spr_pal_addr = 9'h022; spr_fb_we = 1; spr_fb_x = 9'h023; spr_fb_y = 8'h24; spr_fb_data = 9'h202;
        ras_pal_addr = 9'h033; ras_fb_we = 1; ras_fb_x = 9'h034; ras_fb_y = 8'h35; ras_fb_data = 9'h303;
        #2;

        // Estado inativo e configuracao fixa do auto-scroll.
        check(!alu_valid && !pal_we && !tile_we && !tpat_we && !spat_we,
              "execute=0 nao dispara ULA nem escritas de memoria");
        check(!spos_we && !sattr_we && !scroll_wr_en && !start_bg && !start_sprite && !start_square && !start_triangle,
              "execute=0 nao altera sprites, scroll ou motores");
        check(!scroll_auto_en && !scroll_auto_axis && !scroll_auto_dir && scroll_auto_step == 0,
              "auto-scroll permanece desabilitado");

        // ULA: opcode 1..6; teste detalhado de ADD imediato e SUB por registrador.
        set_instruction(5'b00001, 1'b1, 12'hABC);
        execute = 1; reg_b = 32'h12345678; #1;
        check(alu_valid && alu_op == 3'b001 && alu_b == 32'h00000ABC && alu_shamt == 5'h1C,
              "ADD imediato gera valid, operacao e operando corretos");
        execute = 0; #1; check(!alu_valid, "alu_valid e condicionado a execute");
        set_instruction(5'b00010, 1'b0, 12'h000); execute = 1; reg_b = 32'h89ABCDEF; #1;
        check(alu_valid && alu_op == 3'b010 && alu_b == 32'h89ABCDEF && alu_shamt == 5'h0F,
              "SUB por registrador usa reg_b");
        execute = 0; alu_done = 1; #1;
        check(rf_write_enable && flags_we,
              "alu_done habilita write-back e captura de flags conforme a implementacao");
        alu_done = 0;

        // SET_PALETTE: opcode 00111, endereco e cor vindos dos registradores.
        set_instruction(5'b00111, 0, 0); reg_a = 32'h000001A5; reg_b = 32'h000001C7; execute = 1; #1;
        check(pal_we && pal_wr_addr == 9'h1A5 && pal_wr_data == 9'h0C7,
              "SET_PALETTE escreve endereco e cor de 9 bits");
        execute = 0; #1; check(!pal_we, "pal_we desliga quando execute=0");

        set_instruction(5'b01100, 0, 0); reg_a = 32'd1199; reg_b = 32'h000000A6; execute = 1; #1;
        check(tile_we && tile_wr_addr == 11'd1199 && tile_wr_data == 8'hA6,
              "SET_TILEMAP gera endereco e pattern_id corretos");
        set_instruction(5'b01111, 0, 0); reg_a = 32'h00001234; reg_b = 32'h0000005A; #1;
        check(tpat_we && tpat_wr_addr == 14'h1234 && tpat_wr_data == 8'h5A,
              "WRITE_TILE_DATA gera endereco e indice de cor corretos");
        set_instruction(5'b01110, 0, 0); reg_a = 32'h00002345; reg_b = 32'h0000006B; #1;
        check(spat_we && spat_wr_addr == 14'h2345 && spat_wr_data == 8'h6B,
              "WRITE_SPRITE_DATA gera endereco e indice de cor corretos");

        set_instruction(5'b01010, 0, 0); reg_a = 32'd17; reg_b = 32'h00012345; #1;
        check(spos_we && spos_wr_addr == 5'd17 && spos_wr_data == 17'h12345,
              "SET_SPRITE_POS escreve id e posicao de 17 bits");
        set_instruction(5'b01011, 0, 0); reg_a = 32'd7; reg_b = 32'h00004567; #1;
        check(sattr_we && sattr_wr_addr == 5'd7 && sattr_wr_data == 15'h4567,
              "SET_SPRITE_ATTR escreve id e atributos de 15 bits");

        set_instruction(5'b01101, 0, 0); reg_a = 32'h00000123; reg_b = 1; #1;
        check(scroll_wr_en && scroll_sel && scroll_wr_data == 9'h123,
              "SCROLL_BG seleciona eixo vertical e valor de scroll");
        reg_b = 0; #1; check(scroll_wr_en && !scroll_sel, "SCROLL_BG seleciona eixo horizontal");

        // Disparo e conclusao dos motores.
        set_instruction(5'b10000, 0, 0); #1;
        check(start_bg && !start_sprite && engine_sel == 2'd1,
              "DRAW_BACKGROUND dispara background e seleciona motor 1");
        done_bg = 1; #1; check(engine_done, "done_bg conclui operacao de background");
        done_bg = 0;

        set_instruction(5'b10001, 0, 0); #1;
        check(start_sprite && !start_bg && engine_sel == 2'd2,
              "DRAW_SPRITES dispara sprites e seleciona motor 2");
        done_sprite = 1; #1; check(engine_done, "done_sprite conclui operacao de sprites");
        done_sprite = 0;

        set_instruction(5'b01000, 0, 0); #1;
        check(start_square && !start_triangle && engine_sel == 2'd3,
              "DRAW_RECT dispara rasterizador para retangulo/quadrado");
        done_raster = 1; #1; check(engine_done, "done_raster conclui rasterizacao");
        done_raster = 0;

        set_instruction(5'b01001, 0, 0); raster_invalid = 1; #1;
        check(start_triangle && engine_sel == 2'd3 && engine_done && cmd_error,
              "triangulo invalido gera cmd_error e encerra a instrucao");
        raster_invalid = 0; #1; check(!cmd_error, "cmd_error acompanha raster_invalid");

        // engine_mux: cada seletor deve encaminhar os sinais do motor escolhido.
        mux_engine_sel = 2'd1; #1;
        check(mux_pal_rd_addr == bg_pal_addr && mux_fb_we == bg_fb_we &&
              mux_fb_wr_x == bg_fb_x && mux_fb_wr_y == bg_fb_y && mux_fb_wr_data == bg_fb_data,
              "engine_mux encaminha sinais do background");
        mux_engine_sel = 2'd2; #1;
        check(mux_pal_rd_addr == spr_pal_addr && mux_fb_we == spr_fb_we &&
              mux_fb_wr_x == spr_fb_x && mux_fb_wr_y == spr_fb_y && mux_fb_wr_data == spr_fb_data,
              "engine_mux encaminha sinais do sprite");
        mux_engine_sel = 2'd3; #1;
        check(mux_pal_rd_addr == ras_pal_addr && mux_fb_we == ras_fb_we &&
              mux_fb_wr_x == ras_fb_x && mux_fb_wr_y == ras_fb_y && mux_fb_wr_data == ras_fb_data,
              "engine_mux encaminha sinais do rasterizador");
        mux_engine_sel = 2'd0; #1;
        check(mux_pal_rd_addr == 0 && !mux_fb_we && mux_fb_wr_x == 0 &&
              mux_fb_wr_y == 0 && mux_fb_wr_data == 0,
              "engine_mux desabilita escrita e zera saidas sem motor ativo");

        $display("----------------------------------------------------");
        $display("Resultado: %0d passaram; %0d falharam", tests_passed, tests_failed);
        $display("----------------------------------------------------");
        if (tests_failed == 0) $display("TESTE FINALIZADO: SUCESSO");
        else $display("TESTE FINALIZADO: FALHA");
        $finish;
    end
endmodule
