from PIL import Image
from pathlib import Path

# ============================================================
# CONFIGURAÇÕES
# ============================================================

IMAGE_FILE = r"F:\Mi-Projeto-SD\MI-Projeto-SD-master\aux_files\Sonic.png"

OUTPUT_DIR = Path(
    r"F:\Mi-Projeto-SD\MI-Projeto-SD-master\memory_files\initialization_files"
)

PATTERN_MIF = "sprite_pattern_sonic.mif"
PALETTE_MIF = "sprite_palette_sonic.mif"

# Dimensão de cada sprite
SPRITE_WIDTH = 16
SPRITE_HEIGHT = 16

# Memória de padrões
PATTERN_WIDTH = 8
PATTERN_DEPTH = 16384

# Memória de paleta
PALETTE_WIDTH = 9
PALETTE_DEPTH = 512

# Quantidade máxima de cores visíveis.
# O índice 0 é reservado para transparência.
MAX_COLORS = 255

# Banco da paleta que será utilizado pelo sprite.
# 0 -> endereços 0..255
# 1 -> endereços 256..511
PALETTE_BANK = 0

# Índice usado para pixels transparentes.
TRANSPARENT_INDEX = 0


# ============================================================
# CONVERSÃO RGB -> RRRGGGBBB
# ============================================================

def rgb888_to_rgb999(rgb):
    """
    Converte RGB de 24 bits:

        RRRRRRRR GGGGGGGG BBBBBBBB

    para RGB de 9 bits:

        RRR GGG BBB
    """

    r, g, b = rgb

    r3 = r >> 5
    g3 = g >> 5
    b3 = b >> 5

    return (r3 << 6) | (g3 << 3) | b3


# ============================================================
# GERAÇÃO DO MIF DE PADRÕES
# ============================================================

def generate_pattern_mif(image, color_to_index):
    """
    Gera um padrão 16x16.

    A organização corresponde diretamente ao motor_sprite:

        tile 0 -> canto superior esquerdo
        tile 1 -> canto superior direito
        tile 2 -> canto inferior esquerdo
        tile 3 -> canto inferior direito

    Portanto:

        endereço = tile_id * 64 + y_local * 8 + x_local

    Para um único sprite/padrão, tile_id varia entre 0 e 3.
    """

    width, height = image.size

    if width != SPRITE_WIDTH or height != SPRITE_HEIGHT:
        raise ValueError(
            f"A imagem precisa ter {SPRITE_WIDTH}x{SPRITE_HEIGHT} pixels. "
            f"Recebido: {width}x{height}."
        )

    # Memória completa de 16384 bytes
    memory = [0] * PATTERN_DEPTH

    pixels = image.load()

    for y in range(SPRITE_HEIGHT):
        for x in range(SPRITE_WIDTH):

            # Determina qual dos quatro blocos 8x8 está sendo acessado.
            tile_x = x // 8
            tile_y = y // 8

            tile_id = (tile_y << 1) | tile_x

            # Coordenada dentro do tile 8x8
            local_x = x % 8
            local_y = y % 8

            # Endereço usado pelo motor_sprite
            address = (
                tile_id * 64
                + local_y * 8
                + local_x
            )

            rgba = pixels[x, y]

            # Tratamento de transparência.
            # Qualquer alpha diferente de 255 será considerado transparente.
            if len(rgba) == 4:
                r, g, b, a = rgba

                if a == 0:
                    index = TRANSPARENT_INDEX
                else:
                    index = color_to_index[(r, g, b)]

            else:
                r, g, b = rgba
                index = color_to_index[(r, g, b)]

            memory[address] = index

    # --------------------------------------------------------
    # Escrita do MIF
    # --------------------------------------------------------

    with open(PATTERN_MIF, "w") as file:

        file.write("WIDTH=8;\n")
        file.write(f"DEPTH={PATTERN_DEPTH};\n")
        file.write("ADDRESS_RADIX=DECIMAL;\n")
        file.write("DATA_RADIX=HEX;\n")
        file.write("CONTENT BEGIN\n")

        # Escrevemos apenas os primeiros 256 bytes,
        # pois estamos gerando o pattern 0.
        for address in range(256):
            file.write(
                f"    {address} : {memory[address]:02X};\n"
            )

        file.write("END;\n")


# ============================================================
# GERAÇÃO DO MIF DA PALETA
# ============================================================

def generate_palette_mif(palette):
    """
    Gera uma memória de 512 entradas:

        banco 0 -> 0..255
        banco 1 -> 256..511

    A paleta será colocada no banco selecionado e também
    duplicada no outro banco.
    """

    memory = [0] * PALETTE_DEPTH

    # Índice 0 permanece 000.
    # Isso é coerente com o fato de índice 0 ser transparente.

    for index, rgb in enumerate(palette, start=1):

        if index > 255:
            raise ValueError(
                "A paleta possui mais de 255 cores visíveis."
            )

        rgb9 = rgb888_to_rgb999(rgb)

        # Banco 0
        memory[index] = rgb9

        # Banco 1
        memory[256 + index] = rgb9

    # --------------------------------------------------------
    # Escrita do MIF
    # --------------------------------------------------------

    with open(PALETTE_MIF, "w") as file:

        file.write("WIDTH=9;\n")
        file.write(f"DEPTH={PALETTE_DEPTH};\n")
        file.write("ADDRESS_RADIX=DECIMAL;\n")
        file.write("DATA_RADIX=HEX;\n")
        file.write("CONTENT BEGIN\n")

        for address in range(PALETTE_DEPTH):
            file.write(
                f"    {address} : {memory[address]:03X};\n"
            )

        file.write("END;\n")


# ============================================================
# PROGRAMA PRINCIPAL
# ============================================================

def main():

    image_path = Path(IMAGE_FILE)

    if not image_path.exists():
        raise FileNotFoundError(
            f"Imagem não encontrada: {IMAGE_FILE}"
        )

    # --------------------------------------------------------
    # Abre a imagem
    # --------------------------------------------------------

    image = Image.open(image_path)

    # Mantém alpha caso exista
    if image.mode not in ("RGB", "RGBA"):
        image = image.convert("RGBA")

    print(f"Imagem: {image.size}")
    print(f"Modo: {image.mode}")

    # --------------------------------------------------------
    # Verifica tamanho
    # --------------------------------------------------------

    if image.size != (SPRITE_WIDTH, SPRITE_HEIGHT):
        raise ValueError(
            f"A imagem deve possuir exatamente "
            f"{SPRITE_WIDTH}x{SPRITE_HEIGHT} pixels."
        )

    # --------------------------------------------------------
    # Cria imagem RGB para quantização
    # --------------------------------------------------------

    if image.mode == "RGBA":

        # Preserva alpha separadamente
        alpha = image.getchannel("A")

        rgb_image = image.convert("RGB")

    else:

        alpha = None
        rgb_image = image.convert("RGB")

    # --------------------------------------------------------
    # Quantização
    # --------------------------------------------------------

    # 255 cores porque o índice 0 é reservado para transparência.
    quantized = rgb_image.quantize(
        colors=MAX_COLORS,
        dither=Image.Dither.NONE
    )

    # Obtém a paleta RGB produzida pelo Pillow.
    palette_data = quantized.getpalette()

    # --------------------------------------------------------
    # Cria mapa:
    #
    # RGB original -> índice do sprite
    # --------------------------------------------------------

    color_to_index = {}

    palette = []

    num_colors = len(palette_data) // 3

    for i in range(num_colors):

        r = palette_data[i * 3]
        g = palette_data[i * 3 + 1]
        b = palette_data[i * 3 + 2]

        rgb = (r, g, b)

        # índice 0 é reservado para transparência.
        sprite_index = i + 1

        color_to_index[rgb] = sprite_index
        palette.append(rgb)

    # --------------------------------------------------------
    # Se houver transparência, precisamos garantir que os
    # pixels transparentes não sejam tratados como cor.
    # --------------------------------------------------------

    if alpha is not None:

        pixels = image.load()

        for y in range(SPRITE_HEIGHT):
            for x in range(SPRITE_WIDTH):

                if pixels[x, y][3] == 0:
                    continue

                rgb = pixels[x, y][:3]

                if rgb not in color_to_index:
                    raise RuntimeError(
                        "Foi encontrado um RGB que não está "
                        "presente na paleta quantizada."
                    )

    # --------------------------------------------------------
    # Gera arquivos
    # --------------------------------------------------------

    generate_pattern_mif(
        image,
        color_to_index
    )

    generate_palette_mif(
        palette
    )

    # --------------------------------------------------------
    # Informações finais
    # --------------------------------------------------------

    print()
    print("Arquivos gerados:")
    print(f"  {PATTERN_MIF}")
    print(f"  {PALETTE_MIF}")
    print()
    print(f"Cores disponíveis: {len(palette)}")
    print("Índice 0: transparente")
    print("Banco de paleta 0: 0..255")
    print("Banco de paleta 1: 256..511")
    print()
    print("Conversão concluída.")


if __name__ == "__main__":
    main()