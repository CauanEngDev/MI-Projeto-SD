#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "acel.h"
#include "app.h"
#include "cop_api.h"
#include "game.h"
#include "input.h"

static void usage(const char *p)
{
    fprintf(stderr,
        "uso: %s [opcoes]\n"
        "  --frames N     termina apos N quadros (padrao: ate ESC)\n"
        "  --no-accel     nao usa o acelerometro\n"
        "  --i2c DEV      barramento do ADXL345 (padrao: procura /dev/i2c-0..3)\n"
        "  --flip         inverte o sentido da inclinacao\n"
        "  --kbd PATH     teclado (padrao: detecta em /proc/bus/input/devices)\n"
        "  --mouse PATH   mouse (padrao: detecta)\n"
        "  -v             imprime a taxa de quadros\n", p);
}

int main(int argc, char **argv)
{
    app_cfg_t cfg = { .max_frames = 0, .tilt_sign = 1, .verbose = 0 };
    int use_accel = 1;
    const char *i2c = NULL, *kbd = NULL, *mouse = NULL;

    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--frames") && i + 1 < argc)      cfg.max_frames = atol(argv[++i]);
        else if (!strcmp(argv[i], "--no-accel"))               use_accel = 0;
        else if (!strcmp(argv[i], "--i2c") && i + 1 < argc)    i2c = argv[++i];
        else if (!strcmp(argv[i], "--flip"))                   cfg.tilt_sign = -1;
        else if (!strcmp(argv[i], "--kbd") && i + 1 < argc)    kbd = argv[++i];
        else if (!strcmp(argv[i], "--mouse") && i + 1 < argc)  mouse = argv[++i];
        else if (!strcmp(argv[i], "-v"))                       cfg.verbose = 1;
        else { usage(argv[0]); return 2; }
    }
    cfg.seed = (uint32_t)time(NULL) ^ ((uint32_t)getpid() << 16);

    /* Ponte lightweight e coprocessador */
    void *base = hps_open();
    if (!base) { fprintf(stderr, "hps_open falhou (precisa de root para acessar /dev/mem)\n"); return 1; }
    int rc = cop_init(base);
    if (rc == -1)      fprintf(stderr, "ID do coprocessador diferente de 0xC0DE0001: confira a ponte e o bitstream\n");
    else if (rc == -2) fprintf(stderr, "o coprocessador nao ficou pronto (PLL do VGA nao travou?)\n");
    if (rc != 0) { hps_close(base); return 1; }

    rc = game_load_assets(base);
    if (rc < 0) { fprintf(stderr, "falha ao carregar os recursos (codigo %d)\n", rc); hps_close(base); return 1; }

    /* Entradas: teclado/mouse sao opcionais; o acelerometro tambem */
    input_t in;
    input_init(&in);                       /* input_open_paths exige estado inicializado */
    int n = (kbd || mouse) ? input_open_paths(&in, kbd, mouse) : input_open(&in);
    if (n == 0) fprintf(stderr, "aviso: nenhum teclado/mouse aberto (permissao em /dev/input?)\n");

    acel_t ac; memset(&ac, 0, sizeof ac); ac.fd = -1;
    if (use_accel) {
        int ar = acel_open(&ac, i2c);
        if (ar != ACEL_OK)
            fprintf(stderr, "aviso: acelerometro indisponivel (codigo %d); confira o i2c-dev e o sinal HPS_I2C_CONTROL\n", ar);
    }

    rc = app_run(base, &in, &ac, &cfg);

    acel_close(&ac);
    input_close(&in);
    hps_close(base);
    return rc == APP_OK ? 0 : 1;
}