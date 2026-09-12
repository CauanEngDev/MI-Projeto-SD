module motor_background (
    input  wire       clock,
    input  wire [8:0] logical_x,
    input  wire [7:0] logical_y,
    output reg  [8:0] color_out
);

    localparam TILE_SIZE     = 8;
    localparam TILES_PER_ROW = 40;
    localparam TOTAL_TILES   = 1200;

    reg [8:0] tile_rom [0:TOTAL_TILES-1];

    integer i;

    initial begin
        for (i = 0; i < TOTAL_TILES; i = i + 1) begin

            if (((i / TILES_PER_ROW) +
                 (i % TILES_PER_ROW)) % 2 == 0)
                // Vermelho: RRRGGGBBB
                tile_rom[i] = 9'b111_000_000;

            else
                // Azul: RRRGGGBBB
                tile_rom[i] = 9'b000_000_111;

        end
    end


    wire [5:0] tile_col;
    wire [4:0] tile_row;
    wire [10:0] tile_addr;

    assign tile_col  = logical_x[8:3];
    assign tile_row  = logical_y[7:3];

    assign tile_addr =
        tile_row * TILES_PER_ROW + tile_col;


    always @(posedge clock) begin
        color_out <= tile_rom[tile_addr];
    end

endmodule