#define _POSIX_C_SOURCE 200809L
#include "app.h"
#include "cop_api.h"

#include <stdio.h>
#include <time.h>

static double now_s(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (double)t.tv_sec + (double)t.tv_nsec * 1e-9;
}

int app_run(void *base, input_t *in, acel_t *ac, const app_cfg_t *cfg)
{
    game_t g;
    game_init(&g, cfg->seed);

    uint32_t frame = cop_frame_count(base);     /* contador atual do hardware */
    int steps = 1;                               /* passos de logica deste quadro */
    long n = 0;
    double t0 = cfg->verbose ? now_s() : 0.0;
    long n0 = 0;

    for (;;) {
        if (cfg->max_frames > 0 && n >= cfg->max_frames) return APP_OK;

        /* 1. Entrada, o mais tarde possivel (logo apos o vblank anterior) */
        input_poll(in);
        if (in->keys & INPUT_QUIT) return APP_OK;

        int32_t ax = 0, ay, az;
        int tilt = 0;
        if (ac && ac->is_open && acel_read(ac, &ax, &ay, &az) == ACEL_OK)
            tilt = ax * (cfg->tilt_sign < 0 ? -1 : 1);          /* falha: sem inclinacao */

        game_input_t gi = {
            .tilt_mg   = tilt,
            .key_left  = (in->keys & INPUT_LEFT)  != 0,
            .key_right = (in->keys & INPUT_RIGHT) != 0,
            .action    = (in->key_edges & INPUT_ACTION) || (in->button_edges & INPUT_MOUSE_LEFT),
            .mouse_x   = in->mouse_x,
            .mouse_y   = in->mouse_y,
        };

        /* 2. Logica: se o video atrasou, repete passos para manter a velocidade do jogo */
        for (int s = 0; s < steps; s++) game_update(&g, &gi, s == 0);

        /* 3. Comandos do quadro */
        int rc = game_render(&g, base);
        if (rc < 0) {
            fprintf(stderr, "erro ao enviar o quadro %ld (codigo %d)\n", n, rc);
            return APP_ERR_RENDER;
        }
        if (cfg->on_frame) cfg->on_frame(cfg->user, &g, n);

        /* 4. HALT + espera da troca de buffer (sincronismo de 60 FPS) */
        uint32_t nf = cop_present(base, frame);
        if (nf == 0xFFFFFFFFu) {
            fprintf(stderr, "tempo esgotado esperando o vblank (STATUS=0x%08x)\n", cop_status(base));
            return APP_ERR_SYNC;
        }
        steps = (int)((nf - frame) & 0xFFFFu);                    /* quadros decorridos */
        if (steps < 1) steps = 1;
        if (steps > APP_MAX_CATCHUP) steps = APP_MAX_CATCHUP;
        frame = nf;
        n++;

        if (cop_has_error(base)) {
            fprintf(stderr, "coprocessador em erro (STATUS=0x%08x)\n", cop_status(base));
            return APP_ERR_HW;
        }

        if (cfg->verbose && n - n0 >= 120) {
            double t1 = now_s();
            printf("%.1f quadros/s | placar %d vidas %d\n", (double)(n - n0) / (t1 - t0), g.score, g.lives);
            t0 = t1; n0 = n;
        }
    }
}