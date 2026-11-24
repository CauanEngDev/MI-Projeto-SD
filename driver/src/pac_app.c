#include "pac_app.h"

#include <stdio.h>
#include "cop_api.h"
#include "pac_input.h"
#include "pac_render.h"

int pac_app_run(void *base, input_t *in, perf_t *perf, const pac_cfg_t *cfg)
{
    pac_t game;
    pac_render_t rend;
    pac_intent_t intent = { DIR_NONE, 0, 0 };
    int th = cfg->mouse_threshold > 0 ? cfg->mouse_threshold : PAC_MOUSE_THRESH;

    pac_init(&game, 1);
    pac_render_init(&rend);

    uint32_t frame = cop_frame_count(base);
    int steps = 1;                                    /* passos de logica deste quadro */
    long n = 0;
    if (perf) perf_start(perf);

    for (;;) {
        if (cfg->max_frames > 0 && n >= cfg->max_frames) return PAC_OK;
        if (perf) perf_frame_begin(perf);

        /* 1. Entrada, o mais tarde possivel (logo apos o vblank anterior) */
        input_poll(in);
        if (in->keys & INPUT_QUIT) return PAC_OK;
        dir_t want = pac_input_dir(&intent, in, th);

        /* 2. Logica: se o video atrasou, repete passos para manter a velocidade do jogo */
        for (int s = 0; s < steps; s++) pac_step(&game, want);
        if (perf) perf_add_steps(perf, steps);

        /* 3. Comandos do quadro */
        int rc = pac_render_frame(&rend, base, &game, perf ? perf_fps(perf) : 0);
        if (rc < 0) {
            fprintf(stderr, "erro ao enviar o quadro %ld (codigo %d)\n", n, rc);
            return PAC_ERR_RENDER;
        }
        if (perf) perf_push_done(perf);
        if (cfg->on_frame) cfg->on_frame(cfg->user, &game, n);

        /* 4. HALT + espera da troca de buffer (sincronismo de 60 FPS) */
        uint32_t nf = cop_present(base, frame);
        if (perf) perf_present_done(perf, in->event_time);
        if (nf == 0xFFFFFFFFu) {
            fprintf(stderr, "tempo esgotado esperando o vblank (STATUS=0x%08x)\n", cop_status(base));
            return PAC_ERR_SYNC;
        }
        steps = (int)((nf - frame) & 0xFFFFu);
        if (steps < 1) steps = 1;
        if (steps > PAC_MAX_CATCHUP) steps = PAC_MAX_CATCHUP;
        frame = nf;
        n++;

        if (cop_has_error(base)) {
            fprintf(stderr, "coprocessador em erro (STATUS=0x%08x)\n", cop_status(base));
            return PAC_ERR_HW;
        }
    }
}
