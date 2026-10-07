// ============================================================================
// MOTOR DE SPRITES - VARREDURA POR PIXEL COM BUSCA PARALELA DE PRIORIDADE
// ----------------------------------------------------------------------------
// Baseado na implementacao sugerida (sprite_engine): os atributos dos 32
// sprites ficam em registradores e, para cada pixel da tela, todos os sprites
// sao testados em paralelo para descobrir quais cobrem aquele pixel. Entre os
// que cobrem, vence o de maior prioridade; em empate, o de maior indice.
//
// Diferencas em relacao a implementacao sugerida:
//   - Interface de comando: start / busy / done, e escrita direto no
//     framebuffer (somente pixels opacos de sprites).
//   - Layout de atributos do projeto: prioridade de 5 bits (0-31), padrao de 6
//     bits (64 padroes de 16x16, cada um com 4 tiles de 8x8), pattern RAM de
//     14 bits e paleta de 2 bancos.
//   - Transparencia correta entre sprites: se o pixel do sprite vencedor for
//     transparente (indice 0), ele e excluido (mascara "excluded") e o MESMO
//     pixel e reavaliado; assim um sprite de baixo continua visivel pelos
//     "buracos" do sprite de cima, como no algoritmo do pintor anterior.
//   - A prioridade e resolvida por uma arvore de comparadores dividida em dois
//     estados, para fechar timing em 50 MHz.
//   - Nao ha mais sprite_attribute_ram: a unidade de controle escreve direto
//     nos registradores do motor (spos_* e sattr_*). Cada instrucao grava so
//     o seu campo, sem read-modify-write.
//
// Tempo de varredura: 1 ciclo por pixel sem sprite; cerca de 10 ciclos por
// pixel coberto por um sprite (mais 6 por cada sprite transparente testado).
//
// Latencias supostas (iguais as do motor anterior):
//   - pattern RAM: dado valido 1 ciclo apos o endereco aparecer.
//   - palette RAM: dado valido no ciclo seguinte ao da escrita de
//     palette_rd_addr. Se a RAM exigir mais ciclos, use os parametros
//     PATTERN_EXTRA_WAIT e PALETTE_EXTRA_WAIT.
//
// Atributos:
//   spos_wr_data  = {pos_y[7:0], pos_x[8:0]}                          (SET_SPRITE_POS)
//   sattr_wr_data = {enable, priority[4:0], flip_v, flip_h, palette_sel,
//                    pattern[5:0]}                                    (SET_SPRITE_ATTR)
// ============================================================================

module motor_sprite #(
    parameter PATTERN_EXTRA_WAIT = 0, // ciclos extras de espera da pattern RAM
    parameter PALETTE_EXTRA_WAIT = 0  // ciclos extras de espera da palette RAM
) (
    input  wire        clk,
    input  wire        reset,

    // Escrita da posicao do sprite (SET_SPRITE_POS)
    input  wire        spos_we,
    input  wire [4:0]  spos_wr_addr,   // id do sprite
    input  wire [16:0] spos_wr_data,   // {pos_y[7:0], pos_x[8:0]}

    // Escrita dos demais atributos (SET_SPRITE_ATTR)
    input  wire        sattr_we,
    input  wire [4:0]  sattr_wr_addr,  // id do sprite
    input  wire [14:0] sattr_wr_data,  // {enable, priority, flip_v, flip_h,
                                       //  palette_sel, pattern[5:0]}

    // Leitura da sprite_pattern_ram
    output reg  [13:0] pattern_rd_addr,
    input  wire [7:0]  pattern_rd_data,

    // Leitura da palette_ram (2 paletas x 256 cores)
    output reg  [8:0]  palette_rd_addr,   // {palette_sel, color_index[7:0]}
    input  wire [8:0]  palette_rd_data,

    // Interface de escrita no framebuffer
    output reg         fb_we,
    output reg  [8:0]  fb_wr_x,
    output reg  [7:0]  fb_wr_y,
    output reg  [8:0]  fb_wr_data,

    input  wire        start,
    output wire        busy,
    output reg         done
);

    // ------------------------------------------------------------------------
    // Atributos dos 32 sprites, em registradores
    // ------------------------------------------------------------------------
    reg [8:0] spr_x       [0:31];
    reg [7:0] spr_y       [0:31];
    reg [5:0] spr_pattern [0:31];
    reg [4:0] spr_prio    [0:31];
    reg       spr_enable  [0:31];
    reg       spr_flip_h  [0:31];
    reg       spr_flip_v  [0:31];
    reg       spr_pal_sel [0:31];

    integer j;

    // Escrita dos atributos (uma instrucao por vez; nunca durante a varredura)
    always @(posedge clk) begin
        if (reset) begin
            for (j = 0; j < 32; j = j + 1) begin
                spr_x[j]       <= 9'd0;
                spr_y[j]       <= 8'd0;
                spr_pattern[j] <= 6'd0;
                spr_prio[j]    <= 5'd0;
                spr_enable[j]  <= 1'b0;
                spr_flip_h[j]  <= 1'b0;
                spr_flip_v[j]  <= 1'b0;
                spr_pal_sel[j] <= 1'b0;
            end
        end
        else begin
            if (spos_we) begin
                spr_x[spos_wr_addr] <= spos_wr_data[8:0];
                spr_y[spos_wr_addr] <= spos_wr_data[16:9];
            end
            if (sattr_we) begin
                spr_enable[sattr_wr_addr]  <= sattr_wr_data[14];
                spr_prio[sattr_wr_addr]    <= sattr_wr_data[13:9];
                spr_flip_v[sattr_wr_addr]  <= sattr_wr_data[8];
                spr_flip_h[sattr_wr_addr]  <= sattr_wr_data[7];
                spr_pal_sel[sattr_wr_addr] <= sattr_wr_data[6];
                spr_pattern[sattr_wr_addr] <= sattr_wr_data[5:0];
            end
        end
    end

    // ------------------------------------------------------------------------
    // Estado da varredura
    // ------------------------------------------------------------------------
    reg [8:0]  px;          // pixel atual (0..319)
    reg [7:0]  py;          // pixel atual (0..239)
    reg [31:0] excluded;    // sprites ja testados e transparentes neste pixel
    reg [31:0] cover_r;     // sprites que cobrem o pixel (registrado)
    reg [4:0]  best_id_r;   // sprite vencedor
    reg        pal_sel_r;   // paleta do sprite vencedor
    reg [2:0]  wait_cnt;    // contador das esperas extras

    // ------------------------------------------------------------------------
    // Cobertura: um bit por sprite (comparacoes em paralelo)
    //   cobre = habilitado, nao excluido e (px, py) dentro do quadrado 16x16
    // ------------------------------------------------------------------------
    wire [31:0] cover;

    genvar g;
    generate
        for (g = 0; g < 32; g = g + 1) begin : G_COVER
            wire [9:0] sx = {1'b0, spr_x[g]};
            wire [8:0] sy = {1'b0, spr_y[g]};
            wire [9:0] pxe = {1'b0, px};
            wire [8:0] pye = {1'b0, py};
            assign cover[g] = spr_enable[g] & ~excluded[g]
                            & (pxe >= sx) & (pxe < (sx + 10'd16))
                            & (pye >= sy) & (pye < (sy + 9'd16));
        end
    endgenerate

    // ------------------------------------------------------------------------
    // Resolucao de prioridade por arvore de maximo
    //   chave = {cobre, prioridade[4:0], id[4:0]}; maior chave vence. Como o id
    //   e unico, nao ha empate: maior prioridade e, em seguida, maior id.
    //   Niveis 1 a 3 no estado S_PRIO_A, niveis 4 e 5 no estado S_PRIO_B.
    // ------------------------------------------------------------------------
    wire [10:0] k0 [0:31];
    wire [10:0] k1 [0:15];
    wire [10:0] k2 [0:7];
    wire [10:0] k3 [0:3];

    generate
        for (g = 0; g < 32; g = g + 1) begin : G_K0
            localparam [4:0] ID = g;
            assign k0[g] = {cover_r[g], spr_prio[g], ID};
        end
        for (g = 0; g < 16; g = g + 1) begin : G_K1
            assign k1[g] = (k0[2*g] > k0[2*g+1]) ? k0[2*g] : k0[2*g+1];
        end
        for (g = 0; g < 8; g = g + 1) begin : G_K2
            assign k2[g] = (k1[2*g] > k1[2*g+1]) ? k1[2*g] : k1[2*g+1];
        end
        for (g = 0; g < 4; g = g + 1) begin : G_K3
            assign k3[g] = (k2[2*g] > k2[2*g+1]) ? k2[2*g] : k2[2*g+1];
        end
    endgenerate

    reg  [10:0] k3r [0:3];   // vencedores parciais registrados
    wire [10:0] k4_0 = (k3r[0] > k3r[1]) ? k3r[0] : k3r[1];
    wire [10:0] k4_1 = (k3r[2] > k3r[3]) ? k3r[2] : k3r[3];
    wire [10:0] k5   = (k4_0 > k4_1) ? k4_0 : k4_1;

    // ------------------------------------------------------------------------
    // Atributos do sprite vencedor e endereco na pattern RAM
    //   rel = posicao relativa dentro do sprite (4 bits bastam: o pixel ja foi
    //   confirmado dentro do quadrado). Espelhamento: 15 - r = ~r em 4 bits.
    //   quadrante = {sly[3], slx[3]}; tile_id = {pattern, quadrante};
    //   endereco = {tile_id, sub_y, sub_x}.
    // ------------------------------------------------------------------------
    wire [8:0] sel_x       = spr_x[best_id_r];
    wire [7:0] sel_y       = spr_y[best_id_r];
    wire [5:0] sel_pattern = spr_pattern[best_id_r];
    wire       sel_flip_h  = spr_flip_h[best_id_r];
    wire       sel_flip_v  = spr_flip_v[best_id_r];
    wire       sel_pal     = spr_pal_sel[best_id_r];

    wire [3:0] rel_x = px[3:0] - sel_x[3:0];
    wire [3:0] rel_y = py[3:0] - sel_y[3:0];
    wire [3:0] slx   = sel_flip_h ? ~rel_x : rel_x;
    wire [3:0] sly   = sel_flip_v ? ~rel_y : rel_y;
    wire [7:0] tile_id = {sel_pattern, sly[3], slx[3]};

    // ------------------------------------------------------------------------
    // Maquina de estados
    // ------------------------------------------------------------------------
    localparam [3:0] S_IDLE     = 4'd0,
                     S_COVER    = 4'd1,  // calcula cobertura do pixel
                     S_PRIO_A   = 4'd2,  // arvore de prioridade, niveis 1-3
                     S_PRIO_B   = 4'd3,  // arvore de prioridade, niveis 4-5
                     S_ADDR     = 4'd4,  // endereco na pattern RAM
                     S_PAT_WAIT = 4'd5,  // espera da pattern RAM
                     S_PAT_CHK  = 4'd6,  // transparente? senao, le paleta
                     S_PAL_WAIT = 4'd7,  // espera extra da palette RAM
                     S_WRITE    = 4'd8,  // escreve o pixel no framebuffer
                     S_DONE     = 4'd9;

    localparam [2:0] PAL_LAST = (PALETTE_EXTRA_WAIT == 0) ? 3'd0 : (PALETTE_EXTRA_WAIT - 1);

    reg [3:0] state;
    assign busy = (state != S_IDLE);

    // Passa ao proximo pixel (ou encerra a varredura apos o ultimo)
    task avancar_pixel;
        begin
            excluded <= 32'b0;
            if (px == 9'd319) begin
                px <= 9'd0;
                if (py == 8'd239) begin
                    py    <= 8'd0;
                    state <= S_DONE;
                end
                else begin
                    py    <= py + 8'd1;
                    state <= S_COVER;
                end
            end
            else begin
                px    <= px + 9'd1;
                state <= S_COVER;
            end
        end
    endtask

    always @(posedge clk) begin
        if (reset) begin
            state    <= S_IDLE;
            fb_we    <= 1'b0;
            done     <= 1'b0;
            px       <= 9'd0;
            py       <= 8'd0;
            excluded <= 32'b0;
            wait_cnt <= 3'd0;
        end
        else begin
            fb_we <= 1'b0;
            done  <= 1'b0;

            case (state)
                S_IDLE: if (start) begin
                    px       <= 9'd0;
                    py       <= 8'd0;
                    excluded <= 32'b0;
                    state    <= S_COVER;
                end

                // Nenhum sprite cobre o pixel: segue em 1 ciclo
                S_COVER: begin
                    if (cover == 32'b0) begin
                        avancar_pixel;
                    end
                    else begin
                        cover_r <= cover;
                        state   <= S_PRIO_A;
                    end
                end

                S_PRIO_A: begin
                    k3r[0] <= k3[0];
                    k3r[1] <= k3[1];
                    k3r[2] <= k3[2];
                    k3r[3] <= k3[3];
                    state  <= S_PRIO_B;
                end

                S_PRIO_B: begin
                    best_id_r <= k5[4:0];
                    state     <= S_ADDR;
                end

                S_ADDR: begin
                    pattern_rd_addr <= {tile_id, sly[2:0], slx[2:0]};
                    pal_sel_r       <= sel_pal;
                    wait_cnt        <= 3'd0;
                    state           <= S_PAT_WAIT;
                end

                S_PAT_WAIT: begin
                    if (wait_cnt >= PATTERN_EXTRA_WAIT) begin
                        wait_cnt <= 3'd0;
                        state    <= S_PAT_CHK;
                    end
                    else begin
                        wait_cnt <= wait_cnt + 3'd1;
                    end
                end

                S_PAT_CHK: begin
                    if (pattern_rd_data == 8'd0) begin
                        // Indice 0 = transparente: exclui este sprite e
                        // reavalia o mesmo pixel
                        excluded[best_id_r] <= 1'b1;
                        state               <= S_COVER;
                    end
                    else begin
                        palette_rd_addr <= {pal_sel_r, pattern_rd_data};
                        wait_cnt        <= 3'd0;
                        state           <= (PALETTE_EXTRA_WAIT == 0) ? S_WRITE : S_PAL_WAIT;
                    end
                end

                S_PAL_WAIT: begin
                    if (wait_cnt >= PAL_LAST) begin
                        wait_cnt <= 3'd0;
                        state    <= S_WRITE;
                    end
                    else begin
                        wait_cnt <= wait_cnt + 3'd1;
                    end
                end

                S_WRITE: begin
                    fb_we      <= 1'b1;
                    fb_wr_x    <= px;
                    fb_wr_y    <= py;
                    fb_wr_data <= palette_rd_data;
                    avancar_pixel;
                end

                S_DONE: begin
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule