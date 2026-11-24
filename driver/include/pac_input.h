/* ============================================================================
 * pac_input.h - Conversao de teclado e mouse na direcao pedida ao Pac-Man
 * Logica pura (sem hardware): testavel no host.
 * ========================================================================== */
#ifndef PAC_INPUT_H
#define PAC_INPUT_H

#include "input.h"
#include "pac_core.h"

#define PAC_MOUSE_THRESH  8     /* contagens do mouse para valer como direcao */

/* Estado da conversao entrada -> direcao */
typedef struct {
    dir_t key_dir;              /* direcao da tecla mantida (DIR_NONE se nenhuma)   */
    int   acc_x, acc_y;         /* movimento do mouse acumulado                     */
} pac_intent_t;

/* Converte teclado (setas / WASD) e mouse (movimento acima do limiar) na direcao
 * pedida. Devolve DIR_NONE quando nada novo foi pedido (o Pac-Man mantem a anterior).
 * O teclado tem prioridade sobre o mouse. */
dir_t pac_input_dir(pac_intent_t *st, const input_t *in, int threshold);

#endif /* PAC_INPUT_H */
