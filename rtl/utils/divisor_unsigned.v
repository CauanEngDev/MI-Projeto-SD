module divisor_unsigned #(
    parameter WIDTH = 24
)(
    input  wire               clk,
    input  wire               reset,
    input  wire               start,
    input  wire [WIDTH-1:0]   numerator,
    input  wire [WIDTH-1:0]   denominator,
    output reg  [WIDTH-1:0]   quotient,
    output reg                done
);
    reg [WIDTH-1:0] remainder;
    reg [WIDTH-1:0] num_shift;
    reg [4:0]       count;
    reg             busy;

    always @(posedge clk) begin
        if (reset) begin
            busy <= 1'b0;
            done <= 1'b0;
        end else if (start && !busy) begin
            remainder <= {WIDTH{1'b0}};
            num_shift <= numerator;
            quotient  <= {WIDTH{1'b0}};
            count     <= WIDTH[4:0];
            busy      <= 1'b1;
            done      <= 1'b0;
        end else if (busy) begin
            // Um passo de shift-and-subtract (divisão restauradora)
            if ({remainder[WIDTH-2:0], num_shift[WIDTH-1]} >= denominator) begin
                remainder <= {remainder[WIDTH-2:0], num_shift[WIDTH-1]} - denominator;
                quotient  <= {quotient[WIDTH-2:0], 1'b1};
            end else begin
                remainder <= {remainder[WIDTH-2:0], num_shift[WIDTH-1]};
                quotient  <= {quotient[WIDTH-2:0], 1'b0};
            end
            num_shift <= {num_shift[WIDTH-2:0], 1'b0};
            count     <= count - 5'd1;
            if (count == 5'd1) begin
                busy <= 1'b0;
                done <= 1'b1;
            end
        end else begin
            done <= 1'b0;
        end
    end
endmodule