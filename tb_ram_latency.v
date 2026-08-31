`timescale 1ns / 1ps

module tb_ram_latency;

    reg         clk;
    reg         wren;
    reg  [13:0] wraddr, rdaddr;
    reg  [7:0]  wdata;
    wire [7:0]  qout;

    // Usa a sprite_pattern_ram real, gerada pelo IP Catalog -- é a própria
    // altsyncram que queremos caracterizar, não um modelo hipotético
    sprite_pattern_ram dut (
        .clock     (clk),
        .data      (wdata),
        .wraddress (wraddr),
        .wren      (wren),
        .rdaddress (rdaddr),
        .q         (qout)
    );

    always #10 clk = ~clk; // 50 MHz

    integer cycle_count;
    localparam [7:0] KNOWN_VALUE = 8'hAB;
    localparam [13:0] WRITE_ADDR = 14'd100;
    localparam [13:0] EMPTY_ADDR = 14'd200; // memória inicializada em 0

    initial begin
        clk = 1'b0;
        wren = 1'b0;
        wraddr = 14'd0;
        rdaddr = 14'd0;
        wdata  = 8'd0;

        @(posedge clk);

        // Passo 1: escreve um valor conhecido num endereço
        wraddr = WRITE_ADDR;
        wdata  = KNOWN_VALUE;
        wren   = 1'b1;
        @(posedge clk);
        wren = 1'b0;

        // Passo 2: aponta a leitura para um endereço vazio (deve ler 0),
        // só pra confirmar que 'q' não está "vazando" o valor recém-escrito
        // por coincidência de timing
        rdaddr = EMPTY_ADDR;
        @(posedge clk);
        $display("Sanity check -- endereco vazio (%0d): q = %h (esperado 00)", EMPTY_ADDR, qout);

        // Passo 3: troca o endereço de leitura para o que foi escrito.
        // ESTE instante marca o ciclo 0 da contagem de latência.
        rdaddr = WRITE_ADDR;
        cycle_count = 0;

        while (qout !== KNOWN_VALUE) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            $display("ciclo %0d apos troca de endereco: q = %h", cycle_count, qout);
            if (cycle_count > 8) begin
                $display("ERRO: q nao refletiu o valor escrito apos 8 ciclos -- algo esta errado");
                $stop;
            end
        end

        $display("========================================");
        $display("LATENCIA MEDIDA: %0d ciclo(s) de clock", cycle_count);
        $display("1 ciclo = so a saida e registrada");
        $display("2 ciclos = endereco de leitura TAMBEM e registrado, alem da saida");
        $display("========================================");

        $stop;
    end

endmodule