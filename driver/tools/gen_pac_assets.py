#!/usr/bin/env python3
"""gen_pac_assets.py - gera os dados graficos do jogo (ARTE PROVISORIA).

Entrada : maze.txt  (labirinto 28 x 31 em ASCII, a fonte de verdade da estrutura)
Saida   : pac_assets.h e pac_assets_data.c  (tiles, tilemap, classes de tile,
          padroes de sprite e paleta, prontos para o jogo carregar)

O jogo NAO gera arte em tempo de execucao: so carrega estes dados. Para trocar a
arte provisoria pela definitiva, substitua a etapa "arte" (funcoes build_*) por
uma leitura de PNG; o formato de saida (e o jogo) nao mudam.

Legenda do maze.txt:  # parede   . ponto   o energizer   - porta   ' ' caminho

Uso:  python3 gen_pac_assets.py [--maze maze.txt] [--out-dir .] [--preview out.png]
"""
import argparse
import sys
from collections import deque

W, H = 28, 31                     # labirinto original
TUNNEL_ROW = 14

# ----------------------------------------------------------------------------
# Paleta 0 (9 bits: 3 bits por canal). Indice 0 e transparente nos sprites.
# ----------------------------------------------------------------------------
PALETTE = [
    ("preto",            (0, 0, 0)),   # 0
    ("parede azul",      (1, 1, 7)),   # 1
    ("ponto",            (7, 5, 5)),   # 2
    ("amarelo",          (7, 7, 0)),   # 3
    ("branco",           (7, 7, 7)),   # 4
    ("porta rosa",       (7, 5, 6)),   # 5
    ("energizer",        (7, 5, 5)),   # 6 (pisca por troca de paleta)
    ("vermelho",         (7, 0, 0)),   # 7 (reservado: fantasmas)
    ("rosa",             (7, 4, 6)),   # 8
    ("ciano",            (0, 7, 7)),   # 9
    ("laranja",          (7, 5, 0)),   # 10
    ("assustado",        (1, 1, 7)),   # 11
]
C_BLACK, C_WALL, C_DOT, C_YELLOW, C_WHITE, C_DOOR, C_ENERGIZER = 0, 1, 2, 3, 4, 5, 6

# Classes de tile (o jogo deriva a grade logica do tilemap por esta tabela)
CLS_NONE, CLS_WALL, CLS_PATH, CLS_DOT, CLS_ENERGIZER, CLS_DOOR = 0, 1, 2, 3, 4, 5

# Ids fixos de tile
T_BLANK, T_DOT, T_ENERGIZER, T_DOOR = 0, 1, 2, 3
T_DIGIT0 = 4                                   # 4..13
LETTERS = "SCOREFP"                            # 14..20
T_LETTER0 = 14
T_WALL0 = 21                                   # paredes a partir daqui

FONT_DIGITS = [                                # 8x8, bit 7 = pixel da esquerda
    (0x3C, 0x66, 0x6E, 0x76, 0x66, 0x66, 0x3C, 0x00),
    (0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00),
    (0x3C, 0x66, 0x06, 0x0C, 0x18, 0x30, 0x7E, 0x00),
    (0x3C, 0x66, 0x06, 0x1C, 0x06, 0x66, 0x3C, 0x00),
    (0x0C, 0x1C, 0x3C, 0x6C, 0x7E, 0x0C, 0x0C, 0x00),
    (0x7E, 0x60, 0x7C, 0x06, 0x06, 0x66, 0x3C, 0x00),
    (0x1C, 0x30, 0x60, 0x7C, 0x66, 0x66, 0x3C, 0x00),
    (0x7E, 0x06, 0x0C, 0x18, 0x30, 0x30, 0x30, 0x00),
    (0x3C, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x3C, 0x00),
    (0x3C, 0x66, 0x66, 0x3E, 0x06, 0x0C, 0x38, 0x00),
]
GLYPHS = {                                     # letras 5x7
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
}


# ----------------------------------------------------------------------------
# Leitura e validacao do labirinto
# ----------------------------------------------------------------------------
def load_maze(path):
    rows = [l.rstrip("\n") for l in open(path, encoding="utf-8")]
    rows = [r for r in rows if r != ""] if len(rows) > H else rows
    return rows


def validate_maze(rows):
    errs = []
    if len(rows) != H:
        errs.append(f"o labirinto tem {len(rows)} linhas (esperado {H})")
    for i, r in enumerate(rows):
        if len(r) != W:
            errs.append(f"linha {i} tem {len(r)} colunas (esperado {W})")
        bad = set(r) - set("#.o- ")
        if bad:
            errs.append(f"linha {i} tem caracteres invalidos: {sorted(bad)}")
    if errs:
        return errs
    dots = sum(r.count(".") for r in rows)
    ener = sum(r.count("o") for r in rows)
    if dots != 240 or ener != 4:
        errs.append(f"{dots} pontos e {ener} energizers (esperado 240 e 4)")
    for i, r in enumerate(rows):
        if r != r[::-1]:
            errs.append(f"linha {i} nao e simetrica esquerda-direita")
    doors = [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "-"]
    if len(doors) != 2 or any(y != 12 for _, y in doors):
        errs.append(f"a porta da casa deve ter 2 celulas na linha 12: {doors}")
    row14 = rows[TUNNEL_ROW]
    if not (row14[:6].strip() == "" and row14[-6:].strip() == ""):
        errs.append("o tunel (linha 14, 6 colunas de cada lado) deve estar livre")
    cells = {(x, y) for y in range(H) for x in range(W) if rows[y][x] != "#"}
    start = (13, 23)
    seen, q = {start}, deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if ny == TUNNEL_ROW:
                nx %= W
            if (nx, ny) in cells and (nx, ny) not in seen:
                seen.add((nx, ny)); q.append((nx, ny))
    if cells - seen:
        errs.append(f"{len(cells - seen)} celulas desconectadas: {sorted(cells - seen)[:5]}")
    return errs


# ----------------------------------------------------------------------------
# Arte provisoria
# ----------------------------------------------------------------------------
def blank_tile():
    return [0] * 64


def build_dot():
    t = blank_tile()
    for y in (3, 4):
        for x in (3, 4):
            t[y * 8 + x] = C_DOT
    return t


def build_energizer():
    t = blank_tile()
    for y in range(8):
        for x in range(8):
            if (x - 3.5) ** 2 + (y - 3.5) ** 2 <= 3.3 ** 2:
                t[y * 8 + x] = C_ENERGIZER
    return t


def build_door():
    t = blank_tile()
    for y in (3, 4):
        for x in range(8):
            t[y * 8 + x] = C_DOOR
    return t


def build_digit(d):
    t = blank_tile()
    for y in range(8):
        for x in range(8):
            if FONT_DIGITS[d][y] & (0x80 >> x):
                t[y * 8 + x] = C_WHITE
    return t


def build_letter(ch):
    t = blank_tile()
    for y, row in enumerate(GLYPHS[ch]):
        for x, c in enumerate(row):
            if c == "#":
                t[y * 8 + x + 1] = C_WHITE
    return t


def wall_key(rows, x, y):
    """(bordas abertas N,E,S,W ; cantos concavos NE,SE,SW,NW). Fora do mapa conta como parede."""
    def wall(cx, cy):
        if cy < 0 or cy >= H or cx < 0 or cx >= W:
            return True
        return rows[cy][cx] == "#"
    n, e, s, w = (not wall(x, y - 1)), (not wall(x + 1, y)), (not wall(x, y + 1)), (not wall(x - 1, y))
    ne = wall(x, y - 1) and wall(x + 1, y) and not wall(x + 1, y - 1)
    se = wall(x, y + 1) and wall(x + 1, y) and not wall(x + 1, y + 1)
    sw = wall(x, y + 1) and wall(x - 1, y) and not wall(x - 1, y + 1)
    nw = wall(x, y - 1) and wall(x - 1, y) and not wall(x - 1, y - 1)
    return (n, e, s, w, ne, se, sw, nw)


def build_wall(key):
    """Contorno azul de 2 px nas bordas que dao para caminho; interior preto."""
    n, e, s, w, ne, se, sw, nw = key
    t = blank_tile()

    def box(x0, x1, y0, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                t[y * 8 + x] = C_WALL
    if n: box(0, 7, 0, 1)
    if s: box(0, 7, 6, 7)
    if w: box(0, 1, 0, 7)
    if e: box(6, 7, 0, 7)
    if ne: box(6, 7, 0, 1)
    if se: box(6, 7, 6, 7)
    if sw: box(0, 1, 6, 7)
    if nw: box(0, 1, 0, 1)
    return t


def build_pac(up, frame):
    """Pac-Man 16x16 procedural. up=False: boca para a direita; up=True: para cima.
    frame 0 = fechado, 1 = meio aberto, 2 = aberto. Esquerda/baixo saem por flip."""
    tan = (0.0, 0.4142, 1.0)[frame]
    lin = [0] * 256
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - 8.0, y + 0.5 - 8.0
            if dx * dx + dy * dy > 7.0 * 7.0:
                continue
            if frame > 0:
                if not up and dx > 0 and abs(dy) <= dx * tan:
                    continue
                if up and dy < 0 and abs(dx) <= (-dy) * tan:
                    continue
            lin[y * 16 + x] = C_YELLOW
    return lin


# ----------------------------------------------------------------------------
# Montagem dos dados
# ----------------------------------------------------------------------------
def build_all(rows):
    tiles = [None] * T_WALL0
    tiles[T_BLANK] = blank_tile()
    tiles[T_DOT] = build_dot()
    tiles[T_ENERGIZER] = build_energizer()
    tiles[T_DOOR] = build_door()
    for d in range(10):
        tiles[T_DIGIT0 + d] = build_digit(d)
    for i, ch in enumerate(LETTERS):
        tiles[T_LETTER0 + i] = build_letter(ch)

    classes = [CLS_NONE] * T_WALL0
    classes[T_BLANK] = CLS_PATH
    classes[T_DOT] = CLS_DOT
    classes[T_ENERGIZER] = CLS_ENERGIZER
    classes[T_DOOR] = CLS_DOOR

    wall_ids = {}
    tilemap = [[T_BLANK] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            c = rows[y][x]
            if c == "#":
                k = wall_key(rows, x, y)
                if k not in wall_ids:
                    wall_ids[k] = len(tiles)
                    tiles.append(build_wall(k))
                    classes.append(CLS_WALL)
                tilemap[y][x] = wall_ids[k]
            elif c == ".":
                tilemap[y][x] = T_DOT
            elif c == "o":
                tilemap[y][x] = T_ENERGIZER
            elif c == "-":
                tilemap[y][x] = T_DOOR
    if len(tiles) > 256:
        raise SystemExit(f"{len(tiles)} tiles: passa do limite de 256 da Tile Pattern RAM")

    sprites = [build_pac(False, f) for f in range(3)] + [build_pac(True, f) for f in range(3)]
    palette = [(r << 6) | (g << 3) | b for _, (r, g, b) in PALETTE]
    return tiles, classes, tilemap, sprites, palette


# ----------------------------------------------------------------------------
# Saida em C
# ----------------------------------------------------------------------------
def c_array_2d(name, ctype, data, per_line):
    out = [f"const {ctype} {name}[{len(data)}][{len(data[0])}] = {{"]
    for row in data:
        parts = [f"{v}" for v in row]
        lines = [", ".join(parts[i:i + per_line]) for i in range(0, len(parts), per_line)]
        out.append("    { " + ",\n      ".join(lines) + " },")
    out.append("};")
    return "\n".join(out)


def write_outputs(out_dir, tiles, classes, tilemap, sprites, palette):
    n_tiles, n_walls = len(tiles), len(tiles) - T_WALL0
    h = f"""/* GERADO por gen_pac_assets.py - nao edite. Arte PROVISORIA. */
#ifndef PAC_ASSETS_H
#define PAC_ASSETS_H
#include <stdint.h>

#define PAC_MAZE_W          {W}
#define PAC_MAZE_H          {H}
#define PAC_TUNNEL_ROW      {TUNNEL_ROW}
#define PAC_N_COLORS        {len(palette)}
#define PAC_N_TILES         {n_tiles}      /* padroes de tile (<= 256) */
#define PAC_N_WALL_TILES    {n_walls}
#define PAC_N_SPRITES       {len(sprites)}      /* padroes de sprite 16x16 (linha a linha) */

/* Indices da paleta 0 */
#define PAC_C_BLACK         {C_BLACK}
#define PAC_C_WALL          {C_WALL}
#define PAC_C_DOT           {C_DOT}
#define PAC_C_YELLOW        {C_YELLOW}
#define PAC_C_WHITE         {C_WHITE}
#define PAC_C_DOOR          {C_DOOR}
#define PAC_C_ENERGIZER     {C_ENERGIZER}   /* cor que pisca (troca de paleta) */

/* Ids fixos de tile */
#define PAC_TILE_BLANK      {T_BLANK}
#define PAC_TILE_DOT        {T_DOT}
#define PAC_TILE_ENERGIZER  {T_ENERGIZER}
#define PAC_TILE_DOOR       {T_DOOR}
#define PAC_TILE_DIGIT0     {T_DIGIT0}      /* 10 digitos seguidos */
#define PAC_TILE_LETTER_S   {T_LETTER0 + LETTERS.index('S')}
#define PAC_TILE_LETTER_C   {T_LETTER0 + LETTERS.index('C')}
#define PAC_TILE_LETTER_O   {T_LETTER0 + LETTERS.index('O')}
#define PAC_TILE_LETTER_R   {T_LETTER0 + LETTERS.index('R')}
#define PAC_TILE_LETTER_E   {T_LETTER0 + LETTERS.index('E')}
#define PAC_TILE_LETTER_F   {T_LETTER0 + LETTERS.index('F')}
#define PAC_TILE_LETTER_P   {T_LETTER0 + LETTERS.index('P')}

/* Classes de tile: a grade logica do jogo deriva do tilemap por esta tabela */
enum {{ PAC_CLS_NONE = {CLS_NONE}, PAC_CLS_WALL = {CLS_WALL}, PAC_CLS_PATH = {CLS_PATH},
       PAC_CLS_DOT = {CLS_DOT}, PAC_CLS_ENERGIZER = {CLS_ENERGIZER}, PAC_CLS_DOOR = {CLS_DOOR} }};

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
"""
    c = ['/* GERADO por gen_pac_assets.py - nao edite. Arte PROVISORIA. */',
         '#include "pac_assets.h"', '',
         "const uint16_t pac_palette[PAC_N_COLORS] = { " + ", ".join(str(v) for v in palette) + " };", '',
         c_array_2d("pac_tiles", "uint8_t", tiles, 16), '',
         "const uint8_t pac_tile_class[PAC_N_TILES] = { " + ", ".join(str(v) for v in classes) + " };", '',
         c_array_2d("pac_maze_tilemap", "uint8_t", tilemap, 28), '',
         c_array_2d("pac_sprites", "uint8_t", sprites, 16), '']
    open(f"{out_dir}/pac_assets.h", "w", encoding="utf-8").write(h)
    open(f"{out_dir}/pac_assets_data.c", "w", encoding="utf-8").write("\n".join(c))


def preview(path, rows, tiles, tilemap, sprites, palette):
    """Imagem 320x240 como a tela ficaria (scroll_y = 4, labirinto deslocado 6 colunas)."""
    from PIL import Image
    def rgb(v):
        return tuple(int(((v >> sh) & 7) * 255 / 7) for sh in (6, 3, 0))
    img = Image.new("RGB", (320, 240), (0, 0, 0))
    px = img.load()
    SC = 4
    for ty in range(H - 1):                      # 30 linhas de tiles
        for tx in range(W):
            t = tiles[tilemap[ty][tx]]
            for y in range(8):
                for x in range(8):
                    sx, sy = 48 + tx * 8 + x, ty * 8 + y - SC
                    if sy < 0:
                        sy += 240
                    if 0 <= sy < 240:
                        px[sx, sy] = rgb(palette[t[y * 8 + x]])
    spr = sprites[1]                              # Pac-Man na partida (centro x=112, y=188)
    cx, cy = 48 + 112, 188 - SC
    for y in range(16):
        for x in range(16):
            if spr[y * 16 + x]:
                px[cx - 8 + x, cy - 8 + y] = rgb(palette[spr[y * 16 + x]])
    img = img.resize((960, 720), Image.NEAREST)
    img.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--maze", default="maze.txt")
    ap.add_argument("--out-dir", default=".")
    ap.add_argument("--preview")
    a = ap.parse_args()
    rows = load_maze(a.maze)
    errs = validate_maze(rows)
    if errs:
        print("labirinto invalido:", *errs, sep="\n  - ")
        sys.exit(1)
    tiles, classes, tilemap, sprites, palette = build_all(rows)
    write_outputs(a.out_dir, tiles, classes, tilemap, sprites, palette)
    if a.preview:
        preview(a.preview, rows, tiles, tilemap, sprites, palette)
    print(f"ok: labirinto {W}x{H} validado (240 pontos, 4 energizers, simetrico, conectado); "
          f"{len(tiles)} tiles ({len(tiles) - T_WALL0} de parede), {len(sprites)} padroes de sprite; "
          f"gravado em {a.out_dir}/pac_assets.h e pac_assets_data.c")


if __name__ == "__main__":
    main()
