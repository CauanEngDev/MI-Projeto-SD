module fb_addr_gen #(
    parameter WIDTH = 320
) (
    input  wire [8:0] x,  // 0-319
    input  wire [7:0] y,  // 0-239
    output wire [16:0] addr
);
    // addr = y * 320 + x, sem multiplicador: 320 = 256 + 64
    assign addr = (y << 8) + (y << 6) + x;
endmodule