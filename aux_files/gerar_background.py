#!/usr/bin/env python3
"""
Converte uma imagem em .mif de background para o coprocessador grafico.

  python3 gerar_background_mif.py imagem.png sprite_palette_sonic.mif sprite_pattern_sonic.mif -o saida/ [--modo esticar|cortar|barras]

Restricoes do hardware (motor_background.v):
  - tela 320x240 = mapa de 40x30 tiles de 8x8 pixels (bg_tile_ram, 1200 x 8 bits)
  - id de tile de 8 bits  -> no maximo 256 tiles distintos (bg_tile_pattern_ram, 256 x 64 pixels)
  - cada pixel do tile e um indice de 8 bits no BANCO 0 da paleta (palette_ram[0..255]);
    cores RGB 3-3-3 (9 bits)
  - o sprite le o mesmo banco 0: as entradas que ele usa NAO podem mudar.

Etapas:
  1. imagem -> 320x240
  2. 1200 tiles -> 256 tiles representativos (k-means)
  3. paleta: entradas usadas pelo sprite ficam fixas; o resto (ate o indice 255) e
     otimizado para a imagem (Lloyd com centros fixos); cores arredondadas para 3-3-3
  4. cada pixel dos tiles -> indice da cor mais proxima; cada posicao do mapa -> o
     tile (ja quantizado) mais proximo
"""
import argparse, os, re, sys
import numpy as np
from PIL import Image
from sklearn.cluster import KMeans


def ler_mif(caminho):
    t = re.sub(r"--.*", "", open(caminho).read())
    h = lambda k: (re.search(rf"\b{k}\s*=\s*(\w+)\s*;", t, re.I) or [None, None])[1]
    rx = {"HEX": 16, "UNS": 10, "DEC": 10, "BIN": 2, "OCT": 8}
    ar, dr = rx[(h("ADDRESS_RADIX") or "HEX").upper()[:3]], rx[(h("DATA_RADIX") or "HEX").upper()[:3]]
    out = {}
    for m in re.finditer(r"(?:\[\s*(\w+)\s*\.\.\s*(\w+)\s*\]|(\w+))\s*:\s*(\w+)\s*;", t.split("BEGIN", 1)[1]):
        lo = int(m[1] or m[3], ar); hi = int(m[2], ar) if m[2] else lo
        for k in range(lo, hi + 1):
            out[k] = int(m[4], dr)
    return out


def rgb333_para_rgb(c):
    return np.array([((c >> 6) & 7), ((c >> 3) & 7), (c & 7)], float) * 255 / 7


def rgb_para_333(rgb):
    q = np.clip(np.rint(np.asarray(rgb, float) / 255 * 7), 0, 7).astype(int)
    return (q[..., 0] << 6) | (q[..., 1] << 3) | q[..., 2]


def preparar_imagem(caminho, modo):
    im = Image.open(caminho).convert("RGB")
    w, h = im.size
    if modo == "cortar":                      # preenche a tela, perdendo as laterais
        nw = int(h * 4 / 3)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    elif modo == "barras":                    # mantem a proporcao, com barras pretas
        nh = round(320 * h / w)
        fundo = Image.new("RGB", (320, 240), (0, 0, 0))
        fundo.paste(im.resize((320, nh), Image.LANCZOS), (0, (240 - nh) // 2))
        return np.asarray(fundo, float)
    return np.asarray(im.resize((320, 240), Image.LANCZOS), float)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("imagem"); ap.add_argument("paleta_sprite"); ap.add_argument("padrao_sprite")
    ap.add_argument("-o", "--saida", default="."); ap.add_argument("--prefixo", default="floresta")
    ap.add_argument("--modo", choices=["esticar", "cortar", "barras"], default="esticar")
    ap.add_argument("--refinar", type=int, default=12, help="iteracoes de refino dos tiles (0 = so k-means)")
    a = ap.parse_args()
    os.makedirs(a.saida, exist_ok=True)

    # ---- 0. entradas da paleta que o sprite usa (ficam intactas) ------------------
    pal_sprite = ler_mif(a.paleta_sprite)
    usados = sorted(set(ler_mif(a.padrao_sprite).values()))
    ate = max(usados)                         # indices 0..ate ficam reservados ao sprite
    fixas = list(range(ate + 1))
    n_livres = 256 - len(fixas)
    print(f"sprite usa os indices 1..{ate} do banco 0 -> {len(fixas)} entradas fixas, {n_livres} livres para o fundo")

    # ---- 1. imagem 320x240 e tiles ----------------------------------------------
    img = preparar_imagem(a.imagem, a.modo)                              # (240, 320, 3)
    tiles = img.reshape(30, 8, 40, 8, 3).transpose(0, 2, 1, 3, 4).reshape(1200, 8, 8, 3)
    X = tiles.reshape(1200, 192)
    km = KMeans(n_clusters=256, n_init=4, random_state=0).fit(X)
    cent = km.cluster_centers_.reshape(256, 8, 8, 3)
    uso = np.bincount(km.labels_, minlength=256).astype(float)           # posicoes por tile

    # ---- 2. paleta: centros fixos (sprite) + livres otimizados (Lloyd) ----------
    P = cent.reshape(-1, 3)                                              # 16384 pixels
    W = np.repeat(uso, 64)
    fix_rgb = np.array([rgb333_para_rgb(pal_sprite[i]) for i in fixas])
    grade = np.array([rgb333_para_rgb(c) for c in range(512)])           # as 512 cores possiveis
    centros = list(fix_rgb)
    for _ in range(n_livres):                                            # farthest-first ponderado
        d = np.min(((P[:, None, :] - np.array(centros)[None]) ** 2).sum(2), axis=1)
        centros.append(P[np.argmax(d * W)])
    centros = np.array(centros)
    nf = len(fixas)
    for _ in range(30):
        d = ((P[:, None, :] - centros[None]) ** 2).sum(2)
        lab, dmin = d.argmin(1), d.min(1)
        ordem = np.argsort(-(dmin * W)); semente = []
        for k in range(nf, 256):
            m = lab == k
            if m.any():
                centros[k] = (P[m] * W[m, None]).sum(0) / W[m].sum()
            else:                      # cluster vazio: pixel mal representado e distante das outras sementes
                for q in ordem:
                    if all(((P[q] - P[r]) ** 2).sum() > 150 for r in semente):
                        semente.append(q); centros[k] = P[q]; break
    # arredonda para a grade RGB 3-3-3; duplicatas viram a cor livre mais proxima ainda nao usada
    paleta = [pal_sprite[i] for i in fixas]
    usadas = set(paleta)
    for k in range(nf, 256):
        ordem_c = np.argsort(((grade - centros[k]) ** 2).sum(1))
        c = next(int(c) for c in ordem_c if int(c) not in usadas)
        usadas.add(c); paleta.append(c)
    assert len(set(paleta[nf:])) == n_livres and not set(paleta[nf:]) & set(paleta[:nf])
    pal_rgb = np.array([rgb333_para_rgb(c) for c in paleta])              # (256, 3)

    # ---- 3. tiles quantizados (indices) e mapa ----------------------------------
    d = ((cent.reshape(256, 64, 1, 3) - pal_rgb[None, None]) ** 2).sum(3)
    idx_tiles = d.argmin(2)                                               # (256, 64)
    rec_tiles = pal_rgb[idx_tiles].reshape(256, 192)
    # cada posicao -> tile quantizado mais proximo
    dd = ((X[:, None, :] - rec_tiles[None]) ** 2).sum(2)
    mapa = dd.argmin(1)                                                   # (1200,)
    # refino: o k-means agrupou antes da quantizacao; repete (atribui -> media -> quantiza)
    # medindo o erro ja com os tiles quantizados e a paleta final
    def quantiza(centros_tiles):
        d_ = ((centros_tiles.reshape(256, 64, 1, 3) - pal_rgb[None, None]) ** 2).sum(3)
        ix = d_.argmin(2)
        return ix, pal_rgb[ix].reshape(256, 192)
    melhor = (np.inf, None, None, None)
    for it in range(a.refinar):
        erro_pos = dd.min(1)
        mapa = dd.argmin(1)
        tot = erro_pos.sum()
        if tot < melhor[0]:
            melhor = (tot, mapa.copy(), idx_tiles.copy(), rec_tiles.copy())
        novos = cent.reshape(256, 192).copy()
        for k in range(256):
            m = mapa == k
            if m.any():
                novos[k] = X[m].mean(0)
        # tile sem posicoes: reaproveita no pior ajuste (divide o cluster mais custoso)
        vazios = [k for k in range(256) if not (mapa == k).any()]
        for k in vazios:
            pior = int(np.argmax(erro_pos)); novos[k] = X[pior]; erro_pos[pior] = 0
        idx_tiles, rec_tiles = quantiza(novos.reshape(256, 8, 8, 3))
        cent = novos.reshape(256, 8, 8, 3)
        dd = ((X[:, None, :] - rec_tiles[None]) ** 2).sum(2)
    if a.refinar:
        if dd.min(1).sum() < melhor[0]:
            melhor = (dd.min(1).sum(), dd.argmin(1), idx_tiles, rec_tiles)
        _, mapa, idx_tiles, rec_tiles = melhor
    recon = pal_rgb[idx_tiles[mapa]].reshape(30, 40, 8, 8, 3).transpose(0, 2, 1, 3, 4).reshape(240, 320, 3)
    mse = ((recon - img) ** 2).mean()
    print(f"tiles realmente usados: {len(set(mapa.tolist()))} de 256 | PSNR = {10*np.log10(255**2/mse):.1f} dB")

    # ---- 4. escreve os .mif ------------------------------------------------------
    def runs(vals):
        i = 0
        while i < len(vals):
            j = i
            while j + 1 < len(vals) and vals[j + 1] == vals[i]:
                j += 1
            yield i, j, vals[i]; i = j + 1

    def escreve(nome, cab, largura, prof, vals, comentario, hexw):
        with open(os.path.join(a.saida, nome), "w") as f:
            f.write(f"-- {comentario}\nWIDTH={largura};\nDEPTH={prof};\n\nADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\n\nCONTENT BEGIN\n")
            for lo, hi, v in runs(vals):
                f.write(f"\t{lo}\t:\t{v:0{hexw}X};\n" if lo == hi else f"\t[{lo}..{hi}]\t:\t{v:0{hexw}X};\n")
            f.write("END;\n")

    escreve(f"{a.prefixo}_tilemap.mif", "", 8, 1200, mapa.tolist(),
            "Mapa de tiles do background (40x30 tiles de 8x8) - bg_tile_ram", 2)
    padroes = [0] * 16384
    for t in range(256):
        padroes[t * 64:(t + 1) * 64] = idx_tiles[t].tolist()
    escreve(f"{a.prefixo}_patterns.mif", "", 8, 16384, padroes,
            "256 padroes de 8x8 pixels (indice no banco 0 da paleta); endereco = {tile[7:0], y[2:0], x[2:0]} - bg_tile_pattern_ram", 2)
    full = paleta + paleta                                                # banco 1 = copia do banco 0
    escreve(f"{a.prefixo}_palette.mif", "", 9, 512, full,
            f"Paleta RGB 3-3-3. Entradas 0..{ate} = paleta do sprite (inalteradas); {ate + 1}..255 = cores do fundo. Banco 1 = copia do banco 0", 3)

    Image.fromarray(recon.astype(np.uint8)).resize((640, 480), Image.NEAREST).save(os.path.join(a.saida, f"{a.prefixo}_previa.png"))
    Image.fromarray(img.astype(np.uint8)).resize((640, 480), Image.NEAREST).save(os.path.join(a.saida, f"{a.prefixo}_original_320x240.png"))
    print("gerados:", ", ".join(sorted(os.listdir(a.saida))))


if __name__ == "__main__":
    sys.exit(main())