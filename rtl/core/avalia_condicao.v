// ============================================================================
// AVALIACAO DE CONDICAO DOS DESVIOS (B_COND)
// ----------------------------------------------------------------------------
// Puramente combinacional. Mesmos codigos de condicao do ARMv8/LEGv8:
//
//   cond  mnemonico  condicao                       uso apos SUB (a - b)
//   0000  EQ         Z = 1                          a == b
//   0001  NE         Z = 0                          a != b
//   0010  HS         C = 1                          a >= b  (sem sinal)
//   0011  LO         C = 0                          a <  b  (sem sinal)
//   0100  MI         N = 1                          resultado negativo
//   0101  PL         N = 0                          resultado nao negativo
//   0110  VS         V = 1                          overflow
//   0111  VC         V = 0                          sem overflow
//   1000  HI         C = 1 e Z = 0                  a >  b  (sem sinal)
//   1001  LS         C = 0 ou Z = 1                 a <= b  (sem sinal)
//   1010  GE         N = V                          a >= b  (com sinal)
//   1011  LT         N != V                         a <  b  (com sinal)
//   1100  GT         Z = 0 e N = V                  a >  b  (com sinal)
//   1101  LE         Z = 1 ou N != V                a <= b  (com sinal)
//   1110  AL         sempre
//   1111  (reservado) nunca desvia; "invalida" = 1
//
// flags = {C, V, N, Z}, no mesmo layout do registrador FLAGS (36).
// ============================================================================
module avalia_condicao (
    input  wire [3:0] cond,
    input  wire [3:0] flags,
    output reg        ok,         // 1 = condicao satisfeita
    output wire       invalida    // 1 = codigo de condicao reservado
);

    wire z = flags[0];
    wire n = flags[1];
    wire v = flags[2];
    wire c = flags[3];

    always @(*) begin
        case (cond)
            4'b0000: ok = z;               // EQ
            4'b0001: ok = ~z;              // NE
            4'b0010: ok = c;               // HS
            4'b0011: ok = ~c;              // LO
            4'b0100: ok = n;               // MI
            4'b0101: ok = ~n;              // PL
            4'b0110: ok = v;               // VS
            4'b0111: ok = ~v;              // VC
            4'b1000: ok = c & ~z;          // HI
            4'b1001: ok = ~c | z;          // LS
            4'b1010: ok = (n == v);        // GE
            4'b1011: ok = (n != v);        // LT
            4'b1100: ok = ~z & (n == v);   // GT
            4'b1101: ok = z | (n != v);    // LE
            4'b1110: ok = 1'b1;            // AL
            default: ok = 1'b0;            // reservado: nunca desvia
        endcase
    end

    assign invalida = (cond == 4'b1111);

endmodule
