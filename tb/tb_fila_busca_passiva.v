`timescale 1ns/1ps
// Integracao: writer (HPS) -> fila_comandos real -> unidade_de_busca_passiva real
module tb_fila_busca_passiva;
  reg clk=0, reset=1; always #5 clk=~clk;
  // writer
  reg wr_en=0; reg [31:0] wr_data=0; wire full, empty; wire [31:0] fifo_q; wire fifo_rd;
  fila_comandos #(.LARGURA(32), .PROFUNDIDADE(64)) fila(.clk(clk),.reset(reset),.wr_en(wr_en),.wr_data(wr_data),
      .full(full),.rd_en(fifo_rd),.rd_data(fifo_q),.empty(empty));
  // busca
  reg vblank=0, engine_done=0;
  wire [31:0] instruction; wire execute, frame_swap, running, waiting, invalid_opcode; wire [15:0] pc;
  unidade_de_busca_passiva busca(.clk(clk),.reset(reset),.start(1'b0),.engine_done(engine_done),.vblank(vblank),
      .flags(4'b0),.fifo_empty(empty),.fifo_q(fifo_q),.fifo_rd(fifo_rd),.pc(pc),.instruction(instruction),
      .execute(execute),.frame_swap(frame_swap),.running(running),.waiting(waiting),.invalid_opcode(invalid_opcode));
  // vblank a cada 600 ciclos, 10 ciclos de duracao
  integer cyc=0; always @(posedge clk) begin cyc<=cyc+1; vblank <= ((cyc%600)>=590); end
  // motor falso: engine_done 5 ciclos apos o execute de um DRAW_*
  integer ecnt=0; reg ebusy=0;
  wire blocking = (instruction[31:27]==5'b01000)||(instruction[31:27]==5'b01001)||(instruction[31:27]==5'b10000)||(instruction[31:27]==5'b10001);
  always @(posedge clk) begin
    engine_done<=0;
    if (execute && blocking) begin ebusy<=1; ecnt<=5; end
    else if (ebusy) begin ecnt<=ecnt-1; if (ecnt==1) begin engine_done<=1; ebusy<=0; end end
  end
  // programa: 2 quadros, maiores que a fila (64) para exercitar "cheia"
  localparam N = 300;
  reg [4:0] prog [0:N-1]; integer total=0, sent=0, i, halts=0;
  initial begin
    // quadro 1: 120 PASS, DRAW_RECT, 20 PASS, DRAW_TRI, HALT
    for (i=0;i<120;i=i+1) begin prog[total]=5'b00110; total=total+1; end
    prog[total]=5'b01000; total=total+1;
    for (i=0;i<20;i=i+1) begin prog[total]=5'b00111; total=total+1; end
    prog[total]=5'b01001; total=total+1;
    prog[total]=5'b10011; total=total+1; halts=halts+1;
    // quadro 2: 80 PASS, B (invalido), DRAW_BG, WAIT_VBLANK, DRAW_SPRITES, HALT
    for (i=0;i<80;i=i+1) begin prog[total]=5'b00110; total=total+1; end
    prog[total]=5'b10100; total=total+1;
    prog[total]=5'b10000; total=total+1;
    prog[total]=5'b10010; total=total+1;
    prog[total]=5'b10001; total=total+1;
    prog[total]=5'b10011; total=total+1; halts=halts+1;
  end
  // writer: 60% de chance por ciclo, respeitando full
  integer stalls=0;
  always @(negedge clk) if (!reset) begin
    wr_en <= 0;
    if (sent < total) begin
      if (full) begin if ($urandom_range(0,99)<60) stalls<=stalls+1; end
      else if ($urandom_range(0,99) < 60) begin wr_en<=1; wr_data<={prog[sent],27'd0}; sent<=sent+1; end
    end
  end
  // monitores
  integer n_exec=0, n_inv=0, n_swap=0, bad_order=0, exec_when_empty=0;
  always @(posedge clk) if (!reset) begin
    if (execute) begin
      if (instruction[31:27] !== prog[n_exec]) bad_order<=bad_order+1;
      if (empty) exec_when_empty<=exec_when_empty+1;
      n_exec<=n_exec+1;
    end
    if (invalid_opcode) n_inv<=n_inv+1;
    if (frame_swap) n_swap<=n_swap+1;
  end
  integer fails=0;
  task check(input ok, input [8*70-1:0] msg); begin if (ok) $display("PASSOU : %0s",msg); else begin $display("FALHOU : %0s",msg); fails=fails+1; end end endtask
  initial begin
    repeat(4) @(negedge clk); reset=0;
    repeat(2500) @(negedge clk);
    check(sent==total, "o writer enviou o programa inteiro");
    check(stalls>0, "a fila chegou a encher (writer segurou por 'full')");
    check(n_exec==total, "um execute por palavra, nenhuma perdida ou repetida");
    check(bad_order==0, "as instrucoes executaram na ordem em que foram escritas");
    check(exec_when_empty==0, "nunca executou com a fila vazia");
    check(n_swap==halts, "frame_swap pulsou uma vez por HALT");
    check(n_inv==1, "o desvio B foi sinalizado como invalid_opcode (1 pulso)");
    check(empty===1 && running===1, "ao fim: fila vazia e busca nao travada");
    $display("palavras=%0d execute=%0d swaps=%0d invalidos=%0d ciclos_com_writer_bloqueado=%0d", total,n_exec,n_swap,n_inv,stalls);
    if (fails==0) $display("TUDO OK"); else $display("%0d FALHA(S)",fails); $finish;
  end
endmodule
