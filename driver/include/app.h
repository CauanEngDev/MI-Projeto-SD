/* ============================================================================
 * app.h - Laco principal do jogo
 *
 * Cada iteracao: le os dispositivos de entrada, avanca a logica, envia os
 * comandos do quadro e sincroniza com o vblank (cop_present). A entrada e lida
 * logo apos o vblank, o mais tarde possivel antes de montar o quadro, para
 * minimizar a latencia entre o input e a imagem.
 * ========================================================================== */
#ifndef APP_H
#define APP_H

#include <stdint.h>
#include "acel.h"
#include "game.h"
#include "input.h"

#define APP_OK            0
#define APP_ERR_RENDER  (-1)    /* a API rejeitou ou nao conseguiu enviar um comando */
#define APP_ERR_SYNC    (-2)    /* o FRAME_COUNT nao avancou (video parado?)         */
#define APP_ERR_HW      (-3)    /* STATUS com ERROR ou OVERFLOW                      */

#define APP_MAX_CATCHUP  4      /* passos de logica por quadro, no maximo            */

typedef struct {
    long     max_frames;        /* 0 = ate o jogador sair (ESC)                      */
    uint32_t seed;              /* semente do gerador de numeros aleatorios          */
    int      tilt_sign;         /* +1 ou -1: sentido da inclinacao no eixo X         */
    int      verbose;           /* imprime a taxa de quadros a cada ~2 s             */
    /* Chamado a cada quadro, depois de game_render e antes de cop_present */
    void   (*on_frame)(void *user, const game_t *g, long frame);
    void    *user;
} app_cfg_t;

/* "base" = ponteiro de hps_open (apos cop_init e game_load_assets).
 * "ac" pode ser NULL ou nao estar aberto: o jogo segue so com o teclado.
 * Devolve APP_OK (saiu com ESC ou atingiu max_frames) ou um APP_ERR_*. */
int app_run(void *base, input_t *in, acel_t *ac, const app_cfg_t *cfg);

#endif /* APP_H */