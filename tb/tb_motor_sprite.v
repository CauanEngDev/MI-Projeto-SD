`timescale 1ns/1ps

module tb_motor_sprite;

    reg clk = 1'b0;
    reg reset = 1'b1;

    reg        spos_we = 1'b0;
    reg [4:0]  spos_wr_addr = 5'd0;
    reg [16:0] spos_wr_data = 17'd0;

    reg        sattr_we = 1'b0;
    reg [4:0]  sattr_wr_addr = 5'd0;
    reg [14:0] sattr_wr_data = 15'd0;

    wire [13:0] pattern_rd_addr;
    reg  [7:0]  pattern_rd_data;

    wire [8:0] palette_rd_addr;
    reg  [8:0] palette_rd_data;

    wire       fb_we;
    wire [8:0] fb_wr_x;
    wire [7:0] fb_wr_y;
    wire [8:0] fb_wr_data;

    reg start = 1'b0;
    wire busy;
    wire done;

    // Modelos combinacionais de RAM. Os parametros de espera do DUT sao
    // zerados para acelerar a simulacao com estas memorias simplificadas.
    reg [7:0] pattern_mem [0:16383];
    reg [8:0] palette_mem [0:511];

    integer errors = 0;
    integer writes = 0;
    integer i;
    integer timeout_count;
    reg [8:0] first_pixel_color;
    reg first_pixel_seen = 1'b0;

    localparam integer SPR_X = 10;
    localparam integer SPR_Y = 12;

    always #10 clk = ~clk;

    always @(*) begin
        pattern_rd_data = pattern_mem[pattern_rd_addr];
        palette_rd_data = palette_mem[palette_rd_addr];
    end

    motor_sprite #(
        .PATTERN_EXTRA_WAIT(0),
        .PALETTE_EXTRA_WAIT(0)
    ) dut (
        .clk(clk),
        .reset(reset),
        .spos_we(spos_we),
        .spos_wr_addr(spos_wr_addr),
        .spos_wr_data(spos_wr_data),
        .sattr_we(sattr_we),
        .sattr_wr_addr(sattr_wr_addr),
        .sattr_wr_data(sattr_wr_data),
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

    // Conta as escritas e guarda a cor do primeiro pixel do sprite.
    always @(posedge clk) begin
        if (reset) begin
            writes <= 0;
            first_pixel_seen <= 1'b0;
            first_pixel_color <= 9'd0;
        end
        else if (fb_we) begin
            writes <= writes + 1;
            if (fb_wr_x == SPR_X && fb_wr_y == SPR_Y) begin
                first_pixel_seen <= 1'b1;
                first_pixel_color <= fb_wr_data;
            end
        end
    end

    task clear_memories;
        integer k;
        integer local_x;
        integer local_y;
        integer tile_x;
        integer tile_y;
        integer addr;
        integer idx;
        begin
            for (k = 0; k < 16384; k = k + 1)
                pattern_mem[k] = 8'd0;

            for (k = 0; k < 512; k = k + 1)
                palette_mem[k] = 9'd0;

            // Pattern 0: cada pixel recebe um indice diferente de zero.
            // O indice depende da coordenada local para verificar os flips.
            for (local_y = 0; local_y < 16; local_y = local_y + 1) begin
                for (local_x = 0; local_x < 16; local_x = local_x + 1) begin
                    tile_x = local_x / 8;
                    tile_y = local_y / 8;
                    addr = (tile_y * 128) + (tile_x * 64)
                         + ((local_y % 8) * 8) + (local_x % 8);
                    idx = 1 + ((local_y * 16 + local_x) % 255);
                    pattern_mem[addr] = idx[7:0];
                end
            end

            // Paleta 0: cor = indice. Paleta 1: cor = 0x100 | indice.
            for (k = 0; k < 256; k = k + 1) begin
                palette_mem[k]       = k[8:0];
                palette_mem[256 + k] = 9'h100 | k[7:0];
            end
        end
    endtask

    task reset_dut;
        begin
            @(negedge clk);
            reset = 1'b1;
            start = 1'b0;
            spos_we = 1'b0;
            sattr_we = 1'b0;
            repeat (3) @(negedge clk);
            reset = 1'b0;
            @(negedge clk);
        end
    endtask

    task configure_sprite;
        input integer sprite_id;
        input integer pos_x;
        input integer pos_y;
        input integer flip_h;
        input integer flip_v;
        input integer palette_sel;
        input integer prio;
        begin
            // Posicao: {y[7:0], x[8:0]}.
            @(negedge clk);
            spos_we = 1'b1;
            spos_wr_addr = sprite_id[4:0];
            spos_wr_data = {pos_y[7:0], pos_x[8:0]};
            @(negedge clk);
            spos_we = 1'b0;

            // Atributos: {enable, prio[4:0], flip_v, flip_h,
            //             palette_sel, pattern[5:0]}.
            sattr_we = 1'b1;
            sattr_wr_addr = sprite_id[4:0];
            sattr_wr_data = {1'b1, prio[4:0], flip_v[0], flip_h[0],
                             palette_sel[0], 6'd0};
            @(negedge clk);
            sattr_we = 1'b0;
        end
    endtask

    task run_frame;
        begin
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            timeout_count = 0;
            while (!done && timeout_count < 200000) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (!done) begin
                $display("[FAIL] Timeout: motor_sprite nao concluiu a varredura.");
                errors = errors + 1;
            end
            else begin
                @(negedge clk);
                $display("[INFO] Varredura concluida em %0d ciclos.", timeout_count);
            end
        end
    endtask

    task check_result;
        input [8*64-1:0] test_name;
        input integer expected_writes;
        input [8:0] expected_first_color;
        begin
            if (writes !== expected_writes) begin
                $display("[FAIL] %0s: escritas=%0d, esperado=%0d",
                         test_name, writes, expected_writes);
                errors = errors + 1;
            end
            else begin
                $display("[PASS] %0s: quantidade de escritas = %0d",
                         test_name, writes);
            end

            if (expected_writes > 0) begin
                if (!first_pixel_seen) begin
                    $display("[FAIL] %0s: pixel inicial (%0d,%0d) nao foi escrito.",
                             test_name, SPR_X, SPR_Y);
                    errors = errors + 1;
                end
                else if (first_pixel_color !== expected_first_color) begin
                    $display("[FAIL] %0s: cor inicial=%03h, esperado=%03h",
                             test_name, first_pixel_color, expected_first_color);
                    errors = errors + 1;
                end
                else begin
                    $display("[PASS] %0s: cor do pixel inicial = %03h",
                             test_name, first_pixel_color);
                end
            end
        end
    endtask

    initial begin
        $display("==================================================");
        $display(" TESTBENCH - MOTOR SPRITE");
        $display("==================================================");

        clear_memories();
        reset_dut();

        // Teste 1: sprite opaco, sem flip, paleta 0.
        configure_sprite(0, SPR_X, SPR_Y, 0, 0, 0, 3);
        run_frame();
        check_result("Sprite opaco / paleta 0", 256, 9'h001);

        // Teste 2: flip horizontal: o pixel superior esquerdo exibido
        // corresponde ao pixel local (15,0), cujo indice e 16.
        reset_dut();
        clear_memories();
        configure_sprite(0, SPR_X, SPR_Y, 1, 0, 0, 3);
        run_frame();
        check_result("Flip horizontal", 256, 9'h010);

        // Teste 3: flip vertical: o pixel superior esquerdo exibido
        // corresponde ao pixel local (0,15), cujo indice e 241 (0xF1).
        reset_dut();
        clear_memories();
        configure_sprite(0, SPR_X, SPR_Y, 0, 1, 0, 3);
        run_frame();
        check_result("Flip vertical", 256, 9'h0F1);

        // Teste 4: selecao da paleta 1.
        reset_dut();
        clear_memories();
        configure_sprite(0, SPR_X, SPR_Y, 0, 0, 1, 3);
        run_frame();
        check_result("Selecao da paleta 1", 256, 9'h101);

        // Teste 5: transparencia total. Todos os pixels do padrao sao zero.
        reset_dut();
        clear_memories();
        for (i = 0; i < 16384; i = i + 1)
            pattern_mem[i] = 8'd0;
        configure_sprite(0, SPR_X, SPR_Y, 0, 0, 0, 3);
        run_frame();

        if (writes !== 0) begin
            $display("[FAIL] Transparencia: foram escritas %0d pixels; esperado=0", writes);
            errors = errors + 1;
        end
        else begin
            $display("[PASS] Transparencia: nenhum pixel foi escrito.");
        end

        $display("==================================================");
        if (errors == 0)
            $display("RESULTADO FINAL: TODOS OS TESTES PASSARAM");
        else
            $display("RESULTADO FINAL: %0d FALHA(S)", errors);
        $display("==================================================");
        $finish;
    end

    initial begin
        #100000000;
        $display("[FAIL] Timeout global do testbench.");
        $finish;
    end

endmodule
