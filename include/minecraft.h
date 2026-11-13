#ifndef MINECRAFT_H
#define MINECRAFT_H
#include <stdint.h>
#define MW 64
#define MH 32
#define VW 40
#define VH 30
#define TS 8
#define EMPTY 0
#define GRASS 1
#define DIRT 2
#define STONE 3
#define COAL 4
#define WOOD 5
#define LEAF 6
#define BEDROCK 7

typedef struct { int x,y,vx,vy,on_ground; int selected; unsigned blocks[8]; int score; } Player;
typedef struct { uint8_t map[MH][MW]; Player p; int cam_x,cam_y; uint32_t rng; } Game;
void game_init(Game *g, uint32_t seed);
void game_step(Game *g, int left, int right, int jump);
void game_mine(Game *g, int screen_tx, int screen_ty);
void game_place(Game *g, int screen_tx, int screen_ty);
#endif
