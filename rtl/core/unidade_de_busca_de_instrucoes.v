// ============================================================================
// INSTRUCTION FETCH - COPROCESSADOR GRAFICO
// ----------------------------------------------------------------------------
// Busca ativa: a unidade mantem o PC e o endereco da memoria por conta propria
// e apresenta a instrucao corrente a cada ciclo. O PC (em bytes, PC + 4) so
// avanca quando a instrucao corrente termina.
//
// Politica de execucao (sem instrucoes de desvio):
//   - Instrucoes de um ciclo (ULA, SET_*, WRITE_*, SCROLL_BG, NOP):
//       executam no primeiro ciclo valido e o PC avanca no mesmo ciclo.
//   - Bloqueantes por DONE (DRAW_RECT, DRAW_TRI, CLEAR_FB, DRAW_BG,
//     DRAW_SPRITES, SWAP_BUFFERS):
//       um pulso "execute" dispara o motor e o PC espera engine_done.
//   - WAIT_VBLANK: o PC espera a proxima borda de subida de vblank.
//   - HALT: para a busca. Retoma com o pulso "start" ou com reset.
//   - Opcodes reservados (10110 a 11111): tratados como NOP e sinalizados.
//
// ============================================================================

module unidade_de_busca_de_instrucoes #(
    parameter LAT_MEM      = 2, // latencia de leitura da instruction_memory:
                                //   2 = com registrador de saida em q (como gerada)
                                //   1 = sem registrador de saida
    parameter INICIAR_AUTO = 1  // 1: executa logo apos o reset
                                // 0: espera o pulso "start"
) (
    input  wire        clk,            // clock do sistema
    input  wire        reset,          // reset sincrono (ativo em 1)

    // Controle externo
    input  wire        start,          // pulso: volta o PC a 0 e inicia
                                       // (ex.: start_frame do CTRL)

    // Handshake com os motores e com o VGA
    input  wire        engine_done,    // fim da operacao do motor atual
                                       // (OR dos done dos motores)
    input  wire        vblank,         // 1 durante o apagamento vertical

    // Carga do programa na memoria (so aceita com a busca parada)
    input  wire        load_we,        // escreve load_data em load_addr
    input  wire [13:0] load_addr,      // endereco da palavra
    input  wire [31:0] load_data,      // instrucao a gravar

    // Saidas para o decodificador e para o banco de registradores
    output wire [15:0] pc,             // contador de programa (em bytes)
    output wire [31:0] instruction,    // instrucao corrente
    output wire        execute,        // pulso de 1 ciclo: lancar a instrucao

    // Status
    output wire        running,        // 1 enquanto o programa roda
    output wire        waiting,        // 1 enquanto o PC espera um evento
    output wire        invalid_opcode  // pulso: opcode reservado executado
);

    // ------------------------------------------------------------------------
    // Opcodes que a unidade de busca precisa reconhecer. Os demais opcodes
    // validos executam em um ciclo e o PC avanca.
    // ------------------------------------------------------------------------
    localparam [4:0] OP_DRAW_RECT    = 5'b01000;
    localparam [4:0] OP_DRAW_TRI     = 5'b01001;
    localparam [4:0] OP_CLEAR_FB     = 5'b10000;
    localparam [4:0] OP_DRAW_BG      = 5'b10001;
    localparam [4:0] OP_DRAW_SPRITES = 5'b10010;
    localparam [4:0] OP_SWAP_BUFFERS = 5'b10011;
    localparam [4:0] OP_WAIT_VBLANK  = 5'b10100;
    localparam [4:0] OP_HALT         = 5'b10101; // ultimo opcode valido

    // ------------------------------------------------------------------------
    // Estado interno
    // ------------------------------------------------------------------------
    reg halted;    // 1 = busca parada (HALT, fim da memoria ou aguardando start)
    reg issued;    // 1 = a instrucao corrente ja foi lancada e esta em espera
    reg vblank_d;  // vblank atrasado 1 ciclo, para detectar a borda
    reg bubble;    // 1 = saida da memoria ainda nao corresponde ao PC atual

    // ------------------------------------------------------------------------
    // Classificacao da instrucao corrente pelo opcode (bits 31:27)
    // ------------------------------------------------------------------------
    wire [4:0] opcode = instruction[31:27];

    // Instrucoes que seguram o PC ate engine_done
    wire is_blocking = (opcode == OP_DRAW_RECT)    ||
                       (opcode == OP_DRAW_TRI)     ||
                       (opcode == OP_CLEAR_FB)     ||
                       (opcode == OP_DRAW_BG)      ||
                       (opcode == OP_DRAW_SPRITES) ||
                       (opcode == OP_SWAP_BUFFERS);

    wire is_wait_vblank = (opcode == OP_WAIT_VBLANK); // espera borda de vblank
    wire is_halt        = (opcode == OP_HALT);        // para a busca
    wire is_invalid     = (opcode >  OP_HALT);        // opcode reservado

    // ------------------------------------------------------------------------
    // Borda de subida de vblank (inicio do apagamento vertical)
    // ------------------------------------------------------------------------
    wire vblank_rise = vblank & ~vblank_d;

    // ------------------------------------------------------------------------
    // Pulso de execucao
    // "active" bloqueia a execucao durante reset, durante o pulso start (a
    // saida da memoria ainda e a instrucao antiga), enquanto a busca esta
    // parada e durante a bolha de latencia da memoria. O pulso sai uma unica
    // vez por instrucao, no primeiro ciclo valido (issued = 0).
    // ------------------------------------------------------------------------
    wire active = ~halted & ~reset & ~start & ~bubble;
    assign execute = active & ~issued;

    // ------------------------------------------------------------------------
    // Conclusao da instrucao corrente (condicao para o PC avancar)
    //   - bloqueante: apos lancada (issued) e com engine_done = 1
    //   - WAIT_VBLANK: na borda de subida de vblank
    //   - HALT: nunca avanca
    //   - demais: conclui no proprio ciclo de execucao
    // ------------------------------------------------------------------------
    wire finished = is_blocking   ? (issued & engine_done) :
                    is_wait_vblank ? vblank_rise            :
                    is_halt        ? 1'b0                   :
                                     execute;

    wire advance = active & finished;

    // ------------------------------------------------------------------------
    // Proximo PC (em bytes)
    //   - reset ou start: volta a 0
    //   - advance: PC + 4, exceto na ultima palavra (nao da a volta; o
    //     programa termina e a busca para)
    //   - caso contrario: mantem (stall)
    // ------------------------------------------------------------------------
    wire [15:0] pc_plus4;
    wire        last_word = &pc[15:2]; // PC na ultima palavra da memoria
    wire [15:0] pc_next = (reset | start)         ? 16'd0   :
                          (advance & ~last_word)  ? pc_plus4 :
                                                    pc;

    // Program Counter (modulo original)
    Program_counter pc_register(
        .clk(clk),
        .reset(reset),
        .in(pc_next),
        .out(pc)
    );

    // PC + 4 (modulo original)
    Adder pc_adder(
        .a(pc),
        .b(16'd4),
        .out(pc_plus4)
    );

    // ------------------------------------------------------------------------
    // Memoria de instrucoes (modulo original, 16384 x 32 bits)
    // O endereco enviado e o do PROXIMO PC: a memoria registra o endereco
    // na mesma borda em que o PC e atualizado, o que elimina uma bolha de
    // latencia. Carga do programa so e aceita com a busca parada.
    // ------------------------------------------------------------------------
    wire        load_ok = load_we & halted;
    wire [13:0] fetch_address = pc_next[15:2]; // bytes -> indice da palavra

    instruction_memory instruction_mem(
        .address(load_ok ? load_addr : fetch_address),
        .clock(clk),
        .data(load_data),
        .wren(load_ok),
        .q(instruction)
    );

    // ------------------------------------------------------------------------
    // Bolha de latencia
    // Com LAT_MEM = 2 (q registrado), apos cada mudanca de PC a instrucao
    // correta so aparece em q um ciclo depois. Esse ciclo e marcado como
    // bolha e nada executa nele. Com LAT_MEM = 1 nao ha bolha.
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset | start | advance)
            bubble <= (LAT_MEM == 2);
        else
            bubble <= 1'b0;
    end

    // ------------------------------------------------------------------------
    // Registradores de estado (halted, issued, vblank_d)
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        vblank_d <= vblank;

        if (reset) begin
            issued <= 1'b0;
            halted <= (INICIAR_AUTO == 0);
        end
        else if (start) begin
            issued <= 1'b0;
            halted <= 1'b0;
        end
        else begin
            // Ao avancar, a proxima instrucao ainda nao foi lancada. Ao lancar
            // uma instrucao que fica em espera, marca-se como issued.
            if (advance)
                issued <= 1'b0;
            else if (execute)
                issued <= 1'b1;

            // HALT e fim da memoria param a busca
            if (execute & is_halt)
                halted <= 1'b1;
            if (advance & last_word)
                halted <= 1'b1;
        end
    end

    // ------------------------------------------------------------------------
    // Saidas de status
    // ------------------------------------------------------------------------
    assign running        = ~halted;
    assign waiting        = issued & ~halted;
    assign invalid_opcode = execute & is_invalid;

endmodule