#define _POSIX_C_SOURCE 200809L
#include "minecraft.h"
#include "video.h"
#include "input.h"
#include <stdio.h>
#include <time.h>

int main(void) {
    Game g;
    input_t in;

    game_init(&g, (uint32_t)time(NULL));
    input_init(&in);

    int vr = video_open();

    if (vr < 0) {
        fprintf(stderr,
            "Falha ao inicializar o coprocessador. Codigo: %d\n", vr);

        switch (vr) {
            case -1: fprintf(stderr, "Erro: acesso a memoria HPS (/dev/mem ou mmap).\n"); break;
            case -2: fprintf(stderr, "Erro: identificacao do hardware, reset ou PLL.\n"); break;
            case -3: fprintf(stderr, "Erro: carregamento da paleta.\n"); break;
            case -4: fprintf(stderr, "Erro: carregamento dos tiles.\n"); break;
            case -5: fprintf(stderr, "Erro: carregamento dos sprites.\n"); break;
            case -6: fprintf(stderr, "Erro: configuracao dos atributos do sprite.\n"); break;
            default: fprintf(stderr, "Erro desconhecido.\n"); break;
        }

        return 1;
    }

    if (!input_open(&in))
        fprintf(stderr, "Aviso: teclado/mouse indisponivel.\n");

    for (;;) {
        input_poll(&in);

        if (in.keys & INPUT_QUIT)
            break;

        game_step(&g,
            (in.keys & INPUT_LEFT) != 0,
            (in.keys & INPUT_RIGHT) != 0,
            (in.key_edges & INPUT_ACTION) != 0);

        if (in.button_edges & INPUT_MOUSE_LEFT)
            game_mine(&g, in.mouse_x, in.mouse_y);

        if (in.button_edges & INPUT_MOUSE_RIGHT)
            game_place(&g, in.mouse_x, in.mouse_y);

        if (video_frame(&g, 0) < 0) {
            fprintf(stderr, "Erro ao renderizar/sincronizar.\n");
            break;
        }
    }

    input_close(&in);
    video_close();

    return 0;
}
