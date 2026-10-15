`timescale 1ns/1ps
module tb_top;
    reg CLOCK_50 = 0;
    reg [3:0] KEY = 4'b1110;      // KEY[0] = 0: reset
    wire [9:0] LEDR;
    wire [7:0] R, G, B; wire HS, VS, VCLK, BL, SY;
    always #10 CLOCK_50 = ~CLOCK_50;

    coprocessador_top dut (.CLOCK_50(CLOCK_50), .KEY(KEY), .LEDR(LEDR),
        .VGA_R(R), .VGA_G(G), .VGA_B(B), .VGA_HS(HS), .VGA_VS(VS), .VGA_CLK(VCLK),
        .VGA_BLANK_N(BL), .VGA_SYNC_N(SY));

    localparam [8:0] C_BG = 9'b000_111_000, C_RAS = 9'b111_000_000, C_SPR = 9'b000_000_111;
    function [8:0] esperado; input integer x, y; begin
        if (x >= 120 && x < 136 && y >= 120 && y < 136)         esperado = C_SPR;
        else if (x >= 100 && x <= 139 && y >= 100 && y <= 139)  esperado = C_RAS;
        else                                                    esperado = C_BG;
    end endfunction

    integer k, x, y, bad, nswap = 0, t_init_end = -1, cyc = 0;
    reg [8:0] pix;
    reg prog_started = 0;
    always @(posedge CLOCK_50) begin
        cyc <= cyc + 1;
        if (dut.frame_swap) nswap <= nswap + 1;
        if (t_init_end < 0 && !dut.comp_init_busy && dut.u_composicao.init_r === 1'b0 && cyc > 10) t_init_end <= cyc;
    end

    initial begin
        repeat (20) @(posedge CLOCK_50);
        KEY[0] = 1;
        for (k = 1; k <= 3; k = k + 1) begin
            while (nswap < k && cyc < 9_000_000) @(posedge CLOCK_50);
            repeat (50) @(posedge CLOCK_50);
            if (nswap < k) begin $display("TIMEOUT no frame %0d", k); $finish; end
            bad = 0;
            for (y = 0; y < 240; y = y + 1)
                for (x = 0; x < 320; x = x + 1) begin
                    pix = dut.rd_buf_sel ? dut.u_framebuffer.framebuffer_ram_bank1.mem[y*320+x]
                                         : dut.u_framebuffer.framebuffer_ram_bank0.mem[y*320+x];
                    if (pix !== esperado(x, y)) bad = bad + 1;
                end
            $display("frame %0d (banco exibido = %0d, ciclo %0d): %0d pixels errados | LEDR=%b | varredura em curso=%b",
                     k, dut.rd_buf_sel, cyc, bad, LEDR, dut.u_composicao.sweep_busy);
        end
        $finish;
    end
endmodule
