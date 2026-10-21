`timescale 1ns/1ps
module tb_unidade_de_busca_passiva;
  reg clk=0, reset=1; always #5 clk=~clk;
  reg vblank=0; reg engine_done=0;
  // FIFO comportamental show-ahead
  reg [31:0] mem [0:63]; integer wp=0, rp=0, cnt=0;
  wire fifo_empty = (cnt==0);
  wire [31:0] fifo_q = mem[rp];
  wire fifo_rd; wire [31:0] instruction; wire execute, frame_swap, running, waiting, invalid_opcode; wire [15:0] pc;
  unidade_de_busca_passiva dut(.clk(clk),.reset(reset),.start(1'b0),.engine_done(engine_done),.vblank(vblank),
    .flags(4'b0),.fifo_empty(fifo_empty),.fifo_q(fifo_q),.fifo_rd(fifo_rd),.pc(pc),.instruction(instruction),
    .execute(execute),.frame_swap(frame_swap),.running(running),.waiting(waiting),.invalid_opcode(invalid_opcode));
  always @(posedge clk) if (fifo_rd && cnt>0) begin rp<=rp+1; cnt<=cnt-1; end
  task push(input [4:0] op); begin mem[wp]={op,27'd0}; wp=wp+1; cnt=cnt+1; end endtask
  // vblank: sobe a cada 120 ciclos, fica 10 ciclos
  integer cyc=0; always @(posedge clk) begin cyc<=cyc+1; vblank <= ((cyc%120)>=110); end
  // motor falso: engine_done 5 ciclos apos o execute de um DRAW_*
  integer ecnt=0; reg ebusy=0;
  wire blocking = (instruction[31:27]==5'b01000)||(instruction[31:27]==5'b01001)||(instruction[31:27]==5'b10000)||(instruction[31:27]==5'b10001);
  always @(posedge clk) begin
    engine_done<=0;
    if (execute && blocking) begin ebusy<=1; ecnt<=5; end
    else if (ebusy) begin ecnt<=ecnt-1; if (ecnt==1) begin engine_done<=1; ebusy<=0; end end
  end
  // monitores
  integer n_exec=0, n_inv=0, n_swap=0, t_swap1=0, t_rect_exec=0, t_rect_adv=0, exec_while_halted=0;
  reg halt_pending=0; integer order[0:31]; integer k=0;
  always @(posedge clk) if (!reset) begin
    if (execute) begin
      n_exec<=n_exec+1; order[k]=instruction[31:27]; k=k+1;
      if (halt_pending) exec_while_halted<=exec_while_halted+1;
      if (instruction[31:27]==5'b10011) halt_pending<=1;
      if (instruction[31:27]==5'b01000) t_rect_exec<=cyc;
    end
    if (fifo_rd && instruction[31:27]==5'b01000) t_rect_adv<=cyc;
    if (invalid_opcode) n_inv<=n_inv+1;
    if (frame_swap) begin n_swap<=n_swap+1; halt_pending<=0; if (t_swap1==0) t_swap1<=cyc; end
  end
  integer i, fails=0;
  task check(input ok, input [511:0] msg); begin if (ok) $display("PASSOU : %0s",msg); else begin $display("FALHOU : %0s",msg); fails=fails+1; end end endtask
  initial begin
    // quadro 1: PASS, PASS, DRAW_RECT, DRAW_TRI, HALT   | quadro 2: NOP, B(invalido), DRAW_BG, HALT
    push(5'b00110); push(5'b00110); push(5'b01000); push(5'b01001); push(5'b10011);
    push(5'b00000); push(5'b10100); push(5'b10000); push(5'b10011);
    repeat(4) @(posedge clk); reset=0;
    repeat(300) @(posedge clk);
    check(n_exec==9, "1) um pulso de execute por palavra (9 palavras)");
    check((t_rect_adv - t_rect_exec) >= 5, "2) DRAW_* segura a busca ate o engine_done (>=5 ciclos)");
    check(exec_while_halted==0, "3a) nenhum execute entre o HALT e o frame_swap");
    check(n_swap==2, "3b) frame_swap pulsa uma vez por HALT (2 no total)");
    check(n_inv==1, "4a) B gera invalid_opcode (1 pulso)");
    check(order[7]==5'b10000 && order[8]==5'b10011, "4b) a busca segue depois do B: DRAW_BG e HALT executam");
    check(cnt==0, "5) fila totalmente consumida (o 2o HALT e descartado no ultimo vblank)");
    $display("execute=%0d invalid=%0d swaps=%0d 1o_swap_no_ciclo=%0d", n_exec,n_inv,n_swap,t_swap1);
    if (fails==0) $display("TUDO OK"); $finish;
  end
endmodule
