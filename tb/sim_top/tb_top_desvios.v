`timescale 1ns/1ps

// ============================================================================
// Simulacao do coprocessador_top completo para testar desvios.
//   +HEX=<arquivo>     programa (uma palavra hexadecimal por linha)
//   +FRAMES=<n>        quantos frames observar (padrao 1)
//
// Imprime, para o runner testes_desvios.py conferir:
//   HALT  <n> R1=.. R2=.. ... R15=.. FLAGS=.. ERR=..   (registradores ao fim de cada execucao)
//   FRAME <n> red_xmin=.. red=.. blue=.. bg=..          (quadro exibido apos cada troca de bancos)
// Cores esperadas: fundo 9'b000_111_000, vermelho 9'b111_000_000, azul 9'b000_000_111.
// ============================================================================
module tb_top_desvios;
    reg CLOCK_50 = 0;
    reg [3:0] KEY = 4'b1110;      // KEY[0] = 0: reset
    wire [9:0] LEDR;
    wire [7:0] R, G, B; wire HS, VS, VCLK, BL, SY;
    always #10 CLOCK_50 = ~CLOCK_50;

    coprocessador_top dut (.CLOCK_50(CLOCK_50), .KEY(KEY), .LEDR(LEDR),
        .VGA_R(R), .VGA_G(G), .VGA_B(B), .VGA_HS(HS), .VGA_VS(VS), .VGA_CLK(VCLK),
        .VGA_BLANK_N(BL), .VGA_SYNC_N(SY));

    localparam [8:0] C_BG = 9'b000_111_000, C_RED = 9'b111_000_000, C_BLUE = 9'b000_000_111;

    integer frames_alvo = 1, nswap = 0, nhalt = 0, cyc = 0;
    reg prog_done_d = 0;

    always @(posedge CLOCK_50) begin
        cyc <= cyc + 1;
        prog_done_d <= dut.u_busca.prog_done;
        if (dut.frame_swap) nswap <= nswap + 1;
        if (dut.u_busca.prog_done && !prog_done_d) begin
            nhalt = nhalt + 1;
            $display("HALT %0d R1=%0d R2=%0d R3=%0d R4=%0d R5=%0d R10=%0d R11=%0d R12=%0d R13=%0d R14=%0d R15=%0d R16=%0d FLAGS=%0d ERR=%b",
                     nhalt,
                     $signed(dut.u_banco.registradores[1]), $signed(dut.u_banco.registradores[2]),
                     dut.u_banco.registradores[3], dut.u_banco.registradores[4], dut.u_banco.registradores[5],
                     dut.u_banco.registradores[10], dut.u_banco.registradores[11], dut.u_banco.registradores[12],
                     dut.u_banco.registradores[13], dut.u_banco.registradores[14], dut.u_banco.registradores[15], dut.u_banco.registradores[16],
                     dut.flags_q, LEDR[2]);
        end
    end

    integer k, x, y, n_red, n_blue, n_bg, xmin;
    reg [8:0] pix;
    initial begin
        if (!$value$plusargs("FRAMES=%d", frames_alvo)) frames_alvo = 1;
        repeat (20) @(posedge CLOCK_50);
        KEY[0] = 1;
        for (k = 1; k <= frames_alvo; k = k + 1) begin
            while (nswap < k && cyc < 40_000_000) @(posedge CLOCK_50);
            repeat (50) @(posedge CLOCK_50);
            if (nswap < k) begin $display("TIMEOUT no frame %0d", k); $finish; end
            n_red = 0; n_blue = 0; n_bg = 0; xmin = -1;
            for (y = 0; y < 240; y = y + 1)
                for (x = 0; x < 320; x = x + 1) begin
                    pix = dut.rd_buf_sel ? dut.u_framebuffer.framebuffer_ram_bank1.mem[y*320+x]
                                         : dut.u_framebuffer.framebuffer_ram_bank0.mem[y*320+x];
                    if (pix == C_RED)  begin n_red  = n_red  + 1; if (xmin < 0) xmin = x; end
                    if (pix == C_BLUE) n_blue = n_blue + 1;
                    if (pix == C_BG)   n_bg   = n_bg   + 1;
                end
            $display("FRAME %0d red_xmin=%0d red=%0d blue=%0d bg=%0d", k, xmin, n_red, n_blue, n_bg);
        end
        $finish;
    end
endmodule
