// ============================================================================
// UNIDADE DE CONTROLE - COPROCESSADOR GRAFICO
// ----------------------------------------------------------------------------
// Puramente combinacional. Recebe a instrucao corrente e o pulso "execute" da
// instruction_fetch e traduz em sinais de controle:
//   1. Caminho da ULA (valid, op, operando b, write-back, flags).
//   2. Escrita nas memorias de conteudo (paleta, tilemap, padroes de tile e de
//      sprite, posicao e atributos de sprite) e no scroll do background.
//   3. Disparo dos motores de desenho e parametros do rasterizador.
//   4. Seletor do motor ativo e retorno de "engine_done" para a busca.
//
// Todas as acoes saem sincronizadas com "execute" (um unico ciclo por
// instrucao), de modo que cada escrita ou disparo acontece uma unica vez.
// Sem HPS, esta unidade e a unica escritora das memorias: nao ha arbitragem.
//
// Requisito da ULA: os codigos de operacao da alu.v devem estar alinhados aos
// opcodes da ISA (ADD=3'b001, SUB=3'b010, AND=3'b011, LSL=3'b100, LSR=3'b101,
// PASS=3'b110), pois alu_op = opcode[2:0].
//
// Conteudo dos registradores, conforme a ISA (isa_coprocessador_grafico.txt):
//   formato G: reg_a = valor de Ra, reg_b = valor de Rb
//   formato A: reg_a = valor de Rn, reg_b = valor de Rm
//   args = R7..R0 concatenados (R0 = args[31:0])
//
// O modulo engine_mux, no fim do arquivo, seleciona os sinais compartilhados
// (leitura da paleta e escrita no framebuffer) conforme o motor ativo.
// ============================================================================

// ------------------------------------------------------------------------
// Opcodes que a unidade de controle precisa reconhecer.
// ------------------------------------------------------------------------
`include "rtl/include/isa.vh"

module unidade_de_controle (
    // ---- Da unidade de busca ----
    input  wire [31:0]  instruction,       // instrucao corrente
    input  wire         execute,           // pulso de 1 ciclo por instrucao

    // ---- Do banco de registradores ----
    input  wire [31:0]  reg_a,             // Rn (formato A) ou Ra (formato G)
    input  wire [31:0]  reg_b,             // Rm (formato A) ou Rb (formato G)
    input  wire [255:0] args,              // R7..R0

    // ---- Caminho da ULA ----
    output wire         alu_valid,         // habilita a ULA
    output wire [2:0]   alu_op,            // operacao da ULA
    output wire [31:0]  alu_b,             // segundo operando (Rm ou imm12)
    output wire [4:0]   alu_shamt,         // quantidade de deslocamento
    input  wire         alu_done,          // done da ULA
    output wire         rf_write_enable,   // write_enable do banco (Rd)
    output wire         flags_we,          // captura de z e n no FLAGS

    // ---- Escrita na palette_ram (512 x 9) ----
    output wire         pal_we,
    output wire [8:0]   pal_wr_addr,
    output wire [8:0]   pal_wr_data,

    // ---- Escrita na bg_tile_ram (1200 x 8) ----
    output wire         tile_we,
    output wire [10:0]  tile_wr_addr,
    output wire [7:0]   tile_wr_data,

    // ---- Escrita na tile_pattern_ram (16384 x 8) ----
    output wire         tpat_we,
    output wire [13:0]  tpat_wr_addr,
    output wire [7:0]   tpat_wr_data,

    // ---- Escrita na sprite_pattern_ram (16384 x 8) ----
    output wire         spat_we,
    output wire [13:0]  spat_wr_addr,
    output wire [7:0]   spat_wr_data,

    // ---- Escrita da posicao dos sprites (registradores do motor_sprite) ----
    output wire         spos_we,
    output wire [4:0]   spos_wr_addr,
    output wire [16:0]  spos_wr_data,      // {pos_y[7:0], pos_x[8:0]}

    // ---- Escrita dos atributos dos sprites (registradores do motor_sprite) ----
    output wire         sattr_we,
    output wire [4:0]   sattr_wr_addr,
    output wire [14:0]  sattr_wr_data,     // {enable, priority[4:0], flip_v,
                                           //  flip_h, palette_sel, pattern[5:0]}

    // ---- Scroll do background (motor_background) ----
    output wire         scroll_wr_en,
    output wire         scroll_sel,        // 0: horizontal (X), 1: vertical (Y)
    output wire [8:0]   scroll_wr_data,
    output wire         scroll_auto_en,    // auto-scroll desligado
    output wire         scroll_auto_axis,
    output wire         scroll_auto_dir,
    output wire [7:0]   scroll_auto_step,

    // ---- Disparo dos motores ----
    output wire         start_bg,
    output wire         start_sprite,
    output wire         start_square,
    output wire         start_triangle,

    // ---- Parametros do rasterizador ----
    output wire [8:0]   rast_v0x,
    output wire [7:0]   rast_v0y,
    output wire [8:0]   rast_v1x,
    output wire [7:0]   rast_v1y,
    output wire [8:0]   rast_v2x,
    output wire [7:0]   rast_v2y,
    output wire [7:0]   rast_color,
    output wire         rast_palette,

    // ---- Fim das operacoes dos motores ----
    input  wire         done_bg,
    input  wire         done_sprite,
    input  wire         done_raster,
    input  wire         raster_invalid,    // rasterizador rejeitou o comando

    // ---- Para a busca e para o mux dos motores ----
    output wire [1:0]   engine_sel,        // 0: nenhum, 1: background,
                                           // 2: sprite, 3: rasterizador
    output wire         engine_done,       // fim do motor ativo
    output wire         cmd_error          // pulso: comando rejeitado
);

    // ------------------------------------------------------------------------
    // Campos da instrucao
    //   opcode = [31:27]; bit I (formato A) = [26]; imm12 = [11:0]
    // ------------------------------------------------------------------------
    wire [4:0]  opcode = instruction[31:27];
    wire        i_bit  = instruction[26];
    wire [11:0] imm12  = instruction[11:0];

    // ------------------------------------------------------------------------
    // Decodificacao do opcode (um sinal por instrucao)
    // ------------------------------------------------------------------------
    wire is_alu           = (opcode >= ADD) && (opcode <= PASS);
    wire is_set_palette   = (opcode == SEP);
    wire is_draw_rect     = (opcode == DRR);
    wire is_draw_tri      = (opcode == DRT);
    wire is_set_spr_pos   = (opcode == SESP);
    wire is_set_spr_attr  = (opcode == SESA);
    wire is_set_tilemap   = (opcode == SETM);
    wire is_scroll_bg     = (opcode == SCB);
    wire is_wr_spr_data   = (opcode == WRSD);
    wire is_wr_tile_data  = (opcode == WRTD);
    wire is_draw_bg       = (opcode == DRB);
    wire is_draw_sprites  = (opcode == DRS);
    // NOP (00000), WAIT_VBLANK (10010) e HALT (10011) nao geram sinais aqui:
    // sao tratados pela unidade de busca.

    // ------------------------------------------------------------------------
    // 1. Caminho da ULA
    //   - alu_op: opcode[2:0] (ULA alinhada aos opcodes)
    //   - alu_b: imm12 zero-extendido se I = 1, valor de Rm se I = 0
    //   - alu_shamt: b[4:0], serve para registrador e imediato
    //   - O resultado da ULA vai direto ao write_data do banco (a ULA e a unica
    //     que escreve em Rd); aqui so se habilita a escrita e a captura das
    //     flags, ambas em alu_done.
    // ------------------------------------------------------------------------
    assign alu_valid       = execute & is_alu;
    assign alu_op          = opcode[2:0];
    assign alu_b           = i_bit ? {20'b0, imm12} : reg_b;
    assign alu_shamt       = alu_b[4:0];
    assign rf_write_enable = alu_done;
    assign flags_we        = alu_done;

    // ------------------------------------------------------------------------
    // 2. Escritas nas memorias (Ra = endereco, Rb = dado)
    // ------------------------------------------------------------------------
    // SET_PALETTE: Ra = {palette_sel, indice}, Rb = cor RGB (9 bits)
    assign pal_we        = execute & is_set_palette;
    assign pal_wr_addr   = reg_a[8:0];
    assign pal_wr_data   = reg_b[8:0];

    // SET_TILEMAP: Ra = posicao (0-1199), Rb = pattern_id
    assign tile_we       = execute & is_set_tilemap;
    assign tile_wr_addr  = reg_a[10:0];
    assign tile_wr_data  = reg_b[7:0];

    // WRITE_TILE_DATA: Ra = endereco no padrao de tile, Rb = indice de cor
    assign tpat_we       = execute & is_wr_tile_data;
    assign tpat_wr_addr  = reg_a[13:0];
    assign tpat_wr_data  = reg_b[7:0];

    // WRITE_SPRITE_DATA: Ra = endereco no padrao de sprite, Rb = indice de cor
    assign spat_we       = execute & is_wr_spr_data;
    assign spat_wr_addr  = reg_a[13:0];
    assign spat_wr_data  = reg_b[7:0];

    // SET_SPRITE_POS: Ra = id do sprite, Rb[16:0] = {pos_y, pos_x}
    assign spos_we       = execute & is_set_spr_pos;
    assign spos_wr_addr  = reg_a[4:0];
    assign spos_wr_data  = reg_b[16:0];

    // SET_SPRITE_ATTR: Ra = id do sprite, Rb[14:0] = demais atributos
    assign sattr_we      = execute & is_set_spr_attr;
    assign sattr_wr_addr = reg_a[4:0];
    assign sattr_wr_data = reg_b[14:0];

    // SCROLL_BG: Ra[8:0] = valor, Rb[0] = eixo (0 = X, 1 = Y)
    assign scroll_wr_en   = execute & is_scroll_bg;
    assign scroll_sel     = reg_b[0];
    assign scroll_wr_data = reg_a[8:0];

    // Auto-scroll do background: nenhuma instrucao o configura, fica desligado
    assign scroll_auto_en   = 1'b0;
    assign scroll_auto_axis = 1'b0;
    assign scroll_auto_dir  = 1'b0;
    assign scroll_auto_step = 8'd0;

    // ------------------------------------------------------------------------
    // 3. Disparo dos motores (um pulso por instrucao)
    // ------------------------------------------------------------------------
    assign start_bg       = execute & is_draw_bg;
    assign start_sprite   = execute & is_draw_sprites;
    assign start_square   = execute & is_draw_rect;
    assign start_triangle = execute & is_draw_tri;

    // ------------------------------------------------------------------------
    // Parametros do rasterizador, tirados de R0-R7
    //   DRAW_RECT: R0=x0, R1=y0, R2=x1, R3=y1 (cantos opostos),
    //              R4=indice de cor, R5=palette_sel
    //   DRAW_TRI:  R0=x0, R1=y0, R2=x1, R3=y1, R4=x2, R5=y2,
    //              R6=indice de cor, R7=palette_sel
    // Os valores sao estaveis enquanto o motor roda, pois o PC fica parado na
    // instrucao de desenho e nenhuma outra instrucao altera R0-R7.
    // ------------------------------------------------------------------------
    wire [31:0] r0 = args[31:0];
    wire [31:0] r1 = args[63:32];
    wire [31:0] r2 = args[95:64];
    wire [31:0] r3 = args[127:96];
    wire [31:0] r4 = args[159:128];
    wire [31:0] r5 = args[191:160];
    wire [31:0] r6 = args[223:192];
    wire [31:0] r7 = args[255:224];

    assign rast_v0x     = r0[8:0];
    assign rast_v0y     = r1[7:0];
    assign rast_v1x     = r2[8:0];
    assign rast_v1y     = r3[7:0];
    assign rast_v2x     = r4[8:0];   // so usado no triangulo
    assign rast_v2y     = r5[7:0];   // so usado no triangulo
    assign rast_color   = is_draw_tri ? r6[7:0] : r4[7:0];
    assign rast_palette = is_draw_tri ? r7[0]   : r5[0];

    // ------------------------------------------------------------------------
    // 4. Motor ativo e conclusao
    //   engine_sel e derivado do opcode corrente: enquanto um motor roda, o PC
    //   permanece na instrucao de desenho, entao o seletor fica estavel.
    //   engine_done considera apenas o done do motor ativo. Um comando rejeitado
    //   pelo rasterizador tambem encerra a instrucao, para o PC nao travar.
    // ------------------------------------------------------------------------
    assign engine_sel = is_draw_bg              ? 2'd1 :
                        is_draw_sprites         ? 2'd2 :
                        (is_draw_rect | is_draw_tri) ? 2'd3 :
                                                  2'd0;

    assign engine_done = ((engine_sel == 2'd1) & done_bg)     |
                         ((engine_sel == 2'd2) & done_sprite) |
                         ((engine_sel == 2'd3) & (done_raster | raster_invalid));

    assign cmd_error = raster_invalid;

endmodule


// ============================================================================
// MUX DOS RECURSOS COMPARTILHADOS ENTRE MOTORES
// ----------------------------------------------------------------------------
// A leitura da paleta (endereco) e a escrita no framebuffer sao usadas por
// tres motores (background, sprite e rasterizador), mas apenas um roda por vez.
// engine_sel (da control_unit) escolhe de quem sao os sinais enviados as
// memorias. O dado lido da paleta nao precisa de mux: vai a todos os motores.
// Com engine_sel = 0 (nenhum motor) a escrita no framebuffer fica desligada.
// ============================================================================

module engine_mux (
    input  wire [1:0]  engine_sel,         // 1: background, 2: sprite, 3: rasterizador

    // Motor background
    input  wire [8:0]  bg_pal_addr,
    input  wire        bg_fb_we,
    input  wire [8:0]  bg_fb_x,
    input  wire [7:0]  bg_fb_y,
    input  wire [8:0]  bg_fb_data,

    // Motor sprite
    input  wire [8:0]  spr_pal_addr,
    input  wire        spr_fb_we,
    input  wire [8:0]  spr_fb_x,
    input  wire [7:0]  spr_fb_y,
    input  wire [8:0]  spr_fb_data,

    // Rasterizador (rasterizador_top)
    input  wire [8:0]  ras_pal_addr,
    input  wire        ras_fb_we,
    input  wire [8:0]  ras_fb_x,
    input  wire [7:0]  ras_fb_y,
    input  wire [8:0]  ras_fb_data,

    // Saidas para a palette_ram (porta de leitura) e para o framebuffer
    output reg  [8:0]  pal_rd_addr,
    output reg         fb_we,
    output reg  [8:0]  fb_wr_x,
    output reg  [7:0]  fb_wr_y,
    output reg  [8:0]  fb_wr_data
);

    always @(*) begin
        case (engine_sel)
            2'd1: begin
                pal_rd_addr = bg_pal_addr;
                fb_we       = bg_fb_we;
                fb_wr_x     = bg_fb_x;
                fb_wr_y     = bg_fb_y;
                fb_wr_data  = bg_fb_data;
            end
            2'd2: begin
                pal_rd_addr = spr_pal_addr;
                fb_we       = spr_fb_we;
                fb_wr_x     = spr_fb_x;
                fb_wr_y     = spr_fb_y;
                fb_wr_data  = spr_fb_data;
            end
            2'd3: begin
                pal_rd_addr = ras_pal_addr;
                fb_we       = ras_fb_we;
                fb_wr_x     = ras_fb_x;
                fb_wr_y     = ras_fb_y;
                fb_wr_data  = ras_fb_data;
            end
            default: begin
                pal_rd_addr = 9'd0;
                fb_we       = 1'b0;      // nenhum motor ativo: nao escreve
                fb_wr_x     = 9'd0;
                fb_wr_y     = 8'd0;
                fb_wr_data  = 9'd0;
            end
        endcase
    end

endmodule