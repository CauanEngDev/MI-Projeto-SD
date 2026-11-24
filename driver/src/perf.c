#define _POSIX_C_SOURCE 200809L
#include "perf.h"

#include <stdlib.h>
#include <string.h>
#include <time.h>

#define SCAN_MS   16.7        /* varredura do VGA: ate 1 quadro depois da troca de buffer */

static double ts(clockid_t c) { struct timespec t; clock_gettime(c, &t); return (double)t.tv_sec + (double)t.tv_nsec * 1e-9; }
static double def_mono(void *c)   { (void)c; return ts(CLOCK_MONOTONIC); }
static double def_real(void *c)   { (void)c; return ts(CLOCK_REALTIME); }
static double def_cpup(void *c)   { (void)c; return ts(CLOCK_PROCESS_CPUTIME_ID); }
static double def_cput(void *c)   { (void)c; return ts(CLOCK_THREAD_CPUTIME_ID); }

int perf_init(perf_t *p, const char *csv_path)
{
    memset(p, 0, sizeof *p);
    p->clk.mono = def_mono; p->clk.real = def_real; p->clk.cpu_proc = def_cpup; p->clk.cpu_thread = def_cput;
    p->period_ms = malloc(sizeof(float) * PERF_MAX_SAMPLES);
    p->lat_ms    = malloc(sizeof(float) * PERF_MAX_SAMPLES);
    if (!p->period_ms || !p->lat_ms) { free(p->period_ms); free(p->lat_ms); p->period_ms = p->lat_ms = NULL; return -1; }
    p->min_fps = 1e9; p->min_steps_s = 1e9;
    if (csv_path) {
        p->csv = fopen(csv_path, "w");
        if (!p->csv) return -1;
        fprintf(p->csv, "t_s,fps,logic_steps_s,push_ms_avg,push_ms_max,present_wait_ms_avg,present_wait_ms_max,"
                        "input_frames,input_latency_ms_avg,input_latency_ms_max,cpu_pct,cpu_excl_present_pct\n");
    }
    return 0;
}

void perf_set_clock(perf_t *p, const perf_clock_t *clk) { p->clk = *clk; }

void perf_start(perf_t *p)
{
    p->t_run0 = p->t_last = p->t_sec0 = p->t_prev_present = p->clk.mono(p->clk.ctx);
    p->cpu_run0 = p->cpu_sec0 = p->clk.cpu_proc(p->clk.ctx);
}

void perf_frame_begin(perf_t *p) { p->t_frame0 = p->clk.mono(p->clk.ctx); }
void perf_add_steps(perf_t *p, int steps) { p->s_steps += steps; p->steps += steps; }

void perf_push_done(perf_t *p)
{
    p->t_push_end = p->clk.mono(p->clk.ctx);
    p->cpu_thr_push_end = p->clk.cpu_thread(p->clk.ctx);
}

static void roll_second(perf_t *p, double t)
{
    double dt = t - p->t_sec0;
    if (dt <= 0.0) return;
    double fps = (double)p->s_frames / dt, sps = (double)p->s_steps / dt;
    double cpu = p->clk.cpu_proc(p->clk.ctx), dcpu = cpu - p->cpu_sec0;
    double cpu_pct = dcpu / dt * 100.0, excl = (dcpu - p->s_cpu_present) / dt * 100.0;
    if (excl < 0.0) excl = 0.0;
    p->last_fps = fps;
    p->n_secs++;
    if (fps < p->min_fps) p->min_fps = fps;
    if (sps < p->min_steps_s) p->min_steps_s = sps;
    if (p->csv) {
        double n = p->s_frames ? (double)p->s_frames : 1.0;
        fprintf(p->csv, "%.1f,%.1f,%.1f,%.3f,%.3f,%.3f,%.3f,%ld,", t - p->t_run0, fps, sps,
                p->s_push_sum / n * 1e3, p->s_push_max * 1e3, p->s_wait_sum / n * 1e3, p->s_wait_max * 1e3, p->s_lat_n);
        if (p->s_lat_n) fprintf(p->csv, "%.3f,%.3f,", p->s_lat_sum / (double)p->s_lat_n, p->s_lat_max);
        else            fprintf(p->csv, ",,");
        fprintf(p->csv, "%.1f,%.1f\n", cpu_pct, excl);
        fflush(p->csv);
    }
    p->t_sec0 = t; p->cpu_sec0 = cpu;
    p->s_frames = p->s_steps = p->s_lat_n = 0;
    p->s_push_sum = p->s_push_max = p->s_wait_sum = p->s_wait_max = 0.0;
    p->s_lat_sum = p->s_lat_max = p->s_cpu_present = 0.0;
}

void perf_present_done(perf_t *p, double event_time)
{
    double t = p->clk.mono(p->clk.ctx), real = p->clk.real(p->clk.ctx);
    double push = p->t_push_end - p->t_frame0, wait = t - p->t_push_end;
    double cpu_present = p->clk.cpu_thread(p->clk.ctx) - p->cpu_thr_push_end;
    if (cpu_present < 0.0) cpu_present = 0.0;

    if (p->have_prev && p->n_period < PERF_MAX_SAMPLES) p->period_ms[p->n_period++] = (float)((t - p->t_prev_present) * 1e3);
    p->t_prev_present = t; p->have_prev = 1; p->t_last = t;

    p->frames++; p->s_frames++;
    p->s_push_sum += push; p->push_sum += push;
    if (push > p->s_push_max) p->s_push_max = push;
    if (push > p->push_max) p->push_max = push;
    p->s_wait_sum += wait; p->wait_sum += wait;
    if (wait > p->s_wait_max) p->s_wait_max = wait;
    if (wait > p->wait_max) p->wait_max = wait;
    p->s_cpu_present += cpu_present; p->cpu_present_sum += cpu_present;

    if (event_time > 0.0) {
        double lat = (real - event_time) * 1e3;
        if (lat < 0.0) lat = 0.0;
        p->lat_frames++; p->s_lat_n++; p->s_lat_sum += lat;
        if (lat > p->s_lat_max) p->s_lat_max = lat;
        if (p->n_lat < PERF_MAX_SAMPLES) p->lat_ms[p->n_lat++] = (float)lat;
    }
    if (t - p->t_sec0 >= 1.0) roll_second(p, t);
}

int perf_fps(const perf_t *p) { return (int)(p->last_fps + 0.5); }

static int cmp_f(const void *a, const void *b) { float x = *(const float *)a, y = *(const float *)b; return (x > y) - (x < y); }

/* Percentil (p em 0..1) sobre uma copia ordenada. */
static double pct(const float *v, long n, double p)
{
    if (n <= 0) return 0.0;
    float *c = malloc(sizeof(float) * (size_t)n);
    if (!c) return 0.0;
    memcpy(c, v, sizeof(float) * (size_t)n);
    qsort(c, (size_t)n, sizeof(float), cmp_f);
    double pos = p * (double)n;
    long i = (long)pos;
    if ((double)i < pos) i++;                    /* teto, sem libm */
    i -= 1;
    if (i < 0) i = 0;
    if (i >= n) i = n - 1;
    double r = c[i];
    free(c);
    return r;
}

int perf_summary(const perf_t *p, FILE *out)
{
    double dur = p->t_last - p->t_run0;
    if (dur <= 0.0) dur = 1e-9;
    double cpu_tot = p->clk.cpu_proc(p->clk.ctx) - p->cpu_run0;
    fprintf(out, "\n== Resumo de desempenho ==\n");
    fprintf(out, "quadros: %ld em %.2f s (media %.1f quadros/s) | passos de logica: %ld (%.1f por s)\n",
            p->frames, dur, (double)p->frames / dur, p->steps, (double)p->steps / dur);
    fprintf(out, "periodo entre quadros (ms): p50 %.2f | p95 %.2f | p99 %.2f | max %.2f\n",
            pct(p->period_ms, p->n_period, 0.50), pct(p->period_ms, p->n_period, 0.95),
            pct(p->period_ms, p->n_period, 0.99), pct(p->period_ms, p->n_period, 1.0));
    fprintf(out, "envio dos comandos por quadro (ms): media %.3f | max %.3f\n",
            p->frames ? p->push_sum / (double)p->frames * 1e3 : 0.0, p->push_max * 1e3);
    fprintf(out, "espera do vblank por quadro (ms): media %.3f | max %.3f\n",
            p->frames ? p->wait_sum / (double)p->frames * 1e3 : 0.0, p->wait_max * 1e3);
    double l99 = pct(p->lat_ms, p->n_lat, 0.99), lmax = pct(p->lat_ms, p->n_lat, 1.0);
    if (p->n_lat)
        fprintf(out, "latencia entrada -> troca de buffer (ms), %ld quadros com entrada: p50 %.2f | p95 %.2f | p99 %.2f | max %.2f\n",
                p->lat_frames, pct(p->lat_ms, p->n_lat, 0.50), pct(p->lat_ms, p->n_lat, 0.95), l99, lmax);
    else
        fprintf(out, "latencia entrada -> troca de buffer: sem eventos de entrada durante a medicao\n");
    fprintf(out, "CPU: %.1f%% do tempo total | %.1f%% sem a espera ativa do vblank\n",
            cpu_tot / dur * 100.0, (cpu_tot - p->cpu_present_sum) / dur * 100.0);

    int fail = 0;
    if (p->n_secs > 0) {
        int ok = p->min_fps >= 30.0 && p->min_steps_s >= 30.0;
        fprintf(out, "[%s] >= 30 atualizacoes/s: minimo por segundo = %.1f quadros/s e %.1f passos/s (%ld segundos completos)\n",
                ok ? "OK    " : "FALHOU", p->min_fps, p->min_steps_s, p->n_secs);
        fail |= !ok;
    } else {
        fprintf(out, "[------] >= 30 atualizacoes/s: a medicao durou menos de 1 s\n");
    }
    if (p->n_lat) {
        int ok = l99 + SCAN_MS <= 100.0;
        fprintf(out, "[%s] latencia <= 100 ms: p99 %.1f ms ate a troca de buffer + ate %.1f ms de varredura = %.1f ms\n",
                ok ? "OK    " : "FALHOU", l99, SCAN_MS, l99 + SCAN_MS);
        fail |= !ok;
    }
    return fail;
}

void perf_close(perf_t *p)
{
    if (p->csv) fclose(p->csv);
    free(p->period_ms); free(p->lat_ms);
    p->csv = NULL; p->period_ms = p->lat_ms = NULL;
}
