#include "pac_input.h"

#include <stdlib.h>

dir_t pac_input_dir(pac_intent_t *st, const input_t *in, int threshold)
{
    static const struct { uint32_t bit; dir_t d; } map[4] = {
        { INPUT_UP, DIR_UP }, { INPUT_DOWN, DIR_DOWN }, { INPUT_LEFT, DIR_LEFT }, { INPUT_RIGHT, DIR_RIGHT }
    };

    /* Teclado: a tecla pressionada mais recentemente vence; ao soltar, vale outra que siga pressionada */
    dir_t edge = DIR_NONE;                                  /* tecla pressionada neste quadro */
    for (int i = 0; i < 4; i++)
        if (in->key_edges & map[i].bit) { st->key_dir = map[i].d; edge = map[i].d; }
    if (st->key_dir != DIR_NONE) {
        uint32_t bit = 0;
        for (int i = 0; i < 4; i++) if (map[i].d == st->key_dir) bit = map[i].bit;
        if (!(in->keys & bit)) {
            st->key_dir = DIR_NONE;
            for (int i = 0; i < 4; i++) if (in->keys & map[i].bit) st->key_dir = map[i].d;
        }
    }

    /* Mouse: o movimento acumulado que passa do limiar define a direcao (eixo dominante) */
    dir_t md = DIR_NONE;
    st->acc_x += in->mouse_dx;
    st->acc_y += in->mouse_dy;
    int ax = abs(st->acc_x), ay = abs(st->acc_y);
    if (ax >= threshold || ay >= threshold) {
        md = (ax >= ay) ? (st->acc_x > 0 ? DIR_RIGHT : DIR_LEFT) : (st->acc_y > 0 ? DIR_DOWN : DIR_UP);
        st->acc_x = st->acc_y = 0;
    } else {
        st->acc_x = st->acc_x * 3 / 4;                      /* deriva do mouse decai */
        st->acc_y = st->acc_y * 3 / 4;
    }
    if (edge != DIR_NONE) return edge;                      /* toque mais curto que um quadro ainda vale */
    return st->key_dir != DIR_NONE ? st->key_dir : md;
}
