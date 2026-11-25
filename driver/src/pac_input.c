#include "pac_input.h"

#include <stdlib.h>

dir_t pac_input_dir(pac_intent_t *st, const input_t *in, int threshold)
{
    static const struct {
        uint32_t bit;
        dir_t d;
    } map[4] = {
        { INPUT_UP,    DIR_UP },
        { INPUT_DOWN,  DIR_DOWN },
        { INPUT_LEFT,  DIR_LEFT },
        { INPUT_RIGHT, DIR_RIGHT }
    };

    /* Teclado: a tecla pressionada mais recentemente vence */
    dir_t edge = DIR_NONE;

    for (int i = 0; i < 4; i++) {
        if (in->key_edges & map[i].bit) {
            st->key_dir = map[i].d;
            edge = map[i].d;
        }
    }

    /* Verifica se a tecla continua pressionada */
    if (st->key_dir != DIR_NONE) {

        uint32_t bit = 0;

        for (int i = 0; i < 4; i++) {
            if (map[i].d == st->key_dir)
                bit = map[i].bit;
        }

        if (!(in->keys & bit)) {

            st->key_dir = DIR_NONE;

            /* Se outra tecla ainda estiver pressionada, utiliza-a */
            for (int i = 0; i < 4; i++) {
                if (in->keys & map[i].bit)
                    st->key_dir = map[i].d;
            }
        }
    }

    /* Mouse: acumula os deslocamentos recebidos */
    dir_t md = DIR_NONE;

    st->acc_x += in->mouse_dx;
    st->acc_y += in->mouse_dy;

    int ax = abs(st->acc_x);
    int ay = abs(st->acc_y);

    if (threshold < 1)
        threshold = 1;

    if (ax >= threshold || ay >= threshold) {

        /* O eixo com maior deslocamento determina a direcao */
        if (ax >= ay) {
            md = (st->acc_x > 0) ? DIR_RIGHT : DIR_LEFT;
        } else {
            md = (st->acc_y > 0) ? DIR_DOWN : DIR_UP;
        }

        /* Reinicia o acumulador depois de reconhecer o movimento */
        st->acc_x = 0;
        st->acc_y = 0;
    }

    /* Prioridade para o teclado */
    if (edge != DIR_NONE)
        return edge;

    if (st->key_dir != DIR_NONE)
        return st->key_dir;

    /* Se nenhuma tecla estiver pressionada, utiliza o mouse */
    return md;
}