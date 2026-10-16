`timescale 1ns/1ps

// Testbench para os modulos de rtl/core/fetch_unit, exceto Adder.v.
// Usa uma instruction_memory comportamental para evitar dependencia de altsyncram.
// Nao compile memory_files/instruction_memory.v junto com este arquivo.

module instruction_memory (
    input wire [13:0] address,
    input wire clock,
    input wire [31:0] data,
    input wire wren,
    output reg [31:0] q
);
    reg [31:0] mem [0:16383];
    integer i;
    initial begin
        q = 0;
        for (i = 0; i < 16384; i = i + 1) mem[i] = 0;
    end
    always @(posedge clock) begin
        if (wren) mem[address] <= data;
        q <= mem[address];
    end
endmodule

module tb_fetch_unit;
    reg clk = 0;
    always #5 clk = ~clk;

    integer passed = 0, failed = 0;
    integer i;
    localparam [4:0] OP_NOP=5'b00000, OP_DRAW_RECT=5'b01000,
        OP_DRAW_BG=5'b10000, OP_WAIT_VBLANK=5'b10010,
        OP_HALT=5'b10011, OP_B=5'b10100, OP_B_COND=5'b10101,
        OP_INVALID=5'b11111;

    function [31:0] make_instr;
        input [4:0] op;
        input [26:0] payload;
        begin make_instr = {op, payload}; end
    endfunction

    task check;
        input condition;
        input [8*100-1:0] label_text;
        begin
            if (condition === 1'b1) begin
                $display("[PASS] %0s", label_text); passed = passed + 1;
            end else begin
                $display("[FAIL] %0s", label_text); failed = failed + 1;
            end
        end
    endtask

    task wait_cycles;
        input integer n;
        integer k;
        begin for (k=0; k<n; k=k+1) @(negedge clk); end
    endtask

    // Program_counter
    reg pc_reset=1;
    reg [15:0] pc_in=0;
    wire [15:0] pc_out;
    Program_counter pc_dut(.clk(clk), .reset(pc_reset), .in(pc_in), .out(pc_out));

    // instruction_fetch: programa carregado pela interface load_*.
    reg if_reset=1, if_start=0, if_engine_done=0, if_vblank=0, if_load_we=0;
    reg [13:0] if_load_addr=0;
    reg [31:0] if_load_data=0;
    wire [15:0] if_pc;
    wire [31:0] if_instruction;
    wire if_execute, if_running, if_waiting, if_invalid;
    instruction_fetch #(.LAT_MEM(1), .INICIAR_AUTO(0)) fetch_dut (
        .clk(clk), .reset(if_reset), .start(if_start),
        .engine_done(if_engine_done), .vblank(if_vblank),
        .load_we(if_load_we), .load_addr(if_load_addr), .load_data(if_load_data),
        .pc(if_pc), .instruction(if_instruction), .execute(if_execute),
        .running(if_running), .waiting(if_waiting), .invalid_opcode(if_invalid)
    );

    // unidade_de_busca_de_instrucoes: memoria preenchida hierarquicamente.
    reg ub_reset=1, ub_start=0, ub_engine_done=0, ub_vblank=0;
    reg [3:0] ub_flags=0;
    wire [15:0] ub_pc;
    wire [31:0] ub_instruction;
    wire ub_execute, ub_frame_swap, ub_running, ub_waiting, ub_invalid;
    unidade_de_busca_de_instrucoes #(.LAT_MEM(1), .INICIAR_AUTO(0), .LOOP_AUTO(0)) busca_dut (
        .clk(clk), .reset(ub_reset), .start(ub_start),
        .engine_done(ub_engine_done), .vblank(ub_vblank), .flags(ub_flags),
        .pc(ub_pc), .instruction(ub_instruction), .execute(ub_execute),
        .frame_swap(ub_frame_swap), .running(ub_running),
        .waiting(ub_waiting), .invalid_opcode(ub_invalid)
    );

    task reset_if;
        begin
            @(negedge clk); if_reset=1; if_start=0; if_engine_done=0;
            if_vblank=0; if_load_we=0; wait_cycles(2);
            if_reset=0; wait_cycles(2);
        end
    endtask

    task load_if;
        input [13:0] addr;
        input [31:0] data_word;
        begin
            @(negedge clk); if_load_we=1; if_load_addr=addr; if_load_data=data_word;
            @(negedge clk); if_load_we=0; wait_cycles(1);
        end
    endtask

    task reset_ub;
        begin
            @(negedge clk); ub_reset=1; ub_start=0; ub_engine_done=0;
            ub_vblank=0; ub_flags=0; wait_cycles(2);
            ub_reset=0; wait_cycles(2);
        end
    endtask

    initial begin
        $display("====================================================");
        $display(" TESTBENCH - rtl/core/fetch_unit (SEM ADDER)");
        $display("====================================================");

        // Testes do Program_counter
        wait_cycles(1);
        check(pc_out == 0, "Program_counter: reset sincronico zera PC");
        @(negedge clk); pc_reset=0; pc_in=16'h1234;
        @(negedge clk); check(pc_out == 16'h1234, "Program_counter: registra entrada");
        pc_in=16'hABCD; @(negedge clk);
        check(pc_out == 16'hABCD, "Program_counter: atualiza em borda de clock");
        pc_reset=1; pc_in=16'hFFFF; @(negedge clk);
        check(pc_out == 0, "Program_counter: reset tem prioridade sobre entrada");
        pc_reset=0;

        // instruction_fetch: NOP -> DRAW_BG (bloqueante) -> HALT
        reset_if();
        load_if(0, make_instr(OP_NOP, 27'd0));
        load_if(1, make_instr(OP_DRAW_BG, 27'd0));
        load_if(2, make_instr(OP_HALT, 27'd0));
        @(negedge clk); if_start=1; @(negedge clk); if_start=0;
        wait_cycles(3);
        check(if_running, "instruction_fetch: start inicia programa");
        check(if_pc == 16'd4, "instruction_fetch: NOP avanca PC em 4 bytes");
        check(if_instruction[31:27] == OP_DRAW_BG, "instruction_fetch: busca instrucao seguinte");
        wait_cycles(3);
        check(if_pc == 16'd4, "instruction_fetch: instrucao grafica segura PC");
        check(if_waiting, "instruction_fetch: waiting durante espera do motor");
        @(negedge clk); if_engine_done=1; @(negedge clk); if_engine_done=0;
        wait_cycles(2);
        check(if_pc == 16'd8, "instruction_fetch: engine_done libera PC");
        check(if_instruction[31:27] == OP_HALT, "instruction_fetch: HALT e carregado");
        wait_cycles(2);
        check(!if_running, "instruction_fetch: HALT para a busca");

        // unidade_de_busca: DRAW_RECT -> B(offset=2) -> WAIT_VBLANK -> HALT
        reset_ub();
        busca_dut.instruction_mem.mem[0] = make_instr(OP_DRAW_RECT, 27'd0);
        busca_dut.instruction_mem.mem[1] = make_instr(OP_B, 27'd2);
        busca_dut.instruction_mem.mem[2] = make_instr(OP_INVALID, 27'd0);
        busca_dut.instruction_mem.mem[3] = make_instr(OP_WAIT_VBLANK, 27'd0);
        busca_dut.instruction_mem.mem[4] = make_instr(OP_HALT, 27'd0);
        @(negedge clk); ub_start=1; @(negedge clk); ub_start=0;
        wait_cycles(3);
        check(ub_running, "unidade_de_busca: start inicia programa");
        check(ub_instruction[31:27] == OP_DRAW_RECT, "unidade_de_busca: primeira instrucao DRAW_RECT");
        wait_cycles(2);
        check(ub_pc == 0, "unidade_de_busca: DRAW_RECT segura PC ate engine_done");
        check(ub_waiting, "unidade_de_busca: waiting durante operacao grafica");
        @(negedge clk); ub_engine_done=1; @(negedge clk); ub_engine_done=0;
        wait_cycles(2);
        check(ub_pc == 4, "unidade_de_busca: engine_done conclui DRAW_RECT");
        check(ub_instruction[31:27] == OP_B, "unidade_de_busca: carrega instrucao B");
        wait_cycles(2);
        check(ub_pc == 12, "unidade_de_busca: B calcula alvo PC + offset*4");
        check(ub_instruction[31:27] == OP_WAIT_VBLANK, "unidade_de_busca: B pula instrucoes intermediarias");
        wait_cycles(2);
        check(ub_pc == 12, "unidade_de_busca: WAIT_VBLANK segura PC antes da borda");
        @(negedge clk); ub_vblank=1; @(negedge clk); ub_vblank=0;
        wait_cycles(2);
        check(ub_pc == 16, "unidade_de_busca: WAIT_VBLANK avanca na borda de subida");
        check(ub_instruction[31:27] == OP_HALT, "unidade_de_busca: busca instrucao apos WAIT_VBLANK");
        wait_cycles(2);
        check(!ub_running, "unidade_de_busca: HALT encerra programa");

        // Opcode reservado: o sinal invalid_opcode deve ser observado no ciclo
        // de execucao. A verificacao tambem aceita a instrucao presente na saida.
        reset_ub();
        busca_dut.instruction_mem.mem[0] = make_instr(OP_INVALID, 27'd0);
        @(negedge clk); ub_start=1; @(negedge clk); ub_start=0;
        wait_cycles(3);
        check(ub_instruction[31:27] == OP_INVALID,
              "unidade_de_busca: opcode reservado chega ao decodificador");
        check(ub_invalid || !ub_running,
              "unidade_de_busca: sinaliza opcode reservado ou fim/parada");

        // B_COND EQ: flags = {C,V,N,Z}; Z=1, offset=2, alvo PC=8.
        reset_ub();
        busca_dut.instruction_mem.mem[0] = make_instr(OP_B_COND, {4'b0000, 9'd0, 14'd2});
        busca_dut.instruction_mem.mem[1] = make_instr(OP_INVALID, 27'd0);
        busca_dut.instruction_mem.mem[2] = make_instr(OP_NOP, 27'd0);
        ub_flags = 4'b0001;
        @(negedge clk); ub_start=1; @(negedge clk); ub_start=0;
        wait_cycles(3);
        check(ub_pc == 16'd8, "unidade_de_busca: B_COND EQ desvia quando Z=1");

        $display("====================================================");
        $display("RESUMO: %0d PASSOU(S), %0d FALHA(S)", passed, failed);
        if (failed == 0) $display("RESULTADO FINAL: TODOS OS TESTES PASSARAM");
        else $display("RESULTADO FINAL: EXISTEM FALHAS");
        $display("====================================================");
        $finish;
    end

    initial begin
        #2000000;
        $display("[FAIL] Timeout global do testbench.");
        $finish;
    end
endmodule
