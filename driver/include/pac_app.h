/* ============================================================================
 * pac_app.h - Laco do jogo (marco 1: labirinto, Pac-Man, medicao)
 *
 * Cada iteracao: le a entrada, avanca a logica, envia o quadro e sincroniza com o
 * vblank (cop_present). A entrada e lida logo apos o vblank anterior, o mais tarde
 * possivel antes de montar o quadro, para minimizar a latencia.
 * ========================================================================== */
#ifndef PAC_APP_H
#define PAC_APP_H

#include <stdint.h>
#include "input.h"
#include "pac_core.h"
#include "pac_input.h"
#include "perf.h"

#define PAC_OK            0
#define PAC_ERR_RENDER  (-1)    /* a API recusou ou nao conseguiu enviar um comando */
#define PAC_ERR_SYNC    (-2)    /* o FRAME_COUNT nao avancou (video parado?)        */
#define PAC_ERR_HW      (-3)    /* STATUS com ERROR ou OVERFLOW                     */

#define PAC_MAX_CATCHUP   4     /* passos de logica por quadro, no maximo           */

typedef struct {
    long  max_frames;           /* 0 = ate ESC                                      */
    int   mouse_threshold;      /* 0 = PAC_MOUSE_THRESH                             */
    /* Chamado a cada quadro, depois de enviar os comandos e antes de cop_present */
    void (*on_frame)(void *user, const pac_t *p, long frame);
    void *user;
} pac_cfg_t;

/* base = ponteiro de hps_open (apos cop_init e pac_load_assets). perf pode ser NULL. */
int pac_app_run(void *base, input_t *in, perf_t *perf, const pac_cfg_t *cfg);

#endif /* PAC_APP_H */
