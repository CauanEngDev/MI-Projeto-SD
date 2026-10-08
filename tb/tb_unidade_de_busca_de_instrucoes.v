
`timescale 1ns/1ps

// ============================================================================
// TESTBENCH - UNIDADE DE BUSCA DE INSTRUCOES
// ----------------------------------------------------------------------------
// Autoverificavel: imprime "ok"/"FALHOU" por verificacao e um resumo no fim.
//
// Arquivos a compilar:
//   tb_unidade_de_busca_de_instrucoes.v
//   unidade_de_busca_de_instrucoes.v
//   Program_counter.v
//   Adder.v
//
// A memoria de instrucoes agora e comportamental e esta dentro da propria
// unidade_de_busca_de_instrucoes:
//
//   u.mem_data[indice]
//
// Nao utiliza instruction_memory, altsyncram ou biblioteca altera_mf.
//
// Tres instancias da unidade de busca rodam em paralelo:
//   h1: INICIAR_AUTO=1, LOOP_AUTO=1  programa P1
//   h2: INICIAR_AUTO=0, LOOP_AUTO=0  espera "start"; nao reinicia sozinho
//   h3: INICIAR_AUTO=1, LOOP_AUTO=1  memoria inteira de NOPs
//
// Programa P1 (indice da palavra):
//   0 NOP | 1 PASS R0,#1 | 2 SET_PALETTE | 3 DRAW_RECT | 4 DRAW_TRI |
//   5 DRAW_BG | 6 DRAW_SPRITES | 7 WAIT_VBLANK | 8 opcode reservado | 9 HALT
//
// Modelo dos motores: o done chega L+1 ciclos apos o pulso execute
//   (DRAW_RECT L=7, DRAW_TRI L=5, DRAW_BG L=12, DRAW_SPRITES L=30).
//
// vblank sobe nos ciclos 400, 800, 1200, ... e fica alto por 20 ciclos.
//
// Convencao: "ciclo n" e o n-esimo periodo de clock desde o inicio; um sinal
// amostrado na borda de subida pertence ao ciclo que termina nela.
// ============================================================================


module fetch_harness #(
    parameter INICIAR_AUTO = 1,
    parameter LOOP_AUTO    = 1,
    parameter PROG         = 1
) (
    input wire        clk,
    input wire        reset,
    input wire        start,
    input wire        vblank,
    input wire [31:0] cyc
);

    wire [15:0] pc;
    wire [31:0] instruction;
    wire        execute;
    wire        frame_swap;
    wire        running;
    wire        waiting;
    wire        invalid_opcode;

    reg engine_done = 1'b0;

    // ------------------------------------------------------------------------
    // Unidade de busca
    // ------------------------------------------------------------------------

    unidade_de_busca_de_instrucoes #(
        .LAT_MEM      (2),
        .INICIAR_AUTO (INICIAR_AUTO),
        .LOOP_AUTO    (LOOP_AUTO)
    ) u (
        .clk            (clk),
        .reset          (reset),
        .start          (start),
        .engine_done    (engine_done),
        .vblank         (vblank),
        .pc             (pc),
        .instruction    (instruction),
        .execute        (execute),
        .frame_swap     (frame_swap),
        .running        (running),
        .waiting        (waiting),
        .invalid_opcode (invalid_opcode)
    );

    // ------------------------------------------------------------------------
    // Programa de teste
    //
    // A memoria agora pertence diretamente a unidade de busca.
    // Nao existe mais altsyncram_component.
    // ------------------------------------------------------------------------

    integer k;

    initial begin
        #1;

        // Inicializa toda a memoria com NOP
        for (k = 0; k < 16384; k = k + 1)
            u.mem_data[k] = 32'd0;

        if (PROG == 1) begin

            // 0 - NOP
            u.mem_data[0] =
                {5'b00000, 27'd0};

            // 1 - PASS R0,#1
            u.mem_data[1] =
                {5'b00110, 1'b1, 5'd0, 6'd31, 3'd0, 12'd1};

            // 2 - SET_PALETTE R0,R0
            u.mem_data[2] =
                {5'b00111, 6'd0, 6'd0, 15'd0};

            // 3 - DRAW_RECT
            u.mem_data[3] =
                {5'b01000, 27'd0};

            // 4 - DRAW_TRI
            u.mem_data[4] =
                {5'b01001, 27'd0};

            // 5 - DRAW_BG
            u.mem_data[5] =
                {5'b10000, 27'd0};

            // 6 - DRAW_SPRITES
            u.mem_data[6] =
                {5'b10001, 27'd0};

            // 7 - WAIT_VBLANK
            u.mem_data[7] =
                {5'b10010, 27'd0};

            // 8 - opcode reservado
            u.mem_data[8] =
                {5'b10100, 27'd5};

            // 9 - HALT
            u.mem_data[9] =
                {5'b10011, 27'd0};
        end
    end

    // ------------------------------------------------------------------------
    // Modelo dos motores
    //
    // done = L + 1 ciclos apos execute
    // ------------------------------------------------------------------------

    function integer latencia;
        input [4:0] op;

        begin
            case (op)
                5'b01000: latencia = 7;    // DRAW_RECT
                5'b01001: latencia = 5;    // DRAW_TRI
                5'b10000: latencia = 12;   // DRAW_BG
                5'b10001: latencia = 30;   // DRAW_SPRITES
                default:  latencia = 0;
            endcase
        end
    endfunction

    integer cnt = 0;

    always @(posedge clk) begin

        engine_done <= 1'b0;

        if (cnt > 0) begin
            cnt <= cnt - 1;

            if (cnt == 1)
                engine_done <= 1'b1;
        end

        if (execute && latencia(instruction[31:27]) > 0)
            cnt <= latencia(instruction[31:27]);
    end

    // ------------------------------------------------------------------------
    // Registro de eventos
    // ------------------------------------------------------------------------

    integer exec_n     = 0;
    integer swap_n     = 0;
    integer done_n     = 0;
    integer invalid_n  = 0;

    integer viol_hold   = 0;
    integer viol_double = 0;
    integer viol_reset  = 0;

    reg prev_exec = 1'b0;

    reg [15:0] last_exec_pc = 16'd0;

    reg [15:0] exec_pc [0:19999];

    integer exec_cyc [0:19999];
    integer swap_cyc [0:15];
    integer done_cyc [0:63];

    always @(posedge clk) begin

        prev_exec <= execute;

        // ------------------------------------------------------------
        // Execute
        // ------------------------------------------------------------

        if (execute) begin

            exec_pc[exec_n]  <= pc;
            exec_cyc[exec_n] <= cyc;
            exec_n           <= exec_n + 1;

            last_exec_pc <= pc;

            if (reset)
                viol_reset <= viol_reset + 1;

            if (prev_exec)
                viol_double <= viol_double + 1;
        end

        // ------------------------------------------------------------
        // Frame swap
        // ------------------------------------------------------------

        if (frame_swap) begin
            swap_cyc[swap_n] <= cyc;
            swap_n           <= swap_n + 1;
        end

        // ------------------------------------------------------------
        // Engine done
        // ------------------------------------------------------------

        if (engine_done) begin
            done_cyc[done_n] <= cyc;
            done_n           <= done_n + 1;
        end

        // ------------------------------------------------------------
        // Opcode invalido
        // ------------------------------------------------------------

        if (invalid_opcode)
            invalid_n <= invalid_n + 1;

        // ------------------------------------------------------------
        // Enquanto espera um evento, o PC nao pode sair da instrucao
        // lancada.
        // ------------------------------------------------------------

        if (waiting && (pc != last_exec_pc))
            viol_hold <= viol_hold + 1;
    end

endmodule


// ============================================================================
// TESTBENCH PRINCIPAL
// ============================================================================

module tb_unidade_de_busca_de_instrucoes;

    reg clk = 1'b0;

    always #10 clk = ~clk;                       // 50 MHz

    reg reset = 1'b1;

    reg start1 = 1'b0;
    reg start2 = 1'b0;

    reg vblank = 1'b0;

    reg [31:0] cyc = 32'd0;

    always @(posedge clk)
        cyc <= cyc + 1;

    // ------------------------------------------------------------------------
    // VBlank:
    // sobe nos ciclos 400, 800, 1200, ...
    // permanece alto por 20 ciclos.
    // ------------------------------------------------------------------------

    always @(posedge clk)
        vblank <= (((cyc + 1) % 400) < 20) &&
                  ((cyc + 1) >= 400);

    // ------------------------------------------------------------------------
    // Instancias
    // ------------------------------------------------------------------------

    fetch_harness #(
        .INICIAR_AUTO(1),
        .LOOP_AUTO   (1),
        .PROG        (1)
    ) h1 (
        .clk           (clk),
        .reset         (reset),
        .start         (start1),
        .vblank        (vblank),
        .cyc           (cyc)
    );

    fetch_harness #(
        .INICIAR_AUTO(0),
        .LOOP_AUTO   (0),
        .PROG         (1)
    ) h2 (
        .clk           (clk),
        .reset         (reset),
        .start         (start2),
        .vblank        (vblank),
        .cyc           (cyc)
    );

    fetch_harness #(
        .INICIAR_AUTO(1),
        .LOOP_AUTO    (1),
        .PROG         (0)
    ) h3 (
        .clk           (clk),
        .reset         (reset),
        .start         (1'b0),
        .vblank        (vblank),
        .cyc           (cyc)
    );

    // ------------------------------------------------------------------------
    // Utilidades
    // ------------------------------------------------------------------------

    integer fails  = 0;
    integer checks = 0;

    task chk;
        input [8*60-1:0] nome;
        input             cond;

        begin
            checks = checks + 1;

            if (cond)
                $display("ok      %0s", nome);
            else begin
                fails = fails + 1;
                $display("FALHOU  %0s", nome);
            end
        end
    endtask

    task chk_int;
        input [8*60-1:0] nome;
        input integer     obtido;
        input integer     esperado;

        begin
            checks = checks + 1;

            if (obtido == esperado)
                $display("ok      %0s = %0d", nome, obtido);
            else begin
                fails = fails + 1;
                $display(
                    "FALHOU  %0s: obtido=%0d esperado=%0d",
                    nome,
                    obtido,
                    esperado
                );
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Ciclo em que o reset foi liberado e ciclos em que os starts foram vistos
    // ------------------------------------------------------------------------

    integer r_cyc  = -1;
    integer s1_cyc = -1;
    integer s2_cyc = -1;

    always @(posedge clk) begin

        if (!reset && r_cyc < 0)
            r_cyc <= cyc;

        if (start1)
            s1_cyc <= cyc;

        if (start2)
            s2_cyc <= cyc;
    end

    integer i;
    integer bad;

    // ========================================================================
    // SEQUENCIA PRINCIPAL
    // ========================================================================

    initial begin

        repeat (5) @(posedge clk);

        reset <= 1'b0;

        // =====================================================================
        // h1: primeiro passe do programa P1
        // =====================================================================

        wait (h1.exec_n >= 10);

        $display("--- h1: passe 1 (INICIAR_AUTO=1, LOOP_AUTO=1) ---");

        chk_int(
            "h1 primeiro execute (reset + 1)",
            h1.exec_cyc[0],
            r_cyc + 1
        );

        bad = 0;

        for (i = 0; i < 10; i = i + 1)
            if (h1.exec_pc[i] !== 4 * i)
                bad = bad + 1;

        chk_int(
            "h1 sequencia de PCs 0..36",
            bad,
            0
        );

        chk_int(
            "h1 NOP -> PASS (2 ciclos)",
            h1.exec_cyc[1] - h1.exec_cyc[0],
            2
        );

        chk_int(
            "h1 PASS -> SET_PALETTE (2 ciclos)",
            h1.exec_cyc[2] - h1.exec_cyc[1],
            2
        );

        chk_int(
            "h1 SET_PALETTE -> DRAW_RECT",
            h1.exec_cyc[3] - h1.exec_cyc[2],
            2
        );

        chk_int(
            "h1 DRAW_RECT: done em L+1",
            h1.done_cyc[0] - h1.exec_cyc[3],
            8
        );

        chk_int(
            "h1 DRAW_TRI: done em L+1",
            h1.done_cyc[1] - h1.exec_cyc[4],
            6
        );

        chk_int(
            "h1 DRAW_BG: done em L+1",
            h1.done_cyc[2] - h1.exec_cyc[5],
            13
        );

        chk_int(
            "h1 DRAW_SPRITES: done em L+1",
            h1.done_cyc[3] - h1.exec_cyc[6],
            31
        );

        chk_int(
            "h1 DRAW_TRI segue o done + 2",
            h1.exec_cyc[4],
            h1.done_cyc[0] + 2
        );

        chk_int(
            "h1 DRAW_BG segue o done + 2",
            h1.exec_cyc[5],
            h1.done_cyc[1] + 2
        );

        chk_int(
            "h1 DRAW_SPRITES segue o done + 2",
            h1.exec_cyc[6],
            h1.done_cyc[2] + 2
        );

        chk_int(
            "h1 WAIT_VBLANK segue o done + 2",
            h1.exec_cyc[7],
            h1.done_cyc[3] + 2
        );

        chk(
            "h1 WAIT_VBLANK lancado antes do vblank",
            h1.exec_cyc[7] < 400
        );

        chk_int(
            "h1 WAIT_VBLANK libera na borda (400 + 2)",
            h1.exec_cyc[8],
            402
        );

        chk_int(
            "h1 opcode reservado: 1 pulso",
            h1.invalid_n,
            1
        );

        chk_int(
            "h1 reservado -> HALT (2 ciclos)",
            h1.exec_cyc[9] - h1.exec_cyc[8],
            2
        );

        chk_int(
            "h1 sem troca de buffer no passe 1",
            h1.swap_n,
            0
        );

        chk_int(
            "h1 execute duplicado",
            h1.viol_double,
            0
        );

        chk_int(
            "h1 execute durante reset",
            h1.viol_reset,
            0
        );

        chk_int(
            "h1 PC fora do lugar enquanto espera",
            h1.viol_hold,
            0
        );

        // =====================================================================
        // HALT
        // =====================================================================

        repeat (20) @(posedge clk);

        chk(
            "h1 apos HALT: running = 0",
            h1.running === 1'b0
        );

        chk_int(
            "h1 apos HALT: nenhum execute novo",
            h1.exec_n,
            10
        );

        // =====================================================================
        // VBlank em 800: troca de buffer e reinicio
        // =====================================================================

        wait (h1.swap_n >= 1);

        $display("--- h1: troca de buffer e reinicio ---");

        chk_int(
            "h1 frame_swap no vblank (ciclo 800)",
            h1.swap_cyc[0],
            800
        );

        wait (h1.exec_n >= 11);

        chk_int(
            "h1 reinicia no PC 0",
            h1.exec_pc[10],
            0
        );

        chk_int(
            "h1 reinicio em swap + 2",
            h1.exec_cyc[10],
            802
        );

        chk(
            "h1 running = 1 apos o reinicio",
            h1.running === 1'b1
        );

        // =====================================================================
        // Botao start durante WAIT_VBLANK do passe 2
        // =====================================================================

        wait (h1.exec_n >= 18);

        repeat (10) @(posedge clk);

        start1 <= 1'b1;

        @(posedge clk);

        start1 <= 1'b0;

        wait (h1.exec_n >= 19);

        $display("--- h1: botao start no meio do programa ---");

        chk_int(
            "h1 start: reinicia no PC 0",
            h1.exec_pc[18],
            0
        );

        chk_int(
            "h1 start: execute em start + 2",
            h1.exec_cyc[18],
            s1_cyc + 2
        );

        chk_int(
            "h1 start nao troca buffer",
            h1.swap_n,
            1
        );

        // =====================================================================
        // Passe 3 ate HALT
        // =====================================================================

        wait (h1.exec_n >= 28);

        chk_int(
            "h1 passe 3: WAIT_VBLANK libera em 1200 + 2",
            h1.exec_cyc[26],
            1202
        );

        chk_int(
            "h1 passe 3: nenhum troca de buffer",
            h1.swap_n,
            1
        );

        // =====================================================================
        // Start com programa encerrado
        // =====================================================================

        repeat (20) @(posedge clk);

        chk(
            "h1 HALT do passe 3: running = 0",
            h1.running === 1'b0
        );

        start1 <= 1'b1;

        @(posedge clk);

        start1 <= 1'b0;

        wait (h1.exec_n >= 29);

        $display("--- h1: start apos HALT ---");

        chk_int(
            "h1 start apos HALT: PC 0",
            h1.exec_pc[28],
            0
        );

        chk_int(
            "h1 start apos HALT: execute em start + 2",
            h1.exec_cyc[28],
            s1_cyc + 2
        );

        chk(
            "h1 start apos HALT: running = 1",
            h1.running === 1'b1
        );

        // =====================================================================
        // VBlank em 1600: programa ainda em execucao
        // =====================================================================

        wait (h1.exec_n >= 38);

        chk_int(
            "h1 passe 4: WAIT_VBLANK libera em 1600 + 2",
            h1.exec_cyc[36],
            1602
        );

        chk_int(
            "h1 vblank com programa em curso nao troca buffer",
            h1.swap_n,
            1
        );

        // =====================================================================
        // VBlank em 2000: troca de buffer
        // =====================================================================

        wait (h1.swap_n >= 2);

        chk_int(
            "h1 segunda troca de buffer (ciclo 2000)",
            h1.swap_cyc[1],
            2000
        );

        wait (h1.exec_n >= 39);

        chk_int(
            "h1 reinicio apos a segunda troca",
            h1.exec_cyc[38],
            2002
        );

        chk_int(
            "h1 opcode reservado: 1 pulso por passe completo",
            h1.invalid_n,
            3
        );

        chk_int(
            "h1 execute duplicado (total)",
            h1.viol_double,
            0
        );

        chk_int(
            "h1 PC fora do lugar enquanto espera (total)",
            h1.viol_hold,
            0
        );

        // =====================================================================
        // h2: INICIAR_AUTO=0 e LOOP_AUTO=0
        // =====================================================================

        $display("--- h2: INICIAR_AUTO=0, LOOP_AUTO=0 ---");

        chk_int(
            "h2 parado ate o start: nenhum execute",
            h2.exec_n >= 1,
            0
        );

        chk(
            "h2 parado ate o start: running = 0",
            h2.running === 1'b0
        );

        // ---------------------------------------------------------------------
        // Start
        // ---------------------------------------------------------------------

        start2 <= 1'b1;

        @(posedge clk);

        start2 <= 1'b0;

        wait (h2.exec_n >= 1);

        chk_int(
            "h2 start: primeiro execute em start + 2",
            h2.exec_cyc[0],
            s2_cyc + 2
        );

        chk_int(
            "h2 start: PC 0",
            h2.exec_pc[0],
            0
        );

        wait (h2.exec_n >= 10);

        chk_int(
            "h2 passe completo ate o HALT (10 execute)",
            h2.exec_n,
            10
        );

        // ---------------------------------------------------------------------
        // Dois vblanks depois do HALT
        // ---------------------------------------------------------------------

        repeat (900) @(posedge clk);

        chk_int(
            "h2 LOOP_AUTO=0: sem reinicio automatico",
            h2.exec_n,
            10
        );

        chk_int(
            "h2 LOOP_AUTO=0: sem troca de buffer",
            h2.swap_n,
            0
        );

        chk(
            "h2 LOOP_AUTO=0: running = 0",
            h2.running === 1'b0
        );

        // ---------------------------------------------------------------------
        // Novo start
        // ---------------------------------------------------------------------

        start2 <= 1'b1;

        @(posedge clk);

        start2 <= 1'b0;

        wait (h2.exec_n >= 11);

        chk_int(
            "h2 novo start: PC 0",
            h2.exec_pc[10],
            0
        );

        chk_int(
            "h2 novo start: execute em start + 2",
            h2.exec_cyc[10],
            s2_cyc + 2
        );

        chk_int(
            "h2 execute duplicado",
            h2.viol_double,
            0
        );

        // =====================================================================
        // h3: memoria inteira de NOPs
        // =====================================================================

        $display("--- h3: fim da memoria ---");

        wait (h3.exec_n >= 16384);

        chk_int(
            "h3 sem troca de buffer durante a execucao",
            h3.swap_n,
            0
        );

        chk_int(
            "h3 primeiro execute (reset + 1)",
            h3.exec_cyc[0],
            r_cyc + 1
        );

        bad = 0;

        for (i = 0; i < 16384; i = i + 1)
            if (h3.exec_pc[i] !== 4 * i)
                bad = bad + 1;

        chk_int(
            "h3 PCs 0..65532 em sequencia",
            bad,
            0
        );

        bad = 0;

        for (i = 1; i < 16384; i = i + 1)
            if ((h3.exec_cyc[i] - h3.exec_cyc[i-1]) != 2)
                bad = bad + 1;

        chk_int(
            "h3 espacamento de 2 ciclos entre NOPs",
            bad,
            0
        );

        chk_int(
            "h3 ultimo PC executado (65532)",
            h3.exec_pc[16383],
            16'hFFFC
        );

        repeat (10) @(posedge clk);

        chk(
            "h3 fim da memoria: running = 0",
            h3.running === 1'b0
        );

        chk_int(
            "h3 fim da memoria: PC fica na ultima palavra",
            h3.pc,
            16'hFFFC
        );

        chk_int(
            "h3 fim da memoria: nao executa alem",
            h3.exec_n,
            16384
        );

        wait (h3.swap_n >= 1);

        wait (h3.exec_n >= 16385);

        chk_int(
            "h3 reinicia no PC 0 apos o vblank",
            h3.exec_pc[16384],
            0
        );

        chk_int(
            "h3 reinicio em swap + 2",
            h3.exec_cyc[16384],
            h3.swap_cyc[0] + 2
        );

        // =====================================================================
        // RESULTADO
        // =====================================================================

        $display("");

        if (fails == 0)
            $display(
                "TODOS OS TESTES PASSARAM (%0d verificacoes)",
                checks
            );
        else
            $display(
                "FALHAS: %0d de %0d verificacoes",
                fails,
                checks
            );

        $finish;
    end

    // ------------------------------------------------------------------------
    // Timeout
    // ------------------------------------------------------------------------

    initial begin
        #8000000;

        $display("TIMEOUT");

        $finish;
    end

endmodule

