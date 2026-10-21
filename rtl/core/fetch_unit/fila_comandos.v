// ============================================================================
// FILA DE COMANDOS (FIFO) - COPROCESSADOR GRAFICO
// ----------------------------------------------------------------------------
// O que e: uma fila "primeiro a entrar, primeiro a sair" (FIFO). Quem escreve
// (o HPS, via MMIO) e quem le (a unidade de busca passiva) trabalham em ritmos
// diferentes; a fila guarda as instrucoes de 32 bits no meio do caminho.
//
//     HPS --(wr_en, wr_data)--> [ fila_comandos ] --(rd_data, empty)--> busca
//                                  full <--                  <-- rd_en
//
// Como funciona: uma memoria circular de PROFUNDIDADE palavras e dois
// ponteiros, que andam sempre para frente e "dao a volta" no fim da memoria:
//   - wr_ptr: onde a PROXIMA palavra sera gravada.
//   - rd_ptr: onde esta a palavra MAIS ANTIGA (a que sai primeiro).
// Um contador (count) diz quantas palavras estao na fila. Ele existe porque
// os ponteiros sozinhos nao distinguem "fila vazia" de "fila cheia": nos dois
// casos wr_ptr == rd_ptr.
//
// Leitura "show-ahead": rd_data mostra a palavra mais antiga o tempo todo,
// sem precisar pedir (rd_en). rd_en so serve para DESCARTAR essa palavra
// (pop). A unidade de busca depende disso: assim que empty cai para 0, a
// instrucao ja esta em rd_data.
//
// Regras de protecao (o que a fila NAO faz):
//   - Escrever com a fila cheia: ignorado (nao sobrescreve nada).
//   - Ler (pop) com a fila vazia: ignorado (o ponteiro nao anda).
//   - Ler e escrever no mesmo ciclo: os dois acontecem e count nao muda.
//
// Parametros:
//   LARGURA      largura da palavra (32 = uma instrucao da ISA).
//   PROFUNDIDADE numero de palavras. Precisa ser POTENCIA DE 2: so assim os
//                ponteiros, que tem exatamente log2(PROFUNDIDADE) bits, dao a
//                volta sozinhos ao estourar.
// ============================================================================

module fila_comandos #(
    parameter LARGURA      = 32,
    parameter PROFUNDIDADE = 64          // potencia de 2
) (
    input  wire                clk,
    input  wire                reset,    // sincrono; limpa a fila
    // escrita (lado do HPS / MMIO)
    input  wire                wr_en,    // 1 = quer gravar wr_data
    input  wire [LARGURA-1:0]  wr_data,  // palavra a gravar
    output wire                full,     // 1 = fila cheia (escrita e ignorada)
    // leitura (lado da unidade de busca)
    input  wire                rd_en,    // = fifo_rd: 1 = descarta a palavra mais
                                         //   antiga (pop)
    output wire [LARGURA-1:0]  rd_data,  // = fifo_q: palavra mais antiga (so vale
                                         //   quando empty = 0)
    output wire                empty     // = fifo_empty: 1 = fila vazia
);

// ----------------------------------------------------------------------------
// Memoria e ponteiro de escrita
// ----------------------------------------------------------------------------
reg [LARGURA-1:0]              mem [0:PROFUNDIDADE-1];  // armazenamento circular
reg [$clog2(PROFUNDIDADE)-1:0] wr_ptr;                  // proxima posicao livre

// A escrita so acontece se a fila NAO estiver cheia. Sem o "& ~full", uma
// escrita com a fila cheia sobrescreveria a instrucao mais antiga em silencio
// e o programa rodaria errado sem nenhum aviso.
wire pode_escrever = wr_en & ~full;

// ponteiro de escrita: precisa de reset
always @(posedge clk) begin
    if (reset)                wr_ptr <= 0;
    else if (pode_escrever)   wr_ptr <= wr_ptr + 1'b1;   // da a volta sozinho
end

// memória: sem reset
// (de proposito: resetar uma memoria obriga o Quartus a gastar um registrador
//  por bit. Nao precisa: empty/count garantem que ninguem le posicao que nao
//  foi escrita. Na simulacao, rd_data fica X enquanto a fila esta vazia.)
always @(posedge clk) begin
    if (pode_escrever)        mem[wr_ptr] <= wr_data;
end

// ----------------------------------------------------------------------------
// Ponteiro de leitura e saida show-ahead
// ----------------------------------------------------------------------------
reg [$clog2(PROFUNDIDADE)-1:0] rd_ptr;                  // palavra mais antiga

// O pop so acontece se houver algo na fila. Sem o "& ~empty", um rd_en com a
// fila vazia faria rd_ptr passar do wr_ptr e a fila ficaria com lixo.
wire pode_ler = rd_en & ~empty;

// Leitura combinacional (sem clock): mostra sempre a palavra da cabeca.
assign rd_data = mem[rd_ptr];

// ponteiro de leitura: precisa de reset
always @(posedge clk) begin
    if (reset)                rd_ptr <= 0;
    else if (pode_ler)        rd_ptr <= rd_ptr + 1'b1;   // descarta e vai p/ a proxima
end

// ----------------------------------------------------------------------------
// Contador de ocupacao
// ----------------------------------------------------------------------------
// Um bit a mais que os ponteiros: e preciso conseguir representar
// PROFUNDIDADE (fila cheia), que nao cabe em log2(PROFUNDIDADE) bits.
reg [$clog2(PROFUNDIDADE):0] count;

// Tabela do contador:
//   escreve  le   count
//      1      0    +1
//      0      1    -1
//      1      1    igual (entra uma e sai uma)
//      0      0    igual
always @(posedge clk) begin
    if (reset)                count <= 0;
    else if (pode_escrever & ~pode_ler) count <= count + 1'b1;
    else if (~pode_escrever & pode_ler) count <= count - 1'b1;
end

// count e um REGISTRADOR (valor guardado entre ciclos). Por isso full/empty
// nao formam um laco combinacional com pode_escrever/pode_ler.
assign full  = (count == PROFUNDIDADE);
assign empty = (count == 0);

endmodule