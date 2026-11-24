#include "pac_render.h"
#include "cop_api.h"
#include "pac_assets.h"

#define TRY(call) do { int rc_ = (call); if (rc_ < 0) return rc_; } while (0)

#define MAP_COLS        COP_TILEMAP_COLS            /* 40 */
#define MAP_ROWS        COP_TILEMAP_ROWS            /* 30 */
#define MAZE_COL0       6                           /* coluna de tile do labirinto */
#define SCORE_DIGITS    6
#define FPS_DIGITS      3
#define BLINK_FRAMES    15                          /* energizer: 15 quadros ligado, 15 desligado */

/* posicoes de tile dos paineis */
#define SCORE_LABEL_ROW 1
#define SCORE_ROW       2
#define FPS_COL         34

static unsigned map_pos(int row, int col) { return (unsigned)(row * MAP_COLS + col); }

/* ----------------------------------------------------------------------------
 * Carga
 * -------------------------------------------------------------------------- */
int pac_load_assets(void *base)
{
    TRY(cop_load_palette(base, 0, pac_palette, PAC_N_COLORS));

    for (int t = 0; t < PAC_N_TILES; t++)
        TRY(cop_write_tile_data(base, (uint32_t)t, pac_tiles[t]));

    for (int s = 0; s < PAC_N_SPRITES; s++) {
        uint8_t ram[256];
        cop_sprite16_to_ram(pac_sprites[s], ram);
        TRY(cop_write_sprite_data(base, (uint32_t)s, ram));
    }
    for (uint32_t id = 0; id < COP_MAX_SPRITES; id++)          /* todos desligados */
        TRY(cop_set_sprite_attr(base, id, 0));

    TRY(cop_scroll_bg(base, 0, PAC_SCROLL_Y));

    /* Mapa inteiro: as memorias NAO comecam zeradas (README, secao 5) */
    uint8_t map[MAP_ROWS][MAP_COLS];
    for (int r = 0; r < MAP_ROWS; r++)
        for (int c = 0; c < MAP_COLS; c++) map[r][c] = PAC_TILE_BLANK;
    for (int y = 0; y < MAP_ROWS && y < MAZE_H; y++)           /* a linha 30 do labirinto fica fora */
        for (int x = 0; x < MAZE_W; x++) map[y][MAZE_COL0 + x] = pac_maze_tilemap[y][x];
    static const uint8_t score_word[5] = { PAC_TILE_LETTER_S, PAC_TILE_LETTER_C, PAC_TILE_LETTER_O, PAC_TILE_LETTER_R, PAC_TILE_LETTER_E };
    static const uint8_t fps_word[3]   = { PAC_TILE_LETTER_F, PAC_TILE_LETTER_P, PAC_TILE_LETTER_S };
    for (int i = 0; i < 5; i++) map[SCORE_LABEL_ROW][i] = score_word[i];
    for (int i = 0; i < 3; i++) map[SCORE_LABEL_ROW][FPS_COL + i] = fps_word[i];
    for (int i = 0; i < SCORE_DIGITS; i++) map[SCORE_ROW][i] = PAC_TILE_DIGIT0;
    for (int i = 0; i < FPS_DIGITS; i++)   map[SCORE_ROW][FPS_COL + i] = PAC_TILE_DIGIT0;

    for (int r = 0; r < MAP_ROWS; r++)
        for (int c = 0; c < MAP_COLS; c++)
            TRY(cop_set_tilemap(base, map_pos(r, c), map[r][c]));
    return 0;
}

void pac_render_init(pac_render_t *r)
{
    r->attr_sent = -1;
    r->drawn_score = -1;
    r->drawn_fps = -1;
    r->blink_on = -1;
    r->frames = 0;
}

/* ----------------------------------------------------------------------------
 * Quadro
 * -------------------------------------------------------------------------- */
/* Atualiza so os digitos que mudaram. "old" < 0: escreve todos. */
static int put_number(void *base, int row, int col0, int digits, int old, int value)
{
    int div = 1;
    for (int i = 1; i < digits; i++) div *= 10;
    for (int i = 0; i < digits; i++, div /= 10) {
        int nd = (value / div) % 10;
        int od = old < 0 ? -1 : (old / div) % 10;
        if (nd != od) TRY(cop_set_tilemap(base, map_pos(row, col0 + i), (unsigned)(PAC_TILE_DIGIT0 + nd)));
    }
    return 0;
}

int pac_render_frame(pac_render_t *r, void *base, pac_t *p, int fps)
{
    /* 1. Fundo: o mapa precisa estar pronto ANTES do DRAW_BG */
    for (int i = 0; i < p->n_ev; i++) {
        int row = p->ev[i].y, col = MAZE_COL0 + p->ev[i].x;
        if (row < MAP_ROWS) TRY(cop_set_tilemap(base, map_pos(row, col), PAC_TILE_BLANK));
    }
    p->n_ev = 0;

    int score = p->score > 999999 ? 999999 : p->score;
    if (score != r->drawn_score) {
        TRY(put_number(base, SCORE_ROW, 0, SCORE_DIGITS, r->drawn_score, score));
        r->drawn_score = score;
    }
    if (fps > 999) fps = 999;
    if (fps < 0) fps = 0;
    if (fps != r->drawn_fps) {
        TRY(put_number(base, SCORE_ROW, FPS_COL, FPS_DIGITS, r->drawn_fps, fps));
        r->drawn_fps = fps;
    }

    /* 2. Energizers piscam por troca de cor da paleta (3 palavras) */
    int on = ((r->frames / BLINK_FRAMES) & 1) == 0;
    if (on != r->blink_on) {
        TRY(cop_set_palette(base, 0, PAC_C_ENERGIZER, on ? pac_palette[PAC_C_ENERGIZER] : pac_palette[PAC_C_BLACK]));
        r->blink_on = on;
    }

    TRY(cop_draw_bg(base));

    /* 3. Pac-Man: boca para a direita/cima; esquerda e baixo por espelhamento */
    int fr = pac_anim_frame(p);
    int pattern, flip_h = 0, flip_v = 0;
    switch (p->dir) {
    case DIR_RIGHT: pattern = PAC_SPR_RIGHT0 + fr; break;
    case DIR_LEFT:  pattern = PAC_SPR_RIGHT0 + fr; flip_h = 1; break;
    case DIR_UP:    pattern = PAC_SPR_UP0 + fr;    break;
    default:        pattern = PAC_SPR_UP0 + fr;    flip_v = 1; break;   /* DIR_DOWN */
    }
    int32_t attr = (int32_t)COP_SPRITE_ATTR(1, 10, flip_v, flip_h, 0, pattern);
    if (attr != r->attr_sent) {
        TRY(cop_set_sprite_attr(base, PAC_SPRITE_PACMAN, (uint32_t)attr));
        r->attr_sent = attr;
    }
    int sx = PAC_SCREEN_X0 + p->x - 8;                  /* canto do sprite de 16x16 */
    int sy = p->y - 8 - PAC_SCROLL_Y;
    TRY(cop_set_sprite_pos(base, PAC_SPRITE_PACMAN, (uint32_t)sx, (uint32_t)sy));
    TRY(cop_draw_sprites(base));

    r->frames++;
    return 0;
}
