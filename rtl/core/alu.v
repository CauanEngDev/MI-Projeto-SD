module alu (
    input        [2:0]  op,
    output reg   [31:0] rd,
    input        [31:0] rn,
    input        [31:0] b,
    input        [4:0]  shamt,

    // FLAGS
    input               valid,
    output wire         z,
    output wire         n,
    output wire         busy,
    output wire         done
);

    // Opcodes da ALU, alinhados aos opcodes da ISA (op = opcode[2:0])
    localparam ADD  = 3'b001;
    localparam SUB  = 3'b010;
    localparam AND  = 3'b011;
    localparam LSL  = 3'b100;
    localparam LSR  = 3'b101;
    localparam PASS = 3'b110;

    always @(*) begin
        rd = 32'b0; // Define valor padrão para quando valid não é acionado

        if (valid) begin
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
    end

    assign busy = 1'b0; // Busy é sempre 0 já que a ALU é combinacional
    assign done = valid; // Por rodar em um único ciclo, valid e done são o mesmo valor
    assign z = valid ? (rd == 32'b0) : 1'b0;
    assign n = valid ? rd[31] : 1'b0;
endmodule