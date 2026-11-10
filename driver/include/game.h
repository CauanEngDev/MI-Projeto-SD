/* ============================================================================
 * game.h - "Estrelas": pegue as estrelas que caem com a cesta
 *
 * Controles: inclinar a placa (acelerometro) ou setas/A/D movem a cesta;
 * o mouse move um cursor; espaco, enter ou clique reiniciam apos o fim.
 *
 * A logica (game_update) nao depende do hardware e roda em passos de 1/60 s.
 * game_load_assets e game_render usam a API do coprocessador (cop_api.h).
 * ========================================================================== */
#ifndef GAME_H
#define GAME_H

#include <stdint.h>

#define GAME_MAX_STARS     8
#define GAME_START_LIVES   3
#define GAME_PLAYER_Y      208       /* topo do sprite da cesta                  */
#define GAME_MISS_Y        215       /* a estrela que passa daqui bateu no chao   */

/* Sprites do coprocessador (0..31) */
#define GAME_SPRITE_PLAYER 0
#define GAME_SPRITE_STAR0  1         /* 1 .. GAME_MAX_STARS                       */
#define GAME_SPRITE_CURSOR (GAME_SPRITE_STAR0 + GAME_MAX_STARS)
#define GAME_N_SPRITES     (GAME_SPRITE_CURSOR + 1)

typedef enum { GS_PLAYING = 0, GS_OVER = 1 } game_state_t;

typedef struct {
    int     active;
    int32_t x, y, vy;                /* ponto fixo 8.8 (pixels * 256)             */
} star_t;

typedef struct {
    game_state_t state;
    int32_t  player_x;               /* 8.8                                       */
    star_t   star[GAME_MAX_STARS];
    int      score, lives, level, caught;
    int      spawn_timer;            /* passos ate a proxima estrela              */
    uint32_t rng;
    int      cursor_x, cursor_y;     /* posicao do mouse (pixels)                 */

    /* Cache do que ja foi enviado ao hardware (evita palavras desnecessarias) */
    int32_t  attr_sent[GAME_N_SPRITES];   /* -1 = nada enviado ainda              */
    int      drawn_score;                 /* -1 = placar nunca desenhado          */
} game_t;

typedef struct {
    int tilt_mg;                     /* inclinacao em milli-g; positivo = direita */
    int key_left, key_right;         /* teclas pressionadas                       */
    int action;                      /* BORDA: espaco, enter ou clique             */
    int mouse_x, mouse_y;
} game_input_t;

/* Estado inicial. Chame depois de cop_init (que zera o hardware). */
void game_init(game_t *g, uint32_t seed);
void game_restart(game_t *g);

/* Um passo de 1/60 s. "first_step" = 1 so no primeiro passo de cada quadro,
 * para que a borda de "action" valha uma unica vez. */
void game_update(game_t *g, const game_input_t *in, int first_step);

/* Carrega paleta, tiles, sprites e o chao no coprocessador (uma vez).
 * Devolve 0 ou o codigo de erro negativo da API. */
int  game_load_assets(void *base);

/* Envia os comandos de um quadro, sem o HALT (quem fecha o quadro e cop_present).
 * Devolve 0 ou o codigo de erro negativo da API. */
int  game_render(game_t *g, void *base);

#endif /* GAME_H */