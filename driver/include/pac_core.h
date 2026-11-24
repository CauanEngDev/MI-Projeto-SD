/* ============================================================================
 * pac_core.h - Nucleo do jogo: movimento do Pac-Man, pontos e pontuacao
 *
 * Logica pura, sem hardware: roda em passos de 1/60 s e e testavel no host.
 * Marco 1: Pac-Man, labirinto, pontos e energizers. (Fantasmas: marco 3.)
 * ========================================================================== */
#ifndef PAC_CORE_H
#define PAC_CORE_H

#include <stdint.h>
#include "maze.h"

typedef enum { DIR_NONE = -1, DIR_RIGHT = 0, DIR_DOWN = 1, DIR_LEFT = 2, DIR_UP = 3 } dir_t;

#define PAC_EV_MAX        16     /* pontos comidos entre dois quadros desenhados */
#define PAC_SPEED_100     323    /* 100% = 75,75 px/s = 1,2625 px/quadro, em 8.8 */
#define PAC_START_LIVES   3

typedef struct { uint8_t x, y, kind; } pac_eat_t;      /* kind: 1 ponto, 2 energizer */

typedef struct {
    int      x, y;               /* centro do Pac-Man em pixels, relativo ao labirinto */
    int      sub;                /* acumulador de subpixel (1/256 px)                  */
    int      speed;              /* pixels por quadro em 8.8                           */
    dir_t    dir, want;          /* direcao atual e direcao pedida                     */
    int      eat_pause;          /* quadros parado depois de comer                     */
    int      moving;             /* andou no ultimo passo?                             */
    int      anim;               /* contador de animacao da boca                       */
    uint8_t  dots[MAZE_H][MAZE_W];   /* 0 vazio, 1 ponto, 2 energizer (o que resta)    */
    int      dots_left, score, lives, level;
    int      n_dots_eaten, n_ener_eaten;   /* contadores acumulados: pontos e energizers comidos */
    uint32_t frame;              /* passos de logica executados                        */
    pac_eat_t ev[PAC_EV_MAX];    /* pontos comidos desde a ultima limpeza (render)     */
    int      n_ev;
} pac_t;

void pac_init(pac_t *p, int level);

/* Um passo de 1/60 s. "want" = direcao pedida pelo jogador (DIR_NONE mantem a anterior). */
void pac_step(pac_t *p, dir_t want);

/* Volta ao ponto de partida (posicao, direcao, pausa), mantendo pontos, pontuacao e vidas. */
void pac_respawn(pac_t *p);

/* Nova fase: refaz todos os pontos e posiciona o Pac-Man; mantem pontuacao e vidas. */
void pac_new_level(pac_t *p, int level);

/* Quadro da animacao da boca: 0 fechada, 1 meia, 2 aberta (sequencia 0,1,2,1). */
int  pac_anim_frame(const pac_t *p);

/* Velocidade (8.8) por nivel: 80% no nivel 1, 90% nos niveis 2 a 4, 100% depois. */
int  pac_speed_for_level(int level);

#endif /* PAC_CORE_H */
