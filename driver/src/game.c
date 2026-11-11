#include "game.h"
#include "cop_api.h"

#include <string.h>

/* ----------------------------------------------------------------------------
 * Paleta 0 (fundo e sprites). O indice 0 e transparente nos sprites.
 * -------------------------------------------------------------------------- */
enum {
    IDX_BLACK = 0, IDX_SKY = 1, IDX_SKY2 = 2, IDX_GRASS = 3, IDX_DGREEN = 4,
    IDX_WHITE = 5, IDX_YELLOW = 6, IDX_ORANGE = 7, IDX_RED = 8, IDX_BROWN = 9,
    IDX_GRAY = 10, IDX_DIRT = 11, IDX_LIGHT = 12, N_COLORS = 13
};

static const uint16_t palette[N_COLORS] = {
    COP_RGB(0, 0, 0),   /*  0 preto (transparente em sprites) */
    COP_RGB(2, 4, 7),   /*  1 ceu                              */
    COP_RGB(2, 4, 7),   /*  2 (reservado)                      */
    COP_RGB(1, 5, 1),   /*  3 grama                            */
    COP_RGB(0, 3, 0),   /*  4 grama escura                     */
    COP_RGB(7, 7, 7),   /*  5 branco                           */
    COP_RGB(7, 7, 0),   /*  6 amarelo                          */
    COP_RGB(7, 4, 0),   /*  7 laranja                          */
    COP_RGB(6, 0, 0),   /*  8 vermelho                         */
    COP_RGB(4, 2, 0),   /*  9 marrom                           */
    COP_RGB(1, 1, 1),   /* 10 cinza escuro (contorno)          */
    COP_RGB(3, 1, 0),   /* 11 terra                            */
    COP_RGB(7, 7, 4),   /* 12 brilho                           */
};

/* ----------------------------------------------------------------------------
 * Tiles do fundo (8x8): 0 ceu, 1 grama, 2 terra, 3..12 digitos 0..9
 * -------------------------------------------------------------------------- */
enum { TILE_SKY = 0, TILE_GRASS = 1, TILE_DIRT = 2, TILE_DIGIT0 = 3, N_TILES = 13 };

/* Fonte 8x8 dos digitos: um byte por linha, bit 7 = pixel da esquerda */
static const uint8_t font_digits[10][8] = {
    { 0x3C, 0x66, 0x6E, 0x76, 0x66, 0x66, 0x3C, 0x00 },   /* 0 */
    { 0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00 },   /* 1 */
    { 0x3C, 0x66, 0x06, 0x0C, 0x18, 0x30, 0x7E, 0x00 },   /* 2 */
    { 0x3C, 0x66, 0x06, 0x1C, 0x06, 0x66, 0x3C, 0x00 },   /* 3 */
    { 0x0C, 0x1C, 0x3C, 0x6C, 0x7E, 0x0C, 0x0C, 0x00 },   /* 4 */
    { 0x7E, 0x60, 0x7C, 0x06, 0x06, 0x66, 0x3C, 0x00 },   /* 5 */
    { 0x1C, 0x30, 0x60, 0x7C, 0x66, 0x66, 0x3C, 0x00 },   /* 6 */
    { 0x7E, 0x06, 0x0C, 0x18, 0x30, 0x30, 0x30, 0x00 },   /* 7 */
    { 0x3C, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x3C, 0x00 },   /* 8 */
    { 0x3C, 0x66, 0x66, 0x3E, 0x06, 0x0C, 0x38, 0x00 },   /* 9 */
};

static void build_tile(int id, uint8_t t[64])
{
    for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
            uint8_t c;
            if (id == TILE_SKY)        c = IDX_SKY;
            else if (id == TILE_GRASS) c = (y < 4) ? ((x + y) % 5 == 0 ? IDX_DGREEN : IDX_GRASS) : IDX_DGREEN;
            else if (id == TILE_DIRT)  c = ((x * 3 + y * 5) % 7 == 0) ? IDX_BROWN : IDX_DIRT;
            else {                                                  /* digito */
                int d = id - TILE_DIGIT0;
                c = (font_digits[d][y] & (0x80 >> x)) ? IDX_WHITE : IDX_SKY;
            }
            t[y * 8 + x] = c;
        }
    }
}

/* ----------------------------------------------------------------------------
 * Sprites 16x16 em arte ASCII: '.' transparente, W branco, Y amarelo,
 * L brilho, O laranja, B marrom, K contorno
 * -------------------------------------------------------------------------- */
enum { PAT_PLAYER = 0, PAT_STAR = 1, PAT_CURSOR = 2, N_PATTERNS = 3 };

static const char art_player[16][17] = {
    "................", "................", "................", "................",
    "................", "..BBBBBBBBBBBB..", ".BOOOOOOOOOOOOB.", ".BOBOBOBOBOBOOB.",
    ".BOOOOOOOOOOOOB.", "..BOBOBOBOBOOB..", "..BOOOOOOOOOOB..", "...BOBOBOBOOB...",
    "...BOOOOOOOOB...", "....BBBBBBBB....", "................", "................",
};
static const char art_star[16][17] = {
    ".......YY.......", ".......YY.......", "......YYYY......", "......YLLY......",
    ".YYYYYYLLYYYYYY.", "..YYYYYYYYYYYY..", "...YYYYYYYYYY...", "....YYYYYYYY....",
    "....YYYYYYYY....", "...YYYYYYYYYY...", "...YYYY..YYYY...", "..YYYY....YYYY..",
    "..YYY......YYY..", "..YY........YY..", "................", "................",
};
static const char art_cursor[16][17] = {
    "K...............", "KK..............", "KWK.............", "KWWK............",
    "KWWWK...........", "KWWWWK..........", "KWWWWWK.........", "KWWWWWWK........",
    "KWWWWWWWK.......", "KWWWWWKKKK......", "KWWKWWK.........", "KWK.KWWK........",
    "KK..KWWK........", "K....KWWK.......", ".....KWWK.......", "......KK........",
};

static uint8_t art_index(char c)
{
    switch (c) {
    case 'W': return IDX_WHITE;   case 'Y': return IDX_YELLOW;  case 'L': return IDX_LIGHT;
    case 'O': return IDX_ORANGE;  case 'B': return IDX_BROWN;   case 'K': return IDX_GRAY;
    default:  return IDX_BLACK;                                   /* '.' = transparente */
    }
}

/* arte ASCII (linha a linha) -> ordem da Sprite Pattern RAM (4 blocos 8x8) */
static void art_to_ram(const char art[16][17], uint8_t ram[256])
{
    uint8_t lin[256];
    for (int y = 0; y < 16; y++)
        for (int x = 0; x < 16; x++)
            lin[y * 16 + x] = art_index(art[y][x]);
    cop_sprite16_to_ram(lin, ram);
}

/* ----------------------------------------------------------------------------
 * Carga de recursos
 * -------------------------------------------------------------------------- */
#define TRY(call) do { int rc_ = (call); if (rc_ < 0) return rc_; } while (0)

int game_load_assets(void *base)
{
    TRY(cop_load_palette(base, 0, palette, N_COLORS));

    uint8_t px[64];
    for (int id = 0; id < N_TILES; id++) {
        build_tile(id, px);
        TRY(cop_write_tile_data(base, (uint32_t)id, px));
    }

    uint8_t ram[256];
    art_to_ram(art_player, ram); TRY(cop_write_sprite_data(base, PAT_PLAYER, ram));
    art_to_ram(art_star,   ram); TRY(cop_write_sprite_data(base, PAT_STAR,   ram));
    art_to_ram(art_cursor, ram); TRY(cop_write_sprite_data(base, PAT_CURSOR, ram));

    /* Chao: linha 28 de grama e linha 29 de terra (y = 224..239). O resto do
     * tilemap e zero apos o reset, ou seja, tile 0 (ceu). */
    for (int col = 0; col < COP_TILEMAP_COLS; col++) {
        TRY(cop_set_tilemap(base, 28u * COP_TILEMAP_COLS + (unsigned)col, TILE_GRASS));
        TRY(cop_set_tilemap(base, 29u * COP_TILEMAP_COLS + (unsigned)col, TILE_DIRT));
    }
    return 0;
}

/* ----------------------------------------------------------------------------
 * Logica
 * -------------------------------------------------------------------------- */
#define FP              8
#define PLAYER_MAX_X    ((COP_SCREEN_W - COP_SPRITE_SIZE) << FP)     /* 304 px */
#define MAX_SPEED       (5 << FP)                                    /* 5 px por passo */
#define TILT_DEAD_MG    80
#define TILT_FULL_MG    600
#define SCORE_MAX       99999

static uint32_t rnd(game_t *g)           /* xorshift32 */
{
    uint32_t x = g->rng;
    x ^= x << 13; x ^= x >> 17; x ^= x << 5;
    return g->rng = x;
}

void game_restart(game_t *g)
{
    g->state = GS_PLAYING;
    g->player_x = ((COP_SCREEN_W - COP_SPRITE_SIZE) / 2) << FP;
    memset(g->star, 0, sizeof g->star);
    g->score = 0;
    g->lives = GAME_START_LIVES;
    g->level = 0;
    g->caught = 0;
    g->spawn_timer = 30;
}

void game_init(game_t *g, uint32_t seed)
{
    memset(g, 0, sizeof *g);
    g->rng = seed ? seed : 0x2545F491u;       /* xorshift nao aceita estado 0 */
    g->cursor_x = COP_SCREEN_W / 2;
    g->cursor_y = COP_SCREEN_H / 2;
    for (int i = 0; i < GAME_N_SPRITES; i++) g->attr_sent[i] = -1;
    g->drawn_score = -1;
    game_restart(g);
}

static int32_t tilt_to_velocity(int tilt_mg)
{
    int a = tilt_mg < 0 ? -tilt_mg : tilt_mg;
    if (a <= TILT_DEAD_MG) return 0;                       /* zona morta */
    if (a > TILT_FULL_MG) a = TILT_FULL_MG;
    int32_t v = (int32_t)(a - TILT_DEAD_MG) * MAX_SPEED / (TILT_FULL_MG - TILT_DEAD_MG);
    return tilt_mg < 0 ? -v : v;
}

static int overlap(int a0, int a1, int b0, int b1) { return a0 <= b1 && b0 <= a1; }

static int star_speed(int level)         /* 8.8: de 1,25 a 5 px por passo */
{
    int v = 320 + 48 * level;
    return v > MAX_SPEED ? MAX_SPEED : v;
}

static void spawn_star(game_t *g)
{
    for (int i = 0; i < GAME_MAX_STARS; i++) {
        if (g->star[i].active) continue;
        g->star[i].active = 1;
        g->star[i].x = (int32_t)(rnd(g) % (COP_SCREEN_W - COP_SPRITE_SIZE + 1)) << FP;
        g->star[i].y = 0;
        g->star[i].vy = star_speed(g->level);
        return;
    }
}

void game_update(game_t *g, const game_input_t *in, int first_step)
{
    g->cursor_x = in->mouse_x < 0 ? 0 : (in->mouse_x >= COP_SCREEN_W ? COP_SCREEN_W - 1 : in->mouse_x);
    g->cursor_y = in->mouse_y < 0 ? 0 : (in->mouse_y >= COP_SCREEN_H ? COP_SCREEN_H - 1 : in->mouse_y);

    if (g->state == GS_OVER) {
        if (first_step && in->action) game_restart(g);
        return;
    }

    /* Cesta: o teclado tem prioridade sobre a inclinacao */
    int32_t v = tilt_to_velocity(in->tilt_mg);
    if (in->key_left != in->key_right) v = in->key_right ? MAX_SPEED : -MAX_SPEED;
    g->player_x += v;
    if (g->player_x < 0) g->player_x = 0;
    if (g->player_x > PLAYER_MAX_X) g->player_x = PLAYER_MAX_X;

    /* Novas estrelas */
    if (--g->spawn_timer <= 0) {
        spawn_star(g);
        int base_interval = 60 - 4 * g->level;
        g->spawn_timer = (base_interval < 18 ? 18 : base_interval) + (int)(rnd(g) % 16);
    }

    /* Estrelas: queda, captura e chao */
    int px = g->player_x >> FP, py = GAME_PLAYER_Y;
    for (int i = 0; i < GAME_MAX_STARS; i++) {
        star_t *s = &g->star[i];
        if (!s->active) continue;
        s->y += s->vy;
        int sx = s->x >> FP, sy = s->y >> FP;

        /* boca da cesta: x [px+1, px+14], y [py+5, py+9]; estrela: x [sx+3, sx+12], y [sy+3, sy+12] */
        if (overlap(sx + 3, sx + 12, px + 1, px + 14) && overlap(sy + 3, sy + 12, py + 5, py + 9)) {
            s->active = 0;
            if (g->score < SCORE_MAX) g->score++;
            g->caught++;
            g->level = g->caught / 5;
        } else if (sy >= GAME_MISS_Y) {
            s->active = 0;
            if (--g->lives <= 0) {
                g->lives = 0;
                g->state = GS_OVER;
                memset(g->star, 0, sizeof g->star);
                return;
            }
        }
    }
}

/* ----------------------------------------------------------------------------
 * Renderizacao
 * -------------------------------------------------------------------------- */
#define PRIO_STAR    5
#define PRIO_PLAYER  10
#define PRIO_CURSOR  31

/* Posiciona um sprite; o atributo so e reenviado quando muda */
static int put_sprite(game_t *g, void *base, int id, int visible, int x, int y, int prio, int pattern)
{
    int32_t attr = visible ? (int32_t)COP_SPRITE_ATTR(1, prio, 0, 0, 0, pattern) : 0;
    if (g->attr_sent[id] != attr) {
        TRY(cop_set_sprite_attr(base, (uint32_t)id, (uint32_t)attr));
        g->attr_sent[id] = attr;
    }
    if (visible) TRY(cop_set_sprite_pos(base, (uint32_t)id, (uint32_t)x, (uint32_t)y));
    return 0;
}

int game_render(game_t *g, void *base)
{
    /* 1. Placar: o tilemap precisa estar pronto ANTES do DRAW_BG */
    if (g->drawn_score != g->score) {
        int s = g->score, div = 10000;
        for (int i = 0; i < 5; i++, div /= 10)
            TRY(cop_set_tilemap(base, 1u * COP_TILEMAP_COLS + 2u + (unsigned)i,
                                (unsigned)(TILE_DIGIT0 + (s / div) % 10)));
        g->drawn_score = g->score;
    }

    /* 2. Fundo, depois os retangulos (prioridade: fundo < retangulos < sprites) */
    TRY(cop_draw_bg(base));
    for (int i = 0; i < g->lives; i++) {                       /* vidas */
        unsigned x0 = 296u - 12u * (unsigned)i;
        TRY(cop_draw_rect(base, x0, 8, x0 + 7, 15, COP_COLOR(0, IDX_YELLOW)));
    }
    if (g->state == GS_OVER)                                   /* painel de fim de jogo */
        TRY(cop_draw_rect(base, 80, 100, 239, 139, COP_COLOR(0, IDX_RED)));

    /* 3. Sprites */
    TRY(put_sprite(g, base, GAME_SPRITE_PLAYER, 1, g->player_x >> FP, GAME_PLAYER_Y, PRIO_PLAYER, PAT_PLAYER));
    for (int i = 0; i < GAME_MAX_STARS; i++)
        TRY(put_sprite(g, base, GAME_SPRITE_STAR0 + i, g->star[i].active,
                       g->star[i].x >> FP, g->star[i].y >> FP, PRIO_STAR, PAT_STAR));
    TRY(put_sprite(g, base, GAME_SPRITE_CURSOR, 1, g->cursor_x, g->cursor_y, PRIO_CURSOR, PAT_CURSOR));
    TRY(cop_draw_sprites(base));
    return 0;
}