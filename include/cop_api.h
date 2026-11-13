/* ============================================================================
 * cop_api.h - API do coprocessador grafico (implementada em api.S)
 *
 * Todas as funcoes recebem o ponteiro devolvido por hps_open() e enviam
 * palavras da ISA pela fila de comandos (busca passiva). Os limites abaixo vem
 * da RTL (unidade_de_controle.v, banco_registradores.v, rasterizador_top.v,
 * motor_sprite.v, motor_background.v).
 * ========================================================================== */
#ifndef COP_API_H
#define COP_API_H

#include <stdint.h>

/* ----------------------------------------------------------------------------
 * Dimensoes do hardware
 * -------------------------------------------------------------------------- */
#define COP_SCREEN_W         320     /* x valido: 0..319                       */
#define COP_SCREEN_H         240     /* y valido: 0..239                       */
#define COP_TILE_SIZE        8       /* tiles de fundo 8x8                     */
#define COP_TILEMAP_COLS     40
#define COP_TILEMAP_ROWS     30
#define COP_TILEMAP_SIZE     1200    /* posicao = linha * 40 + coluna          */
#define COP_TILE_PATTERNS    256     /* padroes de tile (64 pixels cada)       */
#define COP_SPRITE_SIZE      16      /* sprites 16x16                          */
#define COP_MAX_SPRITES      32
#define COP_SPRITE_PATTERNS  64      /* padroes de sprite (256 pixels cada)    */
#define COP_PALETTES         2       /* palette_sel: 0 ou 1                    */
#define COP_PALETTE_COLORS   256     /* indices por paleta                     */

/* ----------------------------------------------------------------------------
 * Codigos de retorno (cop_present devolve o FRAME_COUNT ou -1)
 * -------------------------------------------------------------------------- */
#define COP_OK               0
#define COP_ERR_TIMEOUT      (-1)    /* fila cheia / hardware nao respondeu    */
#define COP_ERR_RANGE        (-3)    /* argumento fora da faixa: nada foi enviado */

/* ----------------------------------------------------------------------------
 * Empacotamento de valores
 * -------------------------------------------------------------------------- */
/* Cor RGB de 9 bits da paleta: 3 bits por canal (0..7) */
#define COP_RGB(r, g, b)     ((((r) & 7u) << 6) | (((g) & 7u) << 3) | ((b) & 7u))

/* Cor do rasterizador: {palette_sel, indice} (9 bits) */
#define COP_COLOR(sel, idx)  ((((sel) & 1u) << 8) | ((idx) & 0xFFu))

/* Atributos de sprite (15 bits):
 * [14] enable | [13:9] prioridade | [8] flip_v | [7] flip_h |
 * [6] palette_sel | [5:0] padrao                                              */
#define COP_SPRITE_ATTR(enable, prio, flip_v, flip_h, pal, pattern) \
    ((((enable) & 1u) << 14) | (((prio) & 31u) << 9) | (((flip_v) & 1u) << 8) | \
     (((flip_h) & 1u) << 7)  | (((pal) & 1u) << 6)   | ((pattern) & 63u))

/* ----------------------------------------------------------------------------
 * Camada 1 - base (hps_open/hps_close, fila e STATUS)
 * -------------------------------------------------------------------------- */
void*    hps_open(void);                          /* NULL se falhar            */
int      hps_close(void* lw_virtual);

int      cop_init(void* base);                    /* 0, -1 ID errado, -2 PLL   */
int      cop_push(void* base, uint32_t palavra);  /* 0 ou -1                   */
uint32_t cop_status(void* base);
uint32_t cop_has_error(void* base);               /* != 0: ERROR ou OVERFLOW   */
void     cop_clear_flags(void* base);             /* limpa OVERFLOW            */
int      cop_wait_idle(void* base);               /* 0 ou -1                   */
uint32_t cop_frame_count(void* base);
uint32_t cop_wait_frame(void* base, uint32_t anterior); /* novo contador ou -1 */

/* ----------------------------------------------------------------------------
 * Camada 2 - instrucoes da ISA
 * -------------------------------------------------------------------------- */

/* Por quadro. Prioridade fixa em hardware: fundo < rasterizadores < sprites,
 * independente da ordem das chamadas. Ordem tipica de um quadro:
 *   draw_bg, draw_rect/draw_tri, set_sprite_*, draw_sprites, present.
 * O double buffer devolve o quadro de dois frames atras: redesenhe tudo.      */
int      cop_draw_bg(void* base);
int      cop_draw_sprites(void* base);
int      cop_halt(void* base);
uint32_t cop_present(void* base, uint32_t frame_anterior); /* HALT + espera troca */
int      cop_scroll_bg(void* base, uint32_t x, uint32_t y);       /* x<320, y<240 */
int      cop_set_sprite_pos(void* base, uint32_t id, uint32_t x, uint32_t y);
                                                   /* id<32, x<512, y<256      */
int      cop_set_sprite_attr(void* base, uint32_t id, uint32_t attr);
                                                   /* id<32, attr<0x8000       */
int      cop_draw_rect(void* base, uint32_t x0, uint32_t y0,
                       uint32_t x1, uint32_t y1, uint32_t cor);
int      cop_draw_tri(void* base, uint32_t x0, uint32_t y0, uint32_t x1,
                      uint32_t y1, uint32_t x2, uint32_t y2, uint32_t cor);
int      cop_clear_screen(void* base, uint32_t cor);  /* nao cobre sprites     */

/* Carga de recursos (uma vez, na inicializacao) */
int      cop_set_palette(void* base, uint32_t sel, uint32_t indice, uint32_t rgb);
int      cop_load_palette(void* base, uint32_t sel, const uint16_t* rgb, uint32_t n);
int      cop_set_tilemap(void* base, uint32_t posicao, uint32_t pattern_id);
int      cop_write_tile_data(void* base, uint32_t tile_id, const uint8_t* px64);
int      cop_write_sprite_data(void* base, uint32_t pattern_id, const uint8_t* px256);

/* ----------------------------------------------------------------------------
 * Conversao de sprite 16x16 (linha a linha) para a ordem da Sprite Pattern RAM.
 * O hardware monta o sprite de 4 blocos 8x8: 0 = superior esquerdo,
 * 1 = superior direito, 2 = inferior esquerdo, 3 = inferior direito, cada bloco
 * linha a linha. Use o resultado em cop_write_sprite_data().
 * -------------------------------------------------------------------------- */
static inline void cop_sprite16_to_ram(const uint8_t lin[256], uint8_t ram[256])
{
    for (int y = 0; y < 16; y++)
        for (int x = 0; x < 16; x++)
            ram[(((y >> 3) << 1) | (x >> 3)) * 64 + (y & 7) * 8 + (x & 7)] = lin[y * 16 + x];
}

#endif /* COP_API_H */