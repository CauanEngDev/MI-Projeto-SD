#define _GNU_SOURCE
#include "input.h"

#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>   /* struct input_event, EV_*, KEY_*, BTN_*, REL_* */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* Limite de eventos lidos por dispositivo em cada input_poll: um mouse muito
 * rapido nao pode atrasar o quadro; o resto fica para o proximo poll. */
#define MAX_EVENTS_PER_POLL  256

/* ----------------------------------------------------------------------------
 * Teclas fisicas -> bits internos -> teclas logicas
 * -------------------------------------------------------------------------- */
enum { P_LEFT = 0, P_A, P_RIGHT, P_D, P_SPACE, P_ENTER, P_ESC };

static int phys_bit(uint16_t code)
{
    switch (code) {
    case KEY_LEFT:  return P_LEFT;
    case KEY_A:     return P_A;
    case KEY_RIGHT: return P_RIGHT;
    case KEY_D:     return P_D;
    case KEY_SPACE: return P_SPACE;
    case KEY_ENTER: return P_ENTER;
    case KEY_ESC:   return P_ESC;
    default:        return -1;
    }
}

static uint32_t phys_to_keys(uint32_t p)
{
    uint32_t k = 0;
    if (p & ((1u << P_LEFT)  | (1u << P_A)))     k |= INPUT_LEFT;
    if (p & ((1u << P_RIGHT) | (1u << P_D)))     k |= INPUT_RIGHT;
    if (p & ((1u << P_SPACE) | (1u << P_ENTER))) k |= INPUT_ACTION;
    if (p & (1u << P_ESC))                       k |= INPUT_QUIT;
    return k;
}

static int clampi(int v, int lo, int hi) { return v < lo ? lo : (v > hi ? hi : v); }

/* ----------------------------------------------------------------------------
 * Estado
 * -------------------------------------------------------------------------- */
void input_init(input_t *in)
{
    memset(in, 0, sizeof *in);
    for (int i = 0; i < INPUT_MAX_DEVS; i++) in->kbd_fd[i] = in->mouse_fd[i] = -1;
    in->mouse_x = INPUT_SCREEN_W / 2;
    in->mouse_y = INPUT_SCREEN_H / 2;
    in->mouse_gain = 1;
}

static void handle_event(input_t *in, const struct input_event *ev)
{
    if (ev->type == EV_KEY) {
        if (ev->code == BTN_LEFT || ev->code == BTN_RIGHT) {
            uint32_t bit = (ev->code == BTN_LEFT) ? INPUT_MOUSE_LEFT : INPUT_MOUSE_RIGHT;
            if (ev->value) in->buttons |= bit; else in->buttons &= ~bit;
            if (ev->value == 1) in->button_edges |= bit;
        } else {
            int b = phys_bit(ev->code);
            if (b < 0) return;
            if (ev->value) in->phys |= 1u << b; else in->phys &= ~(1u << b);
            if (ev->value == 1)                   /* 2 = repeticao: nao e borda */
                in->key_edges |= phys_to_keys(1u << b);
        }
    } else if (ev->type == EV_REL) {
        if (ev->code == REL_X)
            in->mouse_x = clampi(in->mouse_x + ev->value * in->mouse_gain, 0, INPUT_SCREEN_W - 1);
        else if (ev->code == REL_Y)
            in->mouse_y = clampi(in->mouse_y + ev->value * in->mouse_gain, 0, INPUT_SCREEN_H - 1);
    }
}

/* ----------------------------------------------------------------------------
 * Abertura
 * -------------------------------------------------------------------------- */
static int add_dev(int *fds, int *n, const char *path)
{
    if (*n >= INPUT_MAX_DEVS) return -1;
    int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) return -1;
    fds[(*n)++] = fd;
    return 0;
}

int input_open_paths(input_t *in, const char *kbd_path, const char *mouse_path)
{
    int opened = 0;
    if (kbd_path   && add_dev(in->kbd_fd,   &in->n_kbd,   kbd_path)   == 0) opened++;
    if (mouse_path && add_dev(in->mouse_fd, &in->n_mouse, mouse_path) == 0) opened++;
    return opened;
}

/* Um bloco de /proc/bus/input/devices descreve um dispositivo:
 *   H: Handlers=sysrq kbd event3 leds
 *   B: EV=120013
 * Teclado = handler "kbd" e EV_REP (bit 20); mouse = handler "mouse" e EV_REL (bit 2).
 * Isso descarta botoes de energia (kbd sem repeticao) e touchpads sem "mouse". */
typedef struct { int kbd, mouse, event; unsigned long long ev; } block_t;

static void block_reset(block_t *b) { b->kbd = b->mouse = 0; b->event = -1; b->ev = 0; }

static void block_finish(const block_t *b, input_t *in, const char *dev_dir, int *opened)
{
    if (b->event < 0) return;
    int is_kbd   = b->kbd   && (b->ev & (1ull << EV_REP));
    int is_mouse = b->mouse && (b->ev & (1ull << EV_REL));
    if (!is_kbd && !is_mouse) return;
    char path[256];
    snprintf(path, sizeof path, "%s/event%d", dev_dir, b->event);
    if (is_kbd   && add_dev(in->kbd_fd,   &in->n_kbd,   path) == 0) (*opened)++;
    if (is_mouse && add_dev(in->mouse_fd, &in->n_mouse, path) == 0) (*opened)++;
}

int input_open_proc(input_t *in, const char *proc_devices, const char *dev_dir)
{
    input_init(in);
    FILE *f = fopen(proc_devices, "r");
    if (!f) return 0;

    block_t b; block_reset(&b);
    int opened = 0;
    char line[512];
    while (fgets(line, sizeof line, f)) {
        if (line[0] == '\n' || line[0] == '\r' || line[0] == '\0') {   /* fim do bloco */
            block_finish(&b, in, dev_dir, &opened);
            block_reset(&b);
        } else if (strncmp(line, "H: Handlers=", 12) == 0) {
            char *save = NULL;
            for (char *t = strtok_r(line + 12, " \t\r\n", &save); t; t = strtok_r(NULL, " \t\r\n", &save)) {
                if (strcmp(t, "kbd") == 0)                        b.kbd = 1;
                else if (strncmp(t, "mouse", 5) == 0)             b.mouse = 1;
                else if (strncmp(t, "event", 5) == 0 && t[5] >= '0' && t[5] <= '9')
                    b.event = atoi(t + 5);
            }
        } else if (strncmp(line, "B: EV=", 6) == 0) {
            b.ev = strtoull(line + 6, NULL, 16);
        }
    }
    block_finish(&b, in, dev_dir, &opened);     /* ultimo bloco sem linha em branco */
    fclose(f);
    return opened;
}

int input_open(input_t *in)
{
    return input_open_proc(in, "/proc/bus/input/devices", "/dev/input");
}

/* ----------------------------------------------------------------------------
 * Leitura
 * -------------------------------------------------------------------------- */
static int drain(input_t *in, int *fd)
{
    struct input_event ev;
    int count = 0;
    while (*fd >= 0 && count < MAX_EVENTS_PER_POLL) {
        ssize_t n = read(*fd, &ev, sizeof ev);
        if (n == (ssize_t)sizeof ev) { handle_event(in, &ev); count++; continue; }
        if (n < 0 && errno == EINTR) continue;
        if (n < 0 && errno == ENODEV) { close(*fd); *fd = -1; }   /* desconectado */
        break;      /* EAGAIN (sem eventos), fim de arquivo ou leitura parcial */
    }
    return count;
}

int input_poll(input_t *in)
{
    int total = 0;
    in->key_edges = 0;
    in->button_edges = 0;
    for (int i = 0; i < in->n_kbd; i++)   total += drain(in, &in->kbd_fd[i]);
    for (int i = 0; i < in->n_mouse; i++) total += drain(in, &in->mouse_fd[i]);
    in->keys = phys_to_keys(in->phys);
    return total;
}

void input_close(input_t *in)
{
    for (int i = 0; i < in->n_kbd; i++)   if (in->kbd_fd[i]   >= 0) close(in->kbd_fd[i]);
    for (int i = 0; i < in->n_mouse; i++) if (in->mouse_fd[i] >= 0) close(in->mouse_fd[i]);
    input_init(in);
}