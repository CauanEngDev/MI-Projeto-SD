# ============================================================
# Gerador de programa Assembly - Coprocessador Gráfico
# ============================================================

output_file = "programa.asm"

# ------------------------------------------------------------
# Configurações
# ------------------------------------------------------------

# Cores RRRGGGBBB
# PAL0
PAL0_BG = 0b001001001       # fundo
PAL0_SQUARE = 0b111000000   # vermelho
PAL0_RECT = 0b000111000     # verde

# PAL1
PAL1_SPRITE = 0b000000111   # azul

# Sprite
SPRITE_ID = 0
SPRITE_PATTERN = 0

SPRITE_X = 220
SPRITE_Y = 150

# ------------------------------------------------------------
# Funções auxiliares
# ------------------------------------------------------------

def emit(lines, text):
    lines.append(text)


def pass_imm(lines, reg, value):
    """
    PASS Rn, #imm
    Carrega uma constante usando a ULA.
    """
    emit(lines, f"PASS R{reg}, #{value}")


def set_palette(lines, palette, index, color, ra=10, rb=11):
    """
    SET_PALETTE:
        Ra = {palette_sel, indice}
        Rb = cor
    """

    address = (palette << 8) | index

    pass_imm(lines, ra, address)
    pass_imm(lines, rb, color)

    emit(lines, f"SET_PALETTE R{ra}, R{rb}")


def set_sprite_pos(lines, sprite_id, x, y, ra=10, rb=11):
    """
    SET_SPRITE_POS:
        Ra = sprite ID
        Rb = {pos_y[7:0], pos_x[8:0]}
    """

    packed_pos = (y << 9) | x

    pass_imm(lines, ra, sprite_id)
    pass_imm(lines, rb, packed_pos)

    emit(lines, f"SET_SPRITE_POS R{ra}, R{rb}")


def set_sprite_attr(
    lines,
    sprite_id,
    enable,
    priority,
    flip_v,
    flip_h,
    palette,
    pattern,
    ra=10,
    rb=11
):
    """
    SET_SPRITE_ATTR:

    [14]    enable
    [13:9]  priority
    [8]     flip_v
    [7]     flip_h
    [6]     palette
    [5:0]   pattern
    """

    attr = (
        ((enable & 0x1) << 14)
        | ((priority & 0x1F) << 9)
        | ((flip_v & 0x1) << 8)
        | ((flip_h & 0x1) << 7)
        | ((palette & 0x1) << 6)
        | (pattern & 0x3F)
    )

    pass_imm(lines, ra, sprite_id)
    pass_imm(lines, rb, attr)

    emit(lines, f"SET_SPRITE_ATTR R{ra}, R{rb}")


# ------------------------------------------------------------
# Geração
# ------------------------------------------------------------

lines = []

emit(lines, "; ============================================================")
emit(lines, "; Programa de teste do coprocessador gráfico")
emit(lines, "; ============================================================")
emit(lines, ";")
emit(lines, "; Background -> paleta 0")
emit(lines, "; Quadrado   -> paleta 0")
emit(lines, "; Retangulo  -> paleta 0")
emit(lines, "; Sprite     -> paleta 1")
emit(lines, ";")
emit(lines, "; ============================================================")
emit(lines, "")


# ============================================================
# 1. PALETAS
# ============================================================

emit(lines, "; ------------------------------------------------------------")
emit(lines, "; PALETAS")
emit(lines, "; ------------------------------------------------------------")

# Paleta 0
set_palette(lines, 0, 1, PAL0_BG)
set_palette(lines, 0, 2, PAL0_SQUARE)
set_palette(lines, 0, 3, PAL0_RECT)

# Paleta 1
# índice 0 permanece transparente
set_palette(lines, 1, 1, PAL1_SPRITE)

emit(lines, "")


# ============================================================
# 2. BACKGROUND
# ============================================================

emit(lines, "; ------------------------------------------------------------")
emit(lines, "; TILE PATTERN DO BACKGROUND")
emit(lines, "; ------------------------------------------------------------")
emit(lines, "; Pattern 0 = tile 8x8 preenchido com índice 1")
emit(lines, "; da paleta 0.")
emit(lines, "")

# Um tile 8x8 possui 64 pixels
for addr in range(64):
    pass_imm(lines, 10, addr)
    pass_imm(lines, 11, 1)
    emit(lines, "WRITE_TILE_DATA R10, R11")

emit(lines, "")

emit(lines, "; ------------------------------------------------------------")
emit(lines, "; TILEMAP")
emit(lines, "; ------------------------------------------------------------")
emit(lines, "; Tela: 320x240")
emit(lines, "; Tile: 8x8")
emit(lines, "; 40 x 30 = 1200 tiles")
emit(lines, "; Todos usam pattern 0.")
emit(lines, "")

for tile in range(1200):
    pass_imm(lines, 10, tile)
    pass_imm(lines, 11, 0)
    emit(lines, "SET_TILEMAP R10, R11")

emit(lines, "")


# ============================================================
# 3. DRAW BACKGROUND
# ============================================================

emit(lines, "; ------------------------------------------------------------")
emit(lines, "; DESENHA BACKGROUND")
emit(lines, "; ------------------------------------------------------------")

emit(lines, "DRAW_BG")

emit(lines, "")


# ============================================================
# 4. QUADRADO
# ============================================================

emit(lines, "; ------------------------------------------------------------")
emit(lines, "; QUADRADO")
emit(lines, "; ------------------------------------------------------------")
emit(lines, "; (50,50) -> (99,99)")
emit(lines, "; indice 2 da paleta 0")
emit(lines, "")

pass_imm(lines, 0, 50)     # x0
pass_imm(lines, 1, 50)     # y0
pass_imm(lines, 2, 99)     # x1
pass_imm(lines, 3, 99)     # y1
pass_imm(lines, 4, 2)      # indice
pass_imm(lines, 5, 0)      # paleta

emit(lines, "DRAW_RECT")

emit(lines, "")


# ============================================================
# 5. RETÂNGULO
# ============================================================

emit(lines, "; ------------------------------------------------------------")
emit(lines, "; RETANGULO")
emit(lines, "; ------------------------------------------------------------")
emit(lines, "; (130,80) -> (229,129)")
emit(lines, "; indice 3 da paleta 0")
emit(lines, "")

pass_imm(lines, 0, 130)    # x0
pass_imm(lines, 1, 80)     # y0
pass_imm(lines, 2, 229)    # x1
pass_imm(lines, 3, 129)    # y1
pass_imm(lines, 4, 3)      # indice
pass_imm(lines, 5, 0)      # paleta

emit(lines, "DRAW_RECT")

emit(lines, "")


# ============================================================
# 6. DADOS DO SPRITE
# ============================================================

emit(lines, "; ------------------------------------------------------------")
emit(lines, "; SPRITE PATTERN")
emit(lines, "; ------------------------------------------------------------")
emit(lines, "; Pattern 0 = quadrado 16x16")
emit(lines, "; O sprite possui pixels transparentes (indice 0)")
emit(lines, "; nas bordas e indice 1 no interior.")
emit(lines, "")

# Sprite 16x16.
# Borda = transparente
# Interior = índice 1

for y in range(16):
    for x in range(16):

        addr = y * 16 + x

        if x == 0 or x == 15 or y == 0 or y == 15:
            color_index = 0
        else:
            color_index = 1

        pass_imm(lines, 10, addr)
        pass_imm(lines, 11, color_index)

        emit(lines, "WRITE_SPRITE_DATA R10, R11")

emit(lines, "")


# ============================================================
# 7. POSIÇÃO DO SPRITE
# ============================================================

emit(lines, "; ------------------------------------------------------------")
emit(lines, "; POSIÇÃO DO SPRITE")
emit(lines, "; ------------------------------------------------------------")
emit(lines, "; Sprite 0")
emit(lines, f"; posição = ({SPRITE_X},{SPRITE_Y})")
emit(lines, "")

set_sprite_pos(
    lines,
    SPRITE_ID,
    SPRITE_X,
    SPRITE_Y
)

emit(lines, "")


# ============================================================
# 8. ATRIBUTOS DO SPRITE
# ============================================================

emit(lines, "; ------------------------------------------------------------")
emit(lines, "; ATRIBUTOS DO SPRITE")
emit(lines, "; ------------------------------------------------------------")
emit(lines, "; enable    = 1")
emit(lines, "; priority  = 10")
emit(lines, "; flip_v    = 0")
emit(lines, "; flip_h    = 0")
emit(lines, "; palette   = 1")
emit(lines, "; pattern   = 0")
emit(lines, "")

set_sprite_attr(
    lines,
    sprite_id=SPRITE_ID,
    enable=1,
    priority=10,
    flip_v=0,
    flip_h=0,
    palette=1,
    pattern=SPRITE_PATTERN
)

emit(lines, "")


# ============================================================
# 9. DRAW SPRITES
# ============================================================

emit(lines, "; ------------------------------------------------------------")
emit(lines, "; DESENHA SPRITES")
emit(lines, "; ------------------------------------------------------------")

emit(lines, "DRAW_SPRITES")

emit(lines, "")


# ============================================================
# 10. FINALIZA FRAME
# ============================================================

emit(lines, "; ------------------------------------------------------------")
emit(lines, "; FINAL DO FRAME")
emit(lines, "; ------------------------------------------------------------")

emit(lines, "HALT")

emit(lines, "")


# ============================================================
# Salvar
# ============================================================

with open(output_file, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print(f"Assembly gerado em: {output_file}")
print(f"Total de instruções: {len(lines)}")