`timescale 1ns/1ps

// ============================================================================
// Teste da ULA (flags N, Z, V, C) + avalia_condicao
// Para pares (a, b) de valores de borda e aleatorios:
//   - SUB: cada uma das 14 condicoes (+AL) tem que coincidir com a comparacao
//     matematica de a e b (com e sem sinal), calculada em 64 bits;
//   - ADD: C = carry de 33 bits, V = overflow com sinal;
//   - AND/LSL/LSR/PASS: C = V = 0;
//   - condicao 1111 nunca desvia e sinaliza "invalida".
// ============================================================================
module tb_condicoes_desvio;

    reg  [2:0]  op;
    reg  [31:0] a, b;
    reg         valid;
    wire [31:0] rd;
    wire        z, n, v, c, busy, done;

    alu u_alu (.op(op), .rd(rd), .rn(a), .b(b), .shamt(b[4:0]), .valid(valid),
               .z(z), .n(n), .v(v), .c(c), .busy(busy), .done(done));

    reg  [3:0] cond;
    wire       ok, invalida;
    avalia_condicao u_cond (.cond(cond), .flags({c, v, n, z}), .ok(ok), .invalida(invalida));

    localparam ADD = 3'b001, SUB = 3'b010, AND = 3'b011, LSL = 3'b100, LSR = 3'b101, PASS = 3'b110;

    integer errors = 0, checks = 0;
    integer i, j, k, jj;
    reg [31:0] edge_v [0:19];

    reg signed [63:0] sa, sb, ssub, sadd;
    reg        [63:0] ua, ub;
    reg [3:0]  cc;
    reg        esp;

    task testa_par;
        begin
            valid = 1;
            ua = {32'b0, a}; ub = {32'b0, b};
            sa = $signed(a); sb = $signed(b);

            // ------------------------------ SUB ------------------------------
            op = SUB; #1;
            ssub = sa - sb;
            if (rd !== a - b) begin errors = errors + 1; $display("ERRO SUB rd a=%h b=%h", a, b); end
            for (k = 0; k < 16; k = k + 1) begin
                cond = k; #1;
                case (k)
                    0:  esp = (a == b);
                    1:  esp = (a != b);
                    2:  esp = (ua >= ub);
                    3:  esp = (ua <  ub);
                    4:  esp = (a - b) >> 31;                       // MI
                    5:  esp = ~((a - b) >> 31);                    // PL
                    6:  esp = (ssub > 64'sd2147483647) || (ssub < -64'sd2147483648);   // VS
                    7:  esp = ~((ssub > 64'sd2147483647) || (ssub < -64'sd2147483648)); // VC
                    8:  esp = (ua >  ub);
                    9:  esp = (ua <= ub);
                    10: esp = (sa >= sb);
                    11: esp = (sa <  sb);
                    12: esp = (sa >  sb);
                    13: esp = (sa <= sb);
                    14: esp = 1;
                    default: esp = 0;
                endcase
                checks = checks + 1;
                if (ok !== esp) begin
                    errors = errors + 1;
                    if (errors < 20) $display("ERRO SUB cond=%0d a=%h b=%h: ok=%b esperado=%b", k, a, b, ok, esp);
                end
                if (invalida !== (k == 15)) begin errors = errors + 1; $display("ERRO invalida cond=%0d", k); end
            end

            // ------------------------------ ADD ------------------------------
            op = ADD; #1;
            sadd = sa + sb;
            if (rd !== a + b) begin errors = errors + 1; $display("ERRO ADD rd"); end
            checks = checks + 2;
            if (c !== ((ua + ub) >> 32) % 2) begin errors = errors + 1; if (errors < 20) $display("ERRO ADD carry a=%h b=%h c=%b", a, b, c); end
            if (v !== ((sadd > 64'sd2147483647) || (sadd < -64'sd2147483648))) begin errors = errors + 1; if (errors < 20) $display("ERRO ADD overflow a=%h b=%h v=%b", a, b, v); end

            // ----------------------- demais operacoes ------------------------
            for (jj = 0; jj < 4; jj = jj + 1) begin
                op = (jj == 0) ? AND : (jj == 1) ? LSL : (jj == 2) ? LSR : PASS; #1;
                checks = checks + 1;
                if (c !== 1'b0 || v !== 1'b0) begin errors = errors + 1; $display("ERRO op=%0d: c=%b v=%b (esperado 0)", op, c, v); end
            end

            // ------------------------- ULA sem valid -------------------------
            valid = 0; op = SUB; #1;
            checks = checks + 1;
            if (z !== 0 || n !== 0 || v !== 0 || c !== 0) begin errors = errors + 1; $display("ERRO: flags com valid = 0"); end
        end
    endtask

    initial begin
        edge_v[0]  = 32'h00000000; edge_v[1]  = 32'h00000001; edge_v[2]  = 32'h00000002;
        edge_v[3]  = 32'h00000005; edge_v[4]  = 32'h0000013F; edge_v[5]  = 32'h00000FFF;
        edge_v[6]  = 32'h7FFFFFFE; edge_v[7]  = 32'h7FFFFFFF; edge_v[8]  = 32'h80000000;
        edge_v[9]  = 32'h80000001; edge_v[10] = 32'hFFFFFFFE; edge_v[11] = 32'hFFFFFFFF;
        edge_v[12] = 32'hFFFFFFFB; edge_v[13] = 32'h0000FFFF; edge_v[14] = 32'h00010000;
        edge_v[15] = 32'hC0000000; edge_v[16] = 32'h40000000; edge_v[17] = 32'hAAAAAAAA;
        edge_v[18] = 32'h55555555; edge_v[19] = 32'hFFFF0000;

        // todos os pares de valores de borda
        for (i = 0; i < 20; i = i + 1)
            for (j = 0; j < 20; j = j + 1) begin
                a = edge_v[i]; b = edge_v[j];
                testa_par;
            end

        // pares aleatorios, incluindo a == b e vizinhos
        for (i = 0; i < 20000; i = i + 1) begin
            a = $random; b = $random;
            case (i % 4)
                1: b = a;
                2: b = a + ($random % 3);
                3: begin a = {$random} % 600; b = {$random} % 600; end
            endcase
            testa_par;
        end

        $display("");
        if (errors == 0) $display("tb_condicoes_desvio: TODOS OS TESTES PASSARAM (%0d verificacoes)", checks);
        else             $display("tb_condicoes_desvio: %0d ERRO(S)", errors);
        $finish;
    end
endmodule
