#include "maze.h"

int maze_class(int tx, int ty)
{
    if (ty < 0 || ty >= MAZE_H) return PAC_CLS_WALL;
    if (tx < 0 || tx >= MAZE_W) return (ty == MAZE_TUNNEL_ROW) ? PAC_CLS_PATH : PAC_CLS_WALL;
    return pac_tile_class[pac_maze_tilemap[ty][tx]];
}

int maze_pac_can_enter(int tx, int ty)
{
    int c = maze_class(tx, ty);
    return c != PAC_CLS_WALL && c != PAC_CLS_DOOR;
}
