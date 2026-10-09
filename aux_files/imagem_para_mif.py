#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
imagem_para_mif.py - converte uma imagem em tudo que o background do
coprocessador grafico precisa para exibi-la (DE1-SoC / Quartus).

Gera 4 arquivos .mif (mais um .hex do programa e um preview em PNG):

  <nome>_tilemap.mif   bg_tile_ram          8 bits x 1200   (pattern_id por tile)
  <nome>_patterns.mif  bg_tile_pattern_ram  8 bits x 16384  (indice de cor por pixel)
  <nome>_palette.mif   palette_ram          9 bits x 512    (RRRGGGBBB; paleta 0)
  <nome>_program.mif   instruction_memory  32 bits x 16384  (DRAW_BG ; HALT)

Formato exigido pelo hardware (motor_background.v):
  - tela logica 320x240 = grade de 40x30 tiles de 8x8 pixels
  - endereco do tile map:   linha*40 + coluna
  - endereco do padrao:     {pattern_id[7:0], y[2:0], x[2:0]} = id*64 + y*8 + x
  - o fundo le a paleta 0 (enderecos 0..255 da palette_ram), 9 bits RRRGGGBBB
  - no maximo 256 padroes (pattern_id tem 8 bits) e 256 cores

Quando a imagem tem mais de 256 cores ou mais de 256 tiles unicos, o script
reduz (quantizacao de cores e k-means nos tiles) e informa o erro. Use
--strict para falhar em vez de reduzir.

Dependencias: pip install pillow numpy
Uso:          python imagem_para_mif.py imagem.png -o saida/
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

W, H = 320, 240
TS = 8
COLS, ROWS = W // TS, H // TS          # 40 x 30
N_TILES_MAP = COLS * ROWS              # 1200
MAX_PATTERNS = 256
MAX_COLORS = 256
PATTERN_DEPTH = 16384
PALETTE_DEPTH = 512
INSTR_DEPTH = 16384

OP_DRAW_BG = 0b10000
OP_HALT = 0b10011


# ----------------------------------------------------------------------------
# Escrita de .mif
# ----------------------------------------------------------------------------
def write_mif(path, width, depth, values, comment):
    """values: lista com ate `depth` inteiros; o restante vira 0 (faixa unica)."""
    digits = (width + 3) // 4
    vals = list(values)
    last = max((i for i, v in enumerate(vals) if v != 0), default=-1)
    with open(path, "w", newline="\n") as f:
        for line in comment.strip().splitlines():
            f.write("-- %s\n" % line)
        f.write("WIDTH=%d;\nDEPTH=%d;\n\n" % (width, depth))
        f.write("ADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\n\nCONTENT BEGIN\n")
        for i in range(last + 1):
            f.write("    %-5d: %0*X;\n" % (i, digits, vals[i]))
        if last + 1 < depth:
            f.write("    [%d..%d] : %0*X;\n" % (last + 1, depth - 1, digits, 0))
        f.write("END;\n")


# ----------------------------------------------------------------------------
# Imagem -> 320x240
# ----------------------------------------------------------------------------
def fit_image(img, mode, resample):
    img = img.convert("RGB")
    rs = Image.NEAREST if resample == "nearest" else Image.LANCZOS
    w, h = img.size
    if mode == "stretch":
        return img.resize((W, H), rs)
    if mode == "cover":
        s = max(W / w, H / h)
        nw, nh = max(W, round(w * s)), max(H, round(h * s))
        img = img.resize((nw, nh), rs)
        x0, y0 = (nw - W) // 2, (nh - H) // 2
        return img.crop((x0, y0, x0 + W, y0 + H))
    # contain: cabe inteira, barras pretas
    s = min(W / w, H / h)
    nw, nh = max(1, round(w * s)), max(1, round(h * s))
    img = img.resize((nw, nh), rs)
    canvas = Image.new("RGB", (W, H), (0, 0, 0))
    canvas.paste(img, ((W - nw) // 2, (H - nh) // 2))
    return canvas


# ----------------------------------------------------------------------------
# Cores: 8 bits/canal -> 3 bits/canal (RRRGGGBBB)
# ----------------------------------------------------------------------------
def to_levels(rgb8):
    """(...,3) uint8 -> (...,3) int 0..7."""
    return (rgb8.astype(np.int32) * 7 + 127) // 255


def levels_to_code(lv):
    return (lv[..., 0] << 6) | (lv[..., 1] << 3) | lv[..., 2]


def code_to_levels(code):
    code = np.asarray(code)
    return np.stack([(code >> 6) & 7, (code >> 3) & 7, code & 7], axis=-1)


def levels_to_rgb8(lv):
    return (np.asarray(lv) * 255 + 3) // 7


def build_palette(rgb8):
    """Retorna (paleta[n] de codigos 9 bits, indices[H,W] uint8, houve_reducao)."""
    lv = to_levels(rgb8)
    codes = levels_to_code(lv)
    uniq, inv, cnt = np.unique(codes.ravel(), return_inverse=True, return_counts=True)
    if len(uniq) <= MAX_COLORS:
        order = np.argsort(-cnt, kind="stable")          # mais frequentes primeiro
        palette = uniq[order]
        remap = np.empty(len(uniq), dtype=np.int32)
        remap[order] = np.arange(len(uniq))
        return palette, remap[inv].reshape(H, W).astype(np.uint8), False

    # mais de 256 cores distintas em 3-3-3: quantiza por mediana (sem dithering,
    # para nao destruir a repeticao de tiles)
    base = Image.fromarray(levels_to_rgb8(lv).astype(np.uint8), "RGB")
    q = base.quantize(colors=MAX_COLORS, method=Image.Quantize.MEDIANCUT,
                      dither=Image.Dither.NONE)
    pal8 = np.array(q.getpalette()[:3 * MAX_COLORS], dtype=np.uint8).reshape(-1, 3)
    pal_codes = np.unique(levels_to_code(to_levels(pal8)))
    pal_lv = code_to_levels(pal_codes).astype(np.int32)
    # cada cor unica da imagem -> entrada de paleta mais proxima
    u_lv = code_to_levels(uniq).astype(np.int32)
    d = ((u_lv[:, None, :] - pal_lv[None, :, :]) ** 2).sum(axis=2)
    nearest = d.argmin(axis=1)
    used = np.unique(nearest)
    new_id = np.full(len(pal_codes), -1, dtype=np.int32)
    new_id[used] = np.arange(len(used))
    palette = pal_codes[used]
    idx = new_id[nearest][inv].reshape(H, W).astype(np.uint8)
    return palette, idx, True


# ----------------------------------------------------------------------------
# Tiles: deduplicacao e, se preciso, k-means
# ----------------------------------------------------------------------------
def cut_tiles(idx):
    """(H,W) -> (1200, 64), tile na ordem linha*40+coluna, pixel y*8+x."""
    return idx.reshape(ROWS, TS, COLS, TS).transpose(0, 2, 1, 3).reshape(N_TILES_MAP, TS * TS)


def kmeans_tiles(vecs, weights, k, seed=0, iters=25):
    """k-means ponderado. vecs: (N,D) float. Retorna (centroides, rotulos)."""
    rng = np.random.default_rng(seed)
    n = len(vecs)
    # inicializacao k-means++
    cent = np.empty((k, vecs.shape[1]), dtype=np.float64)
    first = rng.choice(n, p=weights / weights.sum())
    cent[0] = vecs[first]
    dist = ((vecs - cent[0]) ** 2).sum(axis=1)
    for c in range(1, k):
        p = dist * weights
        if p.sum() <= 0:
            cent[c] = vecs[rng.integers(n)]
        else:
            cent[c] = vecs[rng.choice(n, p=p / p.sum())]
        dist = np.minimum(dist, ((vecs - cent[c]) ** 2).sum(axis=1))
    labels = np.zeros(n, dtype=np.int64)
    for _ in range(iters):
        d = ((vecs[:, None, :] - cent[None, :, :]) ** 2).sum(axis=2)
        new_labels = d.argmin(axis=1)
        for c in range(k):
            m = new_labels == c
            if m.any():
                w = weights[m]
                cent[c] = (vecs[m] * w[:, None]).sum(axis=0) / w.sum()
            else:                                         # cluster vazio: realoca
                cent[c] = vecs[d.min(axis=1).argmax()]
        if (new_labels == labels).all():
            break
        labels = new_labels
    d = ((vecs[:, None, :] - cent[None, :, :]) ** 2).sum(axis=2)
    return cent, d.argmin(axis=1)


def build_patterns(idx, palette, strict, seed):
    """Retorna (tilemap[1200], patterns[n,64], n_unicos_original, houve_reducao)."""
    tiles = cut_tiles(idx)
    uniq, inv, cnt = np.unique(tiles, axis=0, return_inverse=True, return_counts=True)
    inv = inv.reshape(-1)
    n_unique = len(uniq)
    if n_unique <= MAX_PATTERNS:
        return inv.astype(np.int32), uniq, n_unique, False
    if strict:
        sys.exit("ERRO (--strict): a imagem tem %d tiles 8x8 unicos; o maximo e %d."
                 % (n_unique, MAX_PATTERNS))
    pal_lv = code_to_levels(palette).astype(np.float64)       # (n_cores, 3)
    vecs = pal_lv[uniq].reshape(n_unique, -1)                 # (N, 192)
    cent, labels = kmeans_tiles(vecs, cnt.astype(np.float64), MAX_PATTERNS, seed)
    # centroide -> indices de paleta mais proximos, pixel a pixel
    cpix = cent.reshape(MAX_PATTERNS, TS * TS, 3)
    d = ((cpix[:, :, None, :] - pal_lv[None, None, :, :]) ** 2).sum(axis=3)
    patterns = d.argmin(axis=2).astype(np.uint8)              # (256, 64)
    # remove clusters sem uso e renumera
    tilemap = labels[inv]
    used = np.unique(tilemap)
    new_id = np.full(MAX_PATTERNS, -1, dtype=np.int32)
    new_id[used] = np.arange(len(used))
    return new_id[tilemap], patterns[used], n_unique, True


# ----------------------------------------------------------------------------
# Reconstrucao (preview) a partir dos arrays que vao para os .mif
# ----------------------------------------------------------------------------
def reconstruct(tilemap, pattern_words, palette_words):
    words = list(pattern_words[: MAX_PATTERNS * 64])
    words += [0] * (MAX_PATTERNS * 64 - len(words))          # padroes nao usados = 0
    pat = np.array(words, dtype=np.int32).reshape(MAX_PATTERNS, 64)
    tm = np.array(tilemap, dtype=np.int32).reshape(ROWS, COLS)
    pix = pat[tm]                                             # (30,40,64)
    idx = pix.reshape(ROWS, COLS, TS, TS).transpose(0, 2, 1, 3).reshape(H, W)
    codes = np.array(palette_words[:MAX_COLORS], dtype=np.int32)[idx]
    return levels_to_rgb8(code_to_levels(codes)).astype(np.uint8)


def psnr(a, b):
    mse = ((a.astype(np.float64) - b.astype(np.float64)) ** 2).mean()
    return float("inf") if mse == 0 else 10 * np.log10(255.0 ** 2 / mse)


# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(
        description="Converte uma imagem nos .mif do background do coprocessador grafico.")
    ap.add_argument("imagem", help="arquivo de imagem (png, jpg, bmp, ...)")
    ap.add_argument("-o", "--saida", default=".", help="pasta de saida (padrao: .)")
    ap.add_argument("-n", "--nome", help="prefixo dos arquivos (padrao: nome da imagem)")
    ap.add_argument("--fit", choices=["cover", "contain", "stretch"], default="cover",
                    help="como ajustar a 320x240: cover=recorta o centro (padrao), "
                         "contain=barras pretas, stretch=distorce")
    ap.add_argument("--resample", choices=["lanczos", "nearest"], default="lanczos",
                    help="nearest e melhor para pixel art")
    ap.add_argument("--strict", action="store_true",
                    help="falha se a imagem passar de 256 tiles unicos (nao reduz)")
    ap.add_argument("--seed", type=int, default=0, help="semente do k-means")
    args = ap.parse_args()

    nome = args.nome or os.path.splitext(os.path.basename(args.imagem))[0]
    os.makedirs(args.saida, exist_ok=True)
    out = lambda suf: os.path.join(args.saida, "%s_%s" % (nome, suf))

    src = Image.open(args.imagem)
    img = fit_image(src, args.fit, args.resample)
    rgb8 = np.array(img, dtype=np.uint8)

    palette, idx, color_reduced = build_palette(rgb8)
    tilemap, patterns, n_unique, tile_reduced = build_patterns(idx, palette, args.strict, args.seed)
    n_pat = len(patterns)

    # ---- palavras de cada memoria ----
    tilemap_words = [int(v) for v in tilemap]
    pattern_words = [int(v) for v in patterns.reshape(-1)]
    palette_words = [int(v) for v in palette]
    program_words = [OP_DRAW_BG << 27, OP_HALT << 27]

    hdr = "Gerado por imagem_para_mif.py a partir de '%s'" % os.path.basename(args.imagem)
    write_mif(out("tilemap.mif"), 8, N_TILES_MAP, tilemap_words,
              hdr + "\nbg_tile_ram: 40x30 tiles, endereco = linha*40 + coluna, dado = pattern_id")
    write_mif(out("patterns.mif"), 8, PATTERN_DEPTH, pattern_words,
              hdr + "\nbg_tile_pattern_ram: %d padroes 8x8, endereco = id*64 + y*8 + x, dado = indice da paleta 0" % n_pat)
    write_mif(out("palette.mif"), 9, PALETTE_DEPTH, palette_words,
              hdr + "\npalette_ram: %d cores na paleta 0 (enderecos 0..255), formato RRRGGGBBB" % len(palette))
    write_mif(out("program.mif"), 32, INSTR_DEPTH, program_words,
              hdr + "\ninstruction_memory: 0 DRAW_BG ; 1 HALT")
    with open(out("program.hex"), "w", newline="\n") as f:
        f.write("".join("%08X\n" % w for w in program_words))

    # ---- preview e erro ----
    rec = reconstruct(tilemap_words, pattern_words, palette_words)
    Image.fromarray(rec, "RGB").resize((W * 2, H * 2), Image.NEAREST).save(out("preview.png"))
    ref = levels_to_rgb8(to_levels(rgb8)).astype(np.uint8)    # imagem ideal em 3-3-3
    q_all = psnr(rgb8, rec)

    print("Imagem: %s -> %dx%d (%s)" % (args.imagem, W, H, args.fit))
    print("Cores:  %d na paleta (%s)" % (len(palette),
          "reduzidas por quantizacao" if color_reduced else "sem perda alem do 3-3-3"))
    print("Tiles:  %d unicos de %d -> %d padroes usados (%s)" % (
          n_unique, N_TILES_MAP, n_pat,
          "REDUZIDO por k-means, ha perda" if tile_reduced else "sem perda"))
    print("Qualidade: PSNR %.1f dB vs original; %.1f dB vs original em 3-3-3" % (q_all, psnr(ref, rec)))
    print("\nArquivos em %s:" % os.path.abspath(args.saida))
    for suf in ("tilemap.mif", "patterns.mif", "palette.mif", "program.mif", "program.hex", "preview.png"):
        print("  " + os.path.basename(out(suf)))
    print("""
Proximos passos no Quartus (init_file de cada RAM):
  bg_tile_ram.v           -> ./memory_files/initialization_files/%s
  bg_tile_pattern_ram.v   -> ./memory_files/initialization_files/%s
  palette_ram.v           -> ./memory_files/initialization_files/%s
  instruction_memory.v    -> ./memory_files/initialization_files/%s
Copie os .mif para essa pasta e recompile. ATENCAO: a palette_ram tambem e usada
por sprites e retangulos; trocar o init_file muda as cores deles.""" % (
        os.path.basename(out("tilemap.mif")), os.path.basename(out("patterns.mif")),
        os.path.basename(out("palette.mif")), os.path.basename(out("program.mif"))))


if __name__ == "__main__":
    main()
