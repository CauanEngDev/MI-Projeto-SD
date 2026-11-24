#include "pac_core.h"

#include <string.h>

static const int DX[4] = { 1, 0, -1, 0 };
static const int DY[4] = { 0, 1, 0, -1 };

static dir_t opposite(dir_t d) { return (dir_t)((d + 2) & 3); }
static int mod8(int v)         { int m = v % 8; return m < 0 ? m + 8 : m; }
static int floordiv8(int v)    { return v >= 0 ? v / 8 : -((-v + 7) / 8); }

int pac_speed_for_level(int level)
{
    int pct = (level <= 1) ? 80 : (level <= 4 ? 90 : 100);
    return PAC_SPEED_100 * pct / 100;
}

void pac_init(pac_t *p, int level)
{
    memset(p, 0, sizeof *p);
    p->x = MAZE_PAC_START_X;
    p->y = MAZE_PAC_START_Y;
    p->dir = p->want = DIR_LEFT;
    p->level = level < 1 ? 1 : level;
    p->speed = pac_speed_for_level(p->level);
    p->lives = PAC_START_LIVES;
    for (int y = 0; y < MAZE_H; y++) {
        for (int x = 0; x < MAZE_W; x++) {
            int c = maze_class(x, y);
            if (c == PAC_CLS_DOT)            { p->dots[y][x] = 1; p->dots_left++; }
            else if (c == PAC_CLS_ENERGIZER) { p->dots[y][x] = 2; p->dots_left++; }
        }
    }
}

void pac_respawn(pac_t *p)
{
    p->x = MAZE_PAC_START_X;
    p->y = MAZE_PAC_START_Y;
    p->dir = p->want = DIR_LEFT;
    p->sub = 0;
    p->eat_pause = 0;
    p->moving = 0;
    p->anim = 0;
}

void pac_new_level(pac_t *p, int level)
{
    p->level = level < 1 ? 1 : level;
    memset(p->dots, 0, sizeof p->dots);
    p->dots_left = 0;
    for (int y = 0; y < MAZE_H; y++) {
        for (int x = 0; x < MAZE_W; x++) {
            int c = maze_class(x, y);
            if (c == PAC_CLS_DOT)            { p->dots[y][x] = 1; p->dots_left++; }
            else if (c == PAC_CLS_ENERGIZER) { p->dots[y][x] = 2; p->dots_left++; }
        }
    }
    p->n_ev = 0;
    p->speed = pac_speed_for_level(p->level);
    pac_respawn(p);
}

int pac_anim_frame(const pac_t *p)
{
    static const int seq[4] = { 0, 1, 2, 1 };
    return p->moving ? seq[(p->anim >> 1) & 3] : 1;
}

/* Anda 1 pixel. Devolve 0 se parou (parede, ou parou para comer). */
static int advance_pixel(pac_t *p)
{
    if (mod8(p->x) == 4 && mod8(p->y) == 4) {              /* centro de um tile: ponto de decisao */
        int tx = floordiv8(p->x), ty = floordiv8(p->y);

        if (tx >= 0 && tx < MAZE_W && ty >= 0 && ty < MAZE_H && p->dots[ty][tx]) {
            uint8_t kind = p->dots[ty][tx];
            p->dots[ty][tx] = 0;
            p->dots_left--;
            p->score += (kind == 2) ? 50 : 10;
            if (kind == 2) p->n_ener_eaten++; else p->n_dots_eaten++;
            if (p->n_ev < PAC_EV_MAX) {
                p->ev[p->n_ev].x = (uint8_t)tx; p->ev[p->n_ev].y = (uint8_t)ty; p->ev[p->n_ev].kind = kind;
                p->n_ev++;
            }
            p->eat_pause = (kind == 2) ? 3 : 1;             /* Pac-Man para: 1 quadro (ponto), 3 (energizer) */
        }
        if (p->want != DIR_NONE && p->want != p->dir &&
            maze_pac_can_enter(tx + DX[p->want], ty + DY[p->want]))
            p->dir = p->want;                               /* curva so nos centros */
        if (!maze_pac_can_enter(tx + DX[p->dir], ty + DY[p->dir])) return 0;   /* parede */
        if (p->eat_pause > 0) return 0;
    }
    p->x += DX[p->dir];
    p->y += DY[p->dir];
    if (p->x < -8)                     p->x += MAZE_WRAP_PERIOD;   /* tunel: reaparece do outro lado */
    else if (p->x >= MAZE_PX_W + 8)    p->x -= MAZE_WRAP_PERIOD;
    return 1;
}

void pac_step(pac_t *p, dir_t want)
{
    p->frame++;
    if (want != DIR_NONE) p->want = want;
    p->moving = 0;
    if (p->eat_pause > 0) { p->eat_pause--; return; }

    if (p->want != DIR_NONE && p->want == opposite(p->dir))
        p->dir = p->want;                                   /* inverter vale em qualquer ponto */

    p->sub += p->speed;
    int n = p->sub >> 8;
    p->sub &= 255;
    for (int i = 0; i < n; i++) {
        if (!advance_pixel(p)) break;
        p->moving = 1;
    }
    if (p->moving) p->anim++;
}
