// Stubs das IPs do Quartus, so para simulacao
module pll01(input refclk, input rst, output reg outclk_0, output locked);
    initial outclk_0 = 0;
    always @(posedge refclk) outclk_0 <= ~outclk_0;
    assign locked = ~rst;
endmodule

module ram_stub #(parameter AW = 9, DW = 9, N = 512) (
    input clock, input [DW-1:0] data, input [AW-1:0] wraddress, input wren,
    input [AW-1:0] rdaddress, output reg [DW-1:0] q);
    reg [DW-1:0] mem [0:N-1];
    reg [AW-1:0] a_r;
    integer i;
    initial for (i = 0; i < N; i = i + 1) mem[i] = 0;
    always @(posedge clock) begin
        if (wren) mem[wraddress] <= data;
        a_r <= rdaddress;
        q   <= mem[a_r];
    end
endmodule
module palette_ram(input clock, input [8:0] data, input [8:0] wraddress, input wren, input [8:0] rdaddress, output [8:0] q);
    ram_stub #(9,9,512) r(clock,data,wraddress,wren,rdaddress,q);
endmodule
module bg_tile_ram(input clock, input [7:0] data, input [10:0] wraddress, input wren, input [10:0] rdaddress, output [7:0] q);
    ram_stub #(11,8,2048) r(clock,data,wraddress,wren,rdaddress,q);
endmodule
module bg_tile_pattern_ram(input clock, input [7:0] data, input [13:0] wraddress, input wren, input [13:0] rdaddress, output [7:0] q);
    ram_stub #(14,8,16384) r(clock,data,wraddress,wren,rdaddress,q);
endmodule
module sprite_pattern_ram(input clock, input [7:0] data, input [13:0] wraddress, input wren, input [13:0] rdaddress, output [7:0] q);
    ram_stub #(14,8,16384) r(clock,data,wraddress,wren,rdaddress,q);
endmodule

module framebuffer_ram(input [8:0] data, input [16:0] wraddress, input wrclock, input wren,
                       input [16:0] rdaddress, input rdclock, output reg [8:0] q);
    reg [8:0] mem [0:76799];
    integer i;
    initial for (i = 0; i < 76800; i = i + 1) mem[i] = 9'h1FF;
    always @(posedge wrclock) if (wren) mem[wraddress] <= data;
    always @(posedge rdclock) q <= mem[rdaddress];
endmodule

module instruction_memory(input [13:0] address, input clock, input [31:0] data, input wren, output reg [31:0] q);
    reg [31:0] mem [0:16383];
    reg [13:0] a_r;
    reg [1023:0] f;
    integer i;
    initial begin
        for (i = 0; i < 16384; i = i + 1) mem[i] = 0;
        if ($value$plusargs("HEX=%s", f)) $readmemh(f, mem);
    end
    always @(posedge clock) begin a_r <= address; q <= mem[a_r]; end
endmodule
