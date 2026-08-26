`timescale 1ns/1ps

module tb_tile_memory;

    reg clock;

    reg [8:0] logical_x;
    reg [7:0] logical_y;

    wire [8:0] color_out;

    tile_memory uut (
        .clock(clock),
        .logical_x(logical_x),
        .logical_y(logical_y),
        .color_out(color_out)
    );

    // Clock de simulação
    initial begin
        clock = 0;
        forever #10 clock = ~clock;
    end

   initial begin

    logical_x = 0;
    logical_y = 0;

    #20;

    if (color_out == 9'b111_000_00)
        $display("TESTE 1 PASSOU: tile (0,0) vermelho");
    else
        $display("TESTE 1 FALHOU");

    logical_x = 8;
    logical_y = 0;

    #20;

    if (color_out == 9'b000_000_11)
        $display("TESTE 2 PASSOU: tile (1,0) azul");
    else
        $display("TESTE 2 FALHOU");

    logical_x = 8;
    logical_y = 8;

    #20;

    if (color_out == 9'b111_000_00)
        $display("TESTE 3 PASSOU: tile (1,1) vermelho");
    else
        $display("TESTE 3 FALHOU");

    $stop;

end

endmodule