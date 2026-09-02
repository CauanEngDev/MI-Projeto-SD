module sprite_mover_flip #(
    parameter SLOT = 5'd5,
    parameter PATTERN_INDEX = 6'd2,  // reaproveita o padrao "L" ja existente
    parameter PRIORITY = 5'd3
)(
    input wire clk,
    input wire reset,

    input wire move_pulse,
    input wire [1:0] direction,   // 00=cima 01=baixo 10=esquerda 11=direita
    input wire flip_h_pulse,
    input wire flip_v_pulse,

    output reg        attr_wr_en,
    output reg [4:0]  attr_wr_addr,
    output reg [31:0] attr_wr_data
);
    localparam STEP = 9'd4;

    reg [8:0] pos_x;
    reg [7:0] pos_y;
    reg       flip_h, flip_v;

    wire [8:0] next_x = (!move_pulse) ? pos_x :
                        (direction==2'b10 && pos_x>=STEP)        ? pos_x-STEP :
                        (direction==2'b11 && pos_x<=9'd319-STEP) ? pos_x+STEP : pos_x;
    wire [7:0] next_y = (!move_pulse) ? pos_y :
                        (direction==2'b00 && pos_y>=STEP[7:0])        ? pos_y-STEP[7:0] :
                        (direction==2'b01 && pos_y<=8'd239-STEP[7:0]) ? pos_y+STEP[7:0] : pos_y;

    wire any_change = move_pulse | flip_h_pulse | flip_v_pulse;

    always @(posedge clk) begin
        if (reset) begin
            pos_x      <= 9'd150;
            pos_y      <= 8'd100;
            flip_h     <= 1'b0;
            flip_v     <= 1'b0;
            attr_wr_en <= 1'b0;
        end else begin
            pos_x  <= next_x;
            pos_y  <= next_y;
            if (flip_h_pulse) flip_h <= ~flip_h;
            if (flip_v_pulse) flip_v <= ~flip_v;

            attr_wr_en   <= any_change;
            attr_wr_addr <= SLOT;
            // enable=1 priority palette_sel=0 pattern_index fixo
            attr_wr_data <= {1'b1, PRIORITY,
                              (flip_v_pulse ? ~flip_v : flip_v),
                              (flip_h_pulse ? ~flip_h : flip_h),
                              1'b0, PATTERN_INDEX, next_y, next_x};
        end
    end
endmodule