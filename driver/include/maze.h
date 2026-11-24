/* ============================================================================
 * maze.h - Labirinto: grade logica derivada dos DADOS (pac_assets.h)
 *
 * O jogo nao tem o labirinto em ASCII: a grade logica sai do tilemap e da tabela
 * de classes de tile (pac_maze_tilemap + pac_tile_class), geradas pela ferramenta
 * gen_pac_assets.py. Trocar a arte nao muda a logica enquanto as classes forem
 * as mesmas.
 * ========================================================================== */
#ifndef PAC_MAZE_GUARD_H
#define PAC_MAZE_GUARD_H

#include "pac_assets.h"

#define MAZE_W             PAC_MAZE_W            /* 28 colunas                    */
#define MAZE_H             PAC_MAZE_H            /* 31 linhas                     */
#define MAZE_TILE          8                     /* pixels por tile               */
#define MAZE_PX_W          (MAZE_W * MAZE_TILE)  /* 224                           */
#define MAZE_WRAP_PERIOD   (MAZE_PX_W + 16)      /* periodo do tunel: 240 px      */
#define MAZE_TUNNEL_ROW    PAC_TUNNEL_ROW        /* linha 14                      */

/* Partida do Pac-Man: linha 23, entre as colunas 13 e 14 */
#define MAZE_PAC_START_X   112
#define MAZE_PAC_START_Y   (23 * MAZE_TILE + 4)

#define MAZE_DOT_TOTAL        240
#define MAZE_ENERGIZER_TOTAL  4

/* Classe da celula (tx, ty). Fora do labirinto: parede, exceto o tunel (caminho). */
int maze_class(int tx, int ty);

/* Pac-Man pode entrar na celula? Parede e porta da casa bloqueiam. */
int maze_pac_can_enter(int tx, int ty);

#endif /* PAC_MAZE_GUARD_H */
