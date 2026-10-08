`include "rtl/include/isa.vh"

module alu (
    input        [:0]  op,
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