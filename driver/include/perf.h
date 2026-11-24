/* ============================================================================
 * perf.h - Medicao de desempenho do laco do jogo
 *
 * Mede, por quadro e por segundo:
 *   - taxa de quadros apresentados e de passos de logica;
 *   - tempo de envio dos comandos do quadro (inclui a espera por fila cheia);
 *   - tempo de espera do vblank em cop_present;
 *   - latencia da entrada (instante do evento do kernel) ate a troca de buffer;
 *   - uso de CPU, com e sem a espera ativa do vblank.
 * Grava um CSV por segundo e imprime um resumo com a checagem dos requisitos
 * (30 quadros/s e 100 ms de latencia).
 * ========================================================================== */
#ifndef PERF_H
#define PERF_H

#include <stdio.h>

/* Relogios substituiveis (testes). Tempos em segundos. */
typedef struct perf_clock {
    double (*mono)(void *ctx);         /* CLOCK_MONOTONIC                   */
    double (*real)(void *ctx);         /* CLOCK_REALTIME (base dos eventos) */
    double (*cpu_proc)(void *ctx);     /* tempo de CPU do processo          */
    double (*cpu_thread)(void *ctx);   /* tempo de CPU da thread            */
    void   *ctx;
} perf_clock_t;

#define PERF_MAX_SAMPLES   200000      /* amostras guardadas para os percentis */

typedef struct {
    perf_clock_t clk;
    FILE  *csv;
    int    have_prev;
    double t_run0, t_last, t_sec0, t_frame0, t_push_end, t_prev_present;
    double cpu_sec0, cpu_run0, cpu_thr_push_end;

    long   s_frames, s_steps, s_lat_n;                       /* segundo corrente */
    double s_push_sum, s_push_max, s_wait_sum, s_wait_max;
    double s_lat_sum, s_lat_max, s_cpu_present;
    double last_fps;

    long   frames, steps, lat_frames, n_secs;                /* totais */
    double push_sum, push_max, wait_sum, wait_max, cpu_present_sum;
    double min_fps, min_steps_s;

    float *period_ms; long n_period;                         /* amostras */
    float *lat_ms;    long n_lat;
} perf_t;

/* csv_path pode ser NULL (sem CSV). Devolve 0, ou -1 se nao conseguiu abrir/alocar. */
int  perf_init(perf_t *p, const char *csv_path);

/* Troca os relogios (chame antes de perf_start). */
void perf_set_clock(perf_t *p, const perf_clock_t *clk);

void perf_start(perf_t *p);                       /* inicio da execucao                  */
void perf_frame_begin(perf_t *p);                 /* inicio de um quadro                 */
void perf_add_steps(perf_t *p, int steps);        /* passos de logica executados         */
void perf_push_done(perf_t *p);                   /* comandos enviados; vai chamar present */
/* cop_present voltou. event_time = instante (CLOCK_REALTIME, s) do evento de entrada
 * mais antigo consumido neste quadro, ou 0 se nao houve. */
void perf_present_done(perf_t *p, double event_time);

int  perf_fps(const perf_t *p);                   /* fps do ultimo segundo completo      */

/* Resumo final. Devolve 0 se os dois requisitos foram atendidos, 1 se algum falhou. */
int  perf_summary(const perf_t *p, FILE *out);
void perf_close(perf_t *p);

#endif /* PERF_H */
