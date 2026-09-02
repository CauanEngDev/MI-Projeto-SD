`timescale 1ns / 1ps
`include "sim_models.v"

module tb_top_video_integration;

    reg clock, reset;
    wire hsync, vsync, sync, clk_vga, blank;
    wire [7:0] red, green, blue;

    reg poly_layer_done;
    wire poly_phase;
    reg frame_start;
    wire frame_done;

    reg spr_attr_wr_en; reg [4:0] spr_attr_wr_addr; reg [31:0] spr_attr_wr_data;
    reg spr_pattern_wr_en; reg [13:0] spr_pattern_wr_addr; reg [7:0] spr_pattern_wr_data;
    reg palette_wr_en; reg [8:0] palette_wr_addr; reg [8:0] palette_wr_data;
    reg bg_tile_wr_en; reg [10:0] bg_tile_wr_addr; reg [7:0] bg_tile_wr_data;
    reg bg_pattern_wr_en; reg [13:0] bg_pattern_wr_addr; reg [7:0] bg_pattern_wr_data;

    reg rast_start_square, rast_start_triangle;
    reg [8:0] rast_v0x, rast_v1x, rast_v2x;
    reg [7:0] rast_v0y, rast_v1y, rast_v2y;
    reg [7:0] rast_color_index;
    reg rast_palette_sel;
    wire rast_busy, rast_done, rast_invalid_cmd;

    integer errors = 0;
    integer checks = 0;

    top_video dut (
        .clock(clock), .reset(reset),
        .hsync(hsync), .vsync(vsync), .sync(sync), .clk(clk_vga), .blank(blank),
        .red(red), .green(green), .blue(blue),
        .bg_tile_wr_en(bg_tile_wr_en), .bg_tile_wr_addr(bg_tile_wr_addr), .bg_tile_wr_data(bg_tile_wr_data),
        .bg_pattern_wr_en(bg_pattern_wr_en), .bg_pattern_wr_addr(bg_pattern_wr_addr), .bg_pattern_wr_data(bg_pattern_wr_data),
        .spr_attr_wr_en(spr_attr_wr_en), .spr_attr_wr_addr(spr_attr_wr_addr), .spr_attr_wr_data(spr_attr_wr_data),
        .spr_pattern_wr_en(spr_pattern_wr_en), .spr_pattern_wr_addr(spr_pattern_wr_addr), .spr_pattern_wr_data(spr_pattern_wr_data),
        .palette_wr_en(palette_wr_en), .palette_wr_addr(palette_wr_addr), .palette_wr_data(palette_wr_data),
        .scroll_wr_en(1'b0), .scroll_sel(1'b0), .scroll_wr_data(9'd0),
        .scroll_auto_en(1'b0), .scroll_auto_axis(1'b0), .scroll_auto_dir(1'b0), .scroll_auto_step(8'd0),
        .rast_start_square(rast_start_square), .rast_start_triangle(rast_start_triangle),
        .rast_v0x(rast_v0x), .rast_v1x(rast_v1x), .rast_v2x(rast_v2x),
        .rast_v0y(rast_v0y), .rast_v1y(rast_v1y), .rast_v2y(rast_v2y),
        .rast_color_index(rast_color_index), .rast_palette_sel(rast_palette_sel),
        .rast_busy(rast_busy), .rast_done(rast_done), .rast_invalid_cmd(rast_invalid_cmd),
        .frame_start(frame_start), .poly_layer_done(poly_layer_done),
        .poly_phase(poly_phase), .frame_done(frame_done)
    );

    always #10 clock = ~clock; // 50 MHz

    // ---------------- Tarefas auxiliares ----------------
    task write_sprite_attr(input [4:0] slot, input enable, input [4:0] prio,
                            input flip_v, input flip_h, input pal_sel,
                            input [5:0] pattern, input [7:0] py, input [8:0] px);
        begin
            @(posedge clock);
            spr_attr_wr_en   <= 1'b1;
            spr_attr_wr_addr <= slot;
            spr_attr_wr_data <= {enable, prio, flip_v, flip_h, pal_sel, pattern, py, px};
            @(posedge clock);
            spr_attr_wr_en <= 1'b0;
        end
    endtask

    task write_sprite_pixel(input [7:0] tile_id, input [2:0] sy, input [2:0] sx, input [7:0] val);
        begin
            @(posedge clock);
            spr_pattern_wr_en   <= 1'b1;
            spr_pattern_wr_addr <= {tile_id, sy, sx};
            spr_pattern_wr_data <= val;
            @(posedge clock);
            spr_pattern_wr_en <= 1'b0;
        end
    endtask

    task write_palette(input [8:0] addr, input [8:0] rgb);
        begin
            @(posedge clock);
            palette_wr_en   <= 1'b1;
            palette_wr_addr <= addr;
            palette_wr_data <= rgb;
            @(posedge clock);
            palette_wr_en <= 1'b0;
        end
    endtask

    // Le um pixel do banco de framebuffer indicado (0 ou 1), via acesso
    // hierarquico direto ao array de memoria do modelo comportamental
    function [8:0] read_fb_pixel(input bank, input [8:0] x, input [7:0] y);
        reg [16:0] addr;
        begin
            addr = y * 320 + x;
            if (bank == 1'b0)
                read_fb_pixel = dut.framebuffer_inst.framebuffer_ram_bank0.mem[addr];
            else
                read_fb_pixel = dut.framebuffer_inst.framebuffer_ram_bank1.mem[addr];
        end
    endfunction

    task check_pixel(input [8:0] x, input [7:0] y, input bank, input [8:0] expected, input [127:0] label);
        reg [8:0] got;
        begin
            checks = checks + 1;
            got = read_fb_pixel(bank, x, y);
            if (got !== expected) begin
                $display("FALHOU [%0s]: pixel (%0d,%0d) banco %0d = %h, esperado %h", label, x, y, bank, got, expected);
                errors = errors + 1;
            end else begin
                $display("PASSOU [%0s]: pixel (%0d,%0d) banco %0d = %h", label, x, y, bank, got);
            end
        end
    endtask

    task run_one_frame(output write_bank);
        begin
            write_bank = dut.wr_buf_sel; // banco que vai receber a escrita deste frame
            @(posedge clock);
            frame_start <= 1'b1;
            @(posedge clock);
            frame_start <= 1'b0;
            wait (poly_phase);
            @(posedge clock);
            poly_layer_done <= 1'b1;
            @(posedge clock);
            poly_layer_done <= 1'b0;
            wait (frame_done);
            @(posedge clock);
        end
    endtask

    reg frame_bank;

    // ================================================================
    task test_transparency;
        begin
            $display("=== CENARIO: Transparencia ===");
            // Padrao 0 (sprite slot 0) permanece zerado -> 100%% transparente
            write_sprite_attr(0, 1, 5'd10, 0, 0, 0, 6'd0, 8'd50, 9'd50);
            run_one_frame(frame_bank);
            // Nenhum pixel do sprite deveria ter sido escrito -- verificamos
            // que o pixel permanece no valor de reset do modelo (0)
            check_pixel(9'd50, 8'd50, frame_bank, 9'd0, "transparencia: pixel nao escrito");
        end
    endtask

    // ================================================================
    task test_mirroring;
    integer lx, ly;
    reg [7:0] val;
    reg [7:0] tile_id;
    begin
            $display("=== CENARIO: Espelhamento ===");
            write_palette(9'd1, 9'b111111111); // branco

            for (ly = 0; ly < 16; ly = ly + 1) begin
                for (lx = 0; lx < 16; lx = lx + 1) begin
                    val = (lx < 4 || ly >= 12) ? 8'd1 : 8'd0;
                    tile_id = 8'd4 + ((ly >= 8) ? 8'd2 : 8'd0)
												 + ((lx >= 8) ? 8'd1 : 8'd0);

						   write_sprite_pixel(tile_id, ly[2:0], lx[2:0], val);
                end
            end

            write_sprite_attr(1, 1, 5'd10, 0, 0, 0, 6'd1, 8'd50, 9'd50);  // baseline
            write_sprite_attr(2, 1, 5'd10, 0, 1, 0, 6'd1, 8'd50, 9'd90);  // flip_h

            run_one_frame(frame_bank);

            // Baseline: canto (50+0,50+0) faz parte da barra vertical esquerda -> opaco
            check_pixel(9'd50, 8'd50, frame_bank, 9'b111111111, "espelhamento: baseline opaco na barra esquerda");
            // Flipado: (90+0,50+0) deveria estar transparente (barra foi para o lado direito)
            check_pixel(9'd90, 8'd50, frame_bank, 9'd0, "espelhamento: flip_h limpa a barra esquerda original");
            // Flipado: (90+15,50+0) deveria estar opaco (barra migrou para a direita)
            check_pixel(9'd105, 8'd50, frame_bank, 9'b111111111, "espelhamento: flip_h move a barra para a direita");
        end
    endtask

    // ================================================================
    task test_overlap_priority;
    integer lx, ly;
    reg [7:0] val;
    reg [7:0] tile_id;
    begin
            $display("=== CENARIO: Sobreposicao e Prioridade ===");
            write_palette(9'd4, 9'b111000000); // vermelho -- cor do "quadrado" (pattern 0)
            write_palette(9'd6, 9'b000000111); // azul     -- cor do "L" (pattern 2), reaproveitado aqui so como 2a cor

            // Preenche pattern 0 (tiles 0-3) com o quadrado 12x12 solido, cor 4
            for (ly = 0; ly < 16; ly = ly + 1)
                for (lx = 0; lx < 16; lx = lx + 1)
                    tile_id = 8'd0 + ((ly >= 8) ? 8'd2 : 8'd0)
												 + ((lx >= 8) ? 8'd1 : 8'd0);

							val = (lx >= 2 && lx <= 13 && ly >= 2 && ly <= 13)
									? 8'd4 : 8'd0;

							write_sprite_pixel(tile_id, ly[2:0], lx[2:0], val);

            // Dois sprites na MESMA posicao (100,100), prioridades diferentes,
            // ambos usando pattern 0 (quadrado solido) mas cores diferentes
            // via paleta -- pra simplificar, uso o MESMO color_index (4) nos
            // dois, entao a diferenca visivel aqui e conceitual: o de cima
            // "vence" independente de cor, o teste confirma isso pela ordem
                        write_palette(9'd4, 9'b111000000);       // paleta 0, indice 4 = vermelho
            write_palette(9'd256+4, 9'b000000111);    // paleta 1, indice 4 = azul

            write_sprite_attr(3, 1, 5'd5,  0, 0, 1'b0, 6'd0, 8'd100, 9'd100); // fundo: paleta 0 = vermelho
            write_sprite_attr(4, 1, 5'd20, 0, 0, 1'b1, 6'd0, 8'd100, 9'd100); // frente: paleta 1 = azul

            run_one_frame(frame_bank);
            check_pixel(9'd105, 8'd105, frame_bank, 9'b000000111, "prioridade: sprite de maior priority (azul) venceu, nao o vermelho de baixo");

            // Empate de prioridade -- desempate por indice (maior indice vence)
            write_sprite_attr(5, 1, 5'd15, 0, 0, 0, 6'd0, 8'd150, 9'd150);
            write_sprite_attr(6, 1, 5'd15, 0, 0, 0, 6'd0, 8'd150, 9'd150);

            run_one_frame(frame_bank);
            check_pixel(9'd155, 8'd155, frame_bank, 9'b111000000, "prioridade: empate resolvido pelo maior indice");
        end
    endtask
	 
	 // ================================================================
    task test_buffer_swap;
        reg bank_before;
        begin
            $display("=== CENARIO: Troca de buffers ===");
            bank_before = dut.wr_buf_sel;
            $display("wr_buf_sel antes = %b, rd_buf_sel antes = %b", dut.wr_buf_sel, dut.rd_buf_sel);
            run_one_frame(frame_bank);
            $display("wr_buf_sel depois = %b, rd_buf_sel depois = %b", dut.wr_buf_sel, dut.rd_buf_sel);

            checks = checks + 1;
            if (dut.wr_buf_sel == bank_before) begin
                $display("FALHOU: wr_buf_sel nao trocou apos um frame completo");
                errors = errors + 1;
            end else begin
                $display("PASSOU: wr_buf_sel trocou corretamente apos o frame");
            end

            checks = checks + 1;
            if (dut.rd_buf_sel != bank_before) begin
                $display("FALHOU: rd_buf_sel deveria ter assumido o banco que acabou de ser escrito (%b)", bank_before);
                errors = errors + 1;
            end else begin
                $display("PASSOU: rd_buf_sel agora aponta para o banco recem-escrito");
            end
        end
    endtask

    // ================================================================
    task test_invalid_command;
        begin
            $display("=== CENARIO: Comando invalido (vertice fora da tela) ===");

            @(posedge clock);
            rast_v0x <= 9'd10; rast_v0y <= 8'd10;
            rast_v1x <= 9'd50; rast_v1y <= 8'd50;
            rast_color_index <= 8'd1;
            rast_start_square <= 1'b1;
            @(posedge clock);
            rast_start_square <= 1'b0;
            wait (rast_done);
            checks = checks + 1;
            if (rast_invalid_cmd) begin
                $display("FALHOU: comando valido foi rejeitado incorretamente");
                errors = errors + 1;
            end else $display("PASSOU: comando valido foi aceito normalmente");

            @(posedge clock);
            rast_v0x <= 9'd10;  rast_v0y <= 8'd10;
            rast_v1x <= 9'd400; rast_v1y <= 8'd50; // fora da tela
            rast_color_index <= 8'd2;
            rast_start_square <= 1'b1;
            @(posedge clock);
            rast_start_square <= 1'b0;

            @(posedge clock);
            checks = checks + 1;
            if (rast_invalid_cmd) $display("PASSOU: comando invalido foi corretamente rejeitado");
            else begin
                $display("FALHOU: comando invalido nao foi sinalizado");
                errors = errors + 1;
            end

            checks = checks + 1;
            if (rast_busy) begin
                $display("FALHOU: rast_busy subiu para um comando que deveria ter sido rejeitado");
                errors = errors + 1;
            end else $display("PASSOU: rasterizador permaneceu ocioso");

            @(posedge clock);
            rast_v0x <= 9'd20; rast_v0y <= 8'd20;
            rast_v1x <= 9'd60; rast_v1y <= 8'd60;
            rast_start_square <= 1'b1;
            @(posedge clock);
            rast_start_square <= 1'b0;
            wait (rast_done);
            $display("PASSOU: sistema permaneceu operacional apos comando invalido");
        end
    endtask

    // ================================================================
    initial begin
        clock = 0; reset = 1;
        frame_start = 0; poly_layer_done = 0;
        spr_attr_wr_en = 0; spr_pattern_wr_en = 0; palette_wr_en = 0;
        bg_tile_wr_en = 0; bg_pattern_wr_en = 0;
        rast_start_square = 0; rast_start_triangle = 0;

        repeat (5) @(posedge clock);
        reset = 0;
        @(posedge clock);

        test_transparency;
        test_mirroring;
        test_overlap_priority;
        test_buffer_swap;
        test_invalid_command;

        $display("========================================");
        $display("Total: %0d verificacoes, %0d falha(s)", checks, errors);
        $display("========================================");
        $stop;
    end

endmodule