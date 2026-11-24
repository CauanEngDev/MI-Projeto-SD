#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cop_api.h"
#include "input.h"
#include "pac_app.h"
#include "pac_render.h"
#include "perf.h"

static void usage(const char *p)
{
    fprintf(stderr,
        "uso: %s [opcoes]\n"
        "  --frames N      termina apos N quadros (padrao: ate ESC)\n"
        "  --perf ARQ.csv  grava a medicao de desempenho, um registro por segundo\n"
        "  --kbd PATH      teclado (padrao: detecta em /proc/bus/input/devices)\n"
        "  --mouse PATH    mouse (padrao: detecta)\n"
        "controles: setas ou WASD, ou movimento do mouse; ESC sai\n", p);
}

int main(int argc, char **argv)
{
    pac_cfg_t cfg = { 0 };
    const char *csv = NULL, *kbd = NULL, *mouse = NULL;

    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--frames") && i + 1 < argc)      cfg.max_frames = atol(argv[++i]);
        else if (!strcmp(argv[i], "--perf") && i + 1 < argc)   csv = argv[++i];
        else if (!strcmp(argv[i], "--kbd") && i + 1 < argc)    kbd = argv[++i];
        else if (!strcmp(argv[i], "--mouse") && i + 1 < argc)  mouse = argv[++i];
        else { usage(argv[0]); return 2; }
    }

    void *base = hps_open();
    if (!base) { fprintf(stderr, "hps_open falhou (precisa de root para acessar /dev/mem)\n"); return 1; }
    int rc = cop_init(base);
    if (rc == -1)      fprintf(stderr, "ID do coprocessador diferente de 0xC0DE0001: confira a ponte e o bitstream\n");
    else if (rc == -2) fprintf(stderr, "o coprocessador nao ficou pronto (PLL do VGA nao travou?)\n");
    if (rc != 0) { hps_close(base); return 1; }

    rc = pac_load_assets(base);
    if (rc < 0) { fprintf(stderr, "falha ao carregar os recursos (codigo %d)\n", rc); hps_close(base); return 1; }

    input_t in;
    input_init(&in);
    int n = (kbd || mouse) ? input_open_paths(&in, kbd, mouse) : input_open(&in);
    if (n == 0) fprintf(stderr, "aviso: nenhum teclado/mouse aberto (permissao em /dev/input?)\n");

    perf_t perf;
    if (perf_init(&perf, csv) < 0) { fprintf(stderr, "aviso: nao consegui abrir %s; seguindo sem CSV\n", csv ? csv : "(nulo)"); perf_init(&perf, NULL); }

    rc = pac_app_run(base, &in, &perf, &cfg);
    int perf_fail = perf_summary(&perf, stdout);

    perf_close(&perf);
    input_close(&in);
    hps_close(base);
    (void)perf_fail;                      /* o resumo informa; o codigo de saida reflete so erros de execucao */
    return rc == PAC_OK ? 0 : 1;
}
