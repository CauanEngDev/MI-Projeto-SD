/* GERADO por gen_pac_assets.py - nao edite. Arte PROVISORIA. */
#ifndef PAC_ASSETS_H
#define PAC_ASSETS_H
#include <stdint.h>

#define PAC_MAZE_W          28
#define PAC_MAZE_H          31
#define PAC_TUNNEL_ROW      14
#define PAC_N_COLORS        12
#define PAC_N_TILES         42      /* padroes de tile (<= 256) */
#define PAC_N_WALL_TILES    21
#define PAC_N_SPRITES       6      /* padroes de sprite 16x16 (linha a linha) */

/* Indices da paleta 0 */
#define PAC_C_BLACK         0
#define PAC_C_WALL          1
#define PAC_C_DOT           2
#define PAC_C_YELLOW        3
#define PAC_C_WHITE         4
#define PAC_C_DOOR          5
#define PAC_C_ENERGIZER     6   /* cor que pisca (troca de paleta) */

/* Ids fixos de tile */
#define PAC_TILE_BLANK      0
#define PAC_TILE_DOT        1
#define PAC_TILE_ENERGIZER  2
#define PAC_TILE_DOOR       3
#define PAC_TILE_DIGIT0     4      /* 10 digitos seguidos */
#define PAC_TILE_LETTER_S   14
#define PAC_TILE_LETTER_C   15
#define PAC_TILE_LETTER_O   16
#define PAC_TILE_LETTER_R   17
#define PAC_TILE_LETTER_E   18
#define PAC_TILE_LETTER_F   19
#define PAC_TILE_LETTER_P   20

/* Classes de tile: a grade logica do jogo deriva do tilemap por esta tabela */
enum { PAC_CLS_NONE = 0, PAC_CLS_WALL = 1, PAC_CLS_PATH = 2,
       PAC_CLS_DOT = 3, PAC_CLS_ENERGIZER = 4, PAC_CLS_DOOR = 5 };

/* Padroes de sprite do Pac-Man: boca para a direita (0..2) e para cima (3..5);
 * esquerda e baixo vem do flip. Frame 0 = fechado, 1 = meio, 2 = aberto. */
#define PAC_SPR_RIGHT0      0
#define PAC_SPR_UP0         3

extern const uint16_t pac_palette[PAC_N_COLORS];                 /* RGB 9 bits */
extern const uint8_t  pac_tiles[PAC_N_TILES][64];                /* indices de cor, linha a linha */
extern const uint8_t  pac_tile_class[PAC_N_TILES];
extern const uint8_t  pac_maze_tilemap[PAC_MAZE_H][PAC_MAZE_W];  /* tile de cada celula do labirinto */
extern const uint8_t  pac_sprites[PAC_N_SPRITES][256];           /* 16x16 linha a linha */

#endif /* PAC_ASSETS_H */
