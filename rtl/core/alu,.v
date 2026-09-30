module alu (
    input        [2:0] op,
    output reg   [31:0] rd,
    input        [31:0] rn,
    input        [31:0] b,
    input        [4:0] shamt
);

    // Opcodes da ALU
    localparam ADD  = 3'b000;
    localparam SUB  = 3'b001;
    localparam AND  = 3'b010;
    localparam LSL  = 3'b011;
    localparam LSR  = 3'b100;
    localparam PASS = 3'b101;

    always @(*) begin
        case (op)
            ADD: begin
                rd = rn + b;
            end

            SUB: begin
                rd = rn - b;
            end

            AND: begin
                rd = rn & b;
            end

            LSL: begin
                rd = rn << shamt;
            end

            LSR: begin
                rd = rn >> shamt;
            end

            PASS: begin
                rd = b;
            end
        endcase
    end
endmodule