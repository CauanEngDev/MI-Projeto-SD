// ============================================================================
// CAMADA DE COMPOSICAO - PRIORIDADE ENTRE BACKGROUND, RASTERIZADORES E SPRITES
// ----------------------------------------------------------------------------
// Fica entre o engine_mux e o framebuffer. No caminho de busca ativa a ordem
// de desenho vem do programa (ordem das instrucoes DRAW_*), entao nada impedia
// um DRAW_BG ou um DRAW_RECT de apagar sprites ja desenhados. Esta camada
// devolve a garantia que o compositor sequencial dava por construcao:
//
//        camada 0 (atras)   background          (engine_sel = 1)
//        camada 1           rasterizadores      (engine_sel = 3)
//        camada 2 (frente)  sprites             (engine_sel = 2)
//
// Para cada pixel do banco de escrita, um mapa de camadas (2 bits por pixel)
// guarda a camada mais alta que ja escreveu naquele pixel no quadro atual.
// Uma escrita so chega ao framebuffer se
//
//        camada_da_escrita >= camada_registrada_no_pixel
//
// e, se passar, atualiza o mapa. Consequencias:
//   - escrita de camada inferior sobre camada superior e descartada;
//   - escrita da mesma camada sobrescreve (retangulo/triangulo desenhados
//     depois ficam por cima dos anteriores; um novo DRAW_BG ou DRAW_SPRITES
//     refaz a sua camada);
//   - a ordem das instrucoes DRAW_* deixa de importar entre camadas.
// A transparencia (indice 0) continua resolvida pelos motores: pixel
// transparente nao gera escrita, logo nao marca o mapa e nao esconde nada.
//
// Pipeline (latencia fixa de 2 ciclos entre a entrada e o framebuffer):
//   S0 (combinacional) escrita vinda do engine_mux; endereco enviado ao mapa
//   S1 (registrado)    tag lida do mapa, comparacao de camadas
//   S2 (registrado)    saida para o framebuffer e escrita da tag no mapa
// A camada e registrada junto com a escrita (nao depende de engine_sel nos
// estagios seguintes). Escritas em ciclos consecutivos no mesmo pixel sao
// tratadas por encaminhamento (forwarding) de S2 e S3, entao nao ha hazard
// de leitura-apos-escrita, independentemente da sequencia dos motores.
//
// Limpeza dos mapas (sem custo de tempo no programa):
//   - Cada banco do framebuffer tem o seu mapa. O mapa do banco que esta sendo
//     EXIBIDO nao e usado pelos motores, entao e zerado em varredura (76800
//     ciclos, ~1,5 ms) logo apos a troca de bancos. Quando esse banco volta a
//     ser o de escrita, o mapa ja esta limpo.
//   - Apos reset ou clear_all os dois mapas sao zerados e init_busy segura a
//     unidade de busca (ligue init_busy ao reset da busca); escritas nesse
//     periodo sao descartadas.
// ============================================================================

module camada_composicao (
    input  wire        clk,            // clock do sistema (50 MHz)
    input  wire        reset,          // reset sincrono (ativo em 1)
    input  wire        clear_all,      // pulso: zera os mapas dos dois bancos
                                       // (ex.: reinicio manual do programa)
    input  wire        wr_buf_sel,     // banco de escrita atual (como no top)

    input  wire [1:0]  engine_sel,     // 1: background, 2: sprite, 3: rasterizador

    // Escrita vinda do engine_mux
    input  wire        in_we,
    input  wire [8:0]  in_x,
    input  wire [7:0]  in_y,
    input  wire [8:0]  in_data,

    // Escrita filtrada, para o framebuffer
    output wire        fb_we,
    output wire [8:0]  fb_wr_x,
    output wire [7:0]  fb_wr_y,
    output wire [8:0]  fb_wr_data,

    output wire        init_busy,      // 1 enquanto os mapas sao zerados
    output wire        blocked         // pulso: escrita descartada por prioridade
);

    localparam [16:0] LAST = 17'd76799;   // 320 x 240 - 1

    // ------------------------------------------------------------------------
    // Camada de cada motor (0 = fundo, 1 = rasterizadores, 2 = sprites)
    // ------------------------------------------------------------------------
    function [1:0] camada_de;
        input [1:0] sel;
        begin
            case (sel)
                2'd2:    camada_de = 2'd2;
                2'd3:    camada_de = 2'd1;
                default: camada_de = 2'd0;
            endcase
        end
    endfunction

    // ------------------------------------------------------------------------
    // Varredura de limpeza
    // ------------------------------------------------------------------------
    reg        init_r     = 1'b1;
    reg        sweep_busy = 1'b0;
    reg [16:0] cnt        = 17'd0;
    reg        wr_sel_d   = 1'b1;

    assign init_busy = init_r;

    // O banco exibido e o que nao recebe escritas dos motores
    wire clr_bank = ~wr_buf_sel;

    always @(posedge clk) begin
        wr_sel_d <= wr_buf_sel;

        if (reset | clear_all) begin
            init_r     <= 1'b1;
            sweep_busy <= 1'b0;
            cnt        <= 17'd0;
        end
        else if (init_r) begin
            if (cnt == LAST) begin
                init_r <= 1'b0;
                cnt    <= 17'd0;
            end
            else cnt <= cnt + 17'd1;
        end
        else if (wr_buf_sel != wr_sel_d) begin
            // Troca de bancos: o banco que acabou de sair do modo escrita
            // passa a ser exibido; zera o mapa dele
            sweep_busy <= 1'b1;
            cnt        <= 17'd0;
        end
        else if (sweep_busy) begin
            if (cnt == LAST) sweep_busy <= 1'b0;
            else             cnt <= cnt + 17'd1;
        end
    end

    // ------------------------------------------------------------------------
    // S0: endereco linear do pixel (y * 320 + x), para a leitura do mapa
    // ------------------------------------------------------------------------
    wire [16:0] addr0;

    fb_addr_gen u_addr (
        .x    (in_x),
        .y    (in_y),
        .addr (addr0)
    );

    // ------------------------------------------------------------------------
    // S1: escrita registrada; o mapa devolve a tag neste ciclo
    // ------------------------------------------------------------------------
    reg         s1_we    = 1'b0;
    reg  [8:0]  s1_x, s1_data;
    reg  [7:0]  s1_y;
    reg  [16:0] s1_addr;
    reg  [1:0]  s1_layer;
    reg         s1_bank;

    always @(posedge clk) begin
        if (reset)
            s1_we <= 1'b0;
        else
            // durante a limpeza (e no ciclo do pulso clear_all) nada entra
            s1_we <= in_we & ~init_r & ~clear_all;

        s1_x     <= in_x;
        s1_y     <= in_y;
        s1_data  <= in_data;
        s1_addr  <= addr0;
        s1_layer <= camada_de(engine_sel);
        s1_bank  <= wr_buf_sel;
    end

    // ------------------------------------------------------------------------
    // S2 e S3: escritas ja aceitas (S3 e a copia de S2 um ciclo depois; serve
    // so ao encaminhamento, porque a tag de S2 so entra no mapa no fim do ciclo)
    // ------------------------------------------------------------------------
    reg         s2_we = 1'b0;
    reg  [8:0]  s2_x, s2_data;
    reg  [7:0]  s2_y;
    reg  [16:0] s2_addr;
    reg  [1:0]  s2_layer;
    reg         s2_bank;

    reg         s3_we = 1'b0;
    reg  [16:0] s3_addr;
    reg  [1:0]  s3_layer;
    reg         s3_bank;

    // Tags lidas dos mapas dos dois bancos (mesmo endereco; usa-se o do banco
    // de escrita da escrita em S1)
    wire [1:0] tag_q0, tag_q1;
    wire [1:0] tag_q = s1_bank ? tag_q1 : tag_q0;

    // Encaminhamento: escritas anteriores que ainda nao estao no que o mapa
    // devolveu (S2 e a mais recente, S3 a anterior)
    wire hit2 = s2_we & (s2_addr == s1_addr) & (s2_bank == s1_bank);
    wire hit3 = s3_we & (s3_addr == s1_addr) & (s3_bank == s1_bank);
    wire [1:0] tag_eff = hit2 ? s2_layer :
                         hit3 ? s3_layer : tag_q;

    wire allow = (s1_layer >= tag_eff);

    always @(posedge clk) begin
        if (reset) begin
            s2_we <= 1'b0;
            s3_we <= 1'b0;
        end
        else begin
            s2_we <= s1_we & allow & ~init_r;
            s3_we <= s2_we;
        end

        s2_x     <= s1_x;
        s2_y     <= s1_y;
        s2_data  <= s1_data;
        s2_addr  <= s1_addr;
        s2_layer <= s1_layer;
        s2_bank  <= s1_bank;

        s3_addr  <= s2_addr;
        s3_layer <= s2_layer;
        s3_bank  <= s2_bank;
    end

    assign fb_we      = s2_we;
    assign fb_wr_x    = s2_x;
    assign fb_wr_y    = s2_y;
    assign fb_wr_data = s2_data;

    assign blocked = s1_we & ~allow & ~init_r;

    // ------------------------------------------------------------------------
    // Mapas de camadas (um por banco). Cada mapa tem uma unica porta de
    // escrita, dividida entre a limpeza e a escrita da tag de S2; os dois
    // usos nunca coincidem no mesmo banco (a limpeza so atua no banco exibido,
    // ou nos dois durante init, quando S1/S2 estao bloqueados).
    // ------------------------------------------------------------------------
    wire clr_we0 = init_r | (sweep_busy & (clr_bank == 1'b0));
    wire clr_we1 = init_r | (sweep_busy & (clr_bank == 1'b1));

    wire eng_we0 = s2_we & (s2_bank == 1'b0);
    wire eng_we1 = s2_we & (s2_bank == 1'b1);

    mapa_camadas_ram u_mapa0 (
        .clk   (clk),
        .we    (clr_we0 | eng_we0),
        .waddr (clr_we0 ? cnt : s2_addr),
        .wdata (clr_we0 ? 2'b00 : s2_layer),
        .raddr (addr0),
        .q     (tag_q0)
    );

    mapa_camadas_ram u_mapa1 (
        .clk   (clk),
        .we    (clr_we1 | eng_we1),
        .waddr (clr_we1 ? cnt : s2_addr),
        .wdata (clr_we1 ? 2'b00 : s2_layer),
        .raddr (addr0),
        .q     (tag_q1)
    );

endmodule


// ============================================================================
// MAPA DE CAMADAS - RAM simples de 2 portas, 76800 x 2 bits, clock unico
// ----------------------------------------------------------------------------
// Inferida pelo Quartus em blocos M10K (cerca de 19 blocos por mapa). Leitura
// com 1 ciclo de latencia. O comportamento de leitura durante escrita no mesmo
// endereco e irrelevante: a camada_composicao encaminha as escritas recentes
// (hit2/hit3), por isso o "no_rw_check" evita logica de bypass desnecessaria.
// ============================================================================
module mapa_camadas_ram (
    input  wire        clk,
    input  wire        we,
    input  wire [16:0] waddr,
    input  wire [1:0]  wdata,
    input  wire [16:0] raddr,
    output reg  [1:0]  q
);

    (* ramstyle = "M10K, no_rw_check" *) reg [1:0] mem [0:76799];

    // Apenas para simulacao (evita X antes da varredura de init). O Quartus
    // limita lacos a 5000 iteracoes, e na placa o mapa e zerado pela varredura
    // de init da camada_composicao, entao o sintetizador ignora este bloco.
    // synthesis translate_off
    integer i;
    initial begin
        for (i = 0; i < 76800; i = i + 1)
            mem[i] = 2'b00;
        q = 2'b00;
    end
    // synthesis translate_on

    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
        q <= mem[raddr];
    end

endmodule
