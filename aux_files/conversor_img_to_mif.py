from PIL import Image
from pathlib import Path
import re


# ============================================================
# CONFIGURAÇÕES
# ============================================================

IMAGE_FILE = Path(
    r"F:\Mi-Projeto-SD\MI-Projeto-SD-master\aux_files\Sonic.png"
)

# MIF de paleta que já existe no projeto
GLOBAL_PALETTE_MIF = Path(
    r"F:\Mi-Projeto-SD\MI-Projeto-SD-master\memory_files\initialization_files\palette_default.mif"
)

OUTPUT_DIR = Path(
    r"F:\Mi-Projeto-SD\MI-Projeto-SD-master\memory_files\initialization_files"
)

PATTERN_MIF = "sprite_pattern_sonic.mif"
PALETTE_MIF = "sprite_palette_sonic.mif"


# ============================================================
# SPRITE
# ============================================================

SPRITE_WIDTH = 16
SPRITE_HEIGHT = 16

PATTERN_DEPTH = 16384

# Índice 0 = transparente
TRANSPARENT_INDEX = 0


# ============================================================
# PALETA
# ============================================================

PALETTE_DEPTH = 512
MAX_COLORS = 255

# Sonic será colocado no banco 1
PALETTE_BANK = 1


# ============================================================
# RGB888 -> RGB999
# ============================================================

def rgb888_to_rgb999(rgb):

    r, g, b = rgb

    r3 = r >> 5
    g3 = g >> 5
    b3 = b >> 5

    return (
        (r3 << 6)
        | (g3 << 3)
        | b3
    )


# ============================================================
# LÊ A PALETA GLOBAL
# ============================================================

def load_global_palette():

    if not GLOBAL_PALETTE_MIF.exists():
        raise FileNotFoundError(
            f"Paleta global não encontrada:\n"
            f"{GLOBAL_PALETTE_MIF}"
        )

    palette = [0] * 256

    with open(GLOBAL_PALETTE_MIF, "r") as file:

        for line in file:

            line = line.strip()

            # Procura linhas no formato:
            #
            # 0 : 1C7;
            # 1 : 1C0;
            #
            match = re.match(
                r"^(\d+)\s*:\s*([0-9A-Fa-f]+)\s*;",
                line
            )

            if match is None:
                continue

            address = int(match.group(1))
            value = int(match.group(2), 16)

            # Somente banco 0
            if 0 <= address < 256:

                palette[address] = value

    return palette


# ============================================================
# CRIA PALETA DO SONIC
# ============================================================

def create_sonic_palette(image):

    pixels = image.load()

    rgb999_to_index = {}
    sonic_palette = []

    for y in range(SPRITE_HEIGHT):

        for x in range(SPRITE_WIDTH):

            pixel = pixels[x, y]

            if image.mode == "RGBA":

                r, g, b, a = pixel

                # Transparente não entra na paleta
                if a == 0:
                    continue

            else:

                r, g, b = pixel

            rgb999 = rgb888_to_rgb999(
                (r, g, b)
            )

            if rgb999 not in rgb999_to_index:

                if len(sonic_palette) >= MAX_COLORS:

                    raise ValueError(
                        "O Sonic possui mais de "
                        "255 cores distintas em RGB999."
                    )

                index = len(sonic_palette) + 1

                rgb999_to_index[rgb999] = index

                sonic_palette.append(rgb999)

    return sonic_palette, rgb999_to_index


# ============================================================
# GERA PATTERN MIF
# ============================================================

def generate_pattern_mif(
    image,
    rgb999_to_index
):

    memory = [0] * PATTERN_DEPTH

    pixels = image.load()

    for y in range(SPRITE_HEIGHT):

        for x in range(SPRITE_WIDTH):

            # ------------------------------------------------
            # Identifica o tile 8x8
            # ------------------------------------------------

            tile_x = x // 8
            tile_y = y // 8

            tile_id = (
                (tile_y << 1)
                | tile_x
            )

            # ------------------------------------------------
            # Coordenada dentro do tile
            # ------------------------------------------------

            local_x = x % 8
            local_y = y % 8

            # ------------------------------------------------
            # Endereço da pattern RAM
            # ------------------------------------------------

            address = (
                tile_id * 64
                + local_y * 8
                + local_x
            )

            pixel = pixels[x, y]

            # ------------------------------------------------
            # Transparência
            # ------------------------------------------------

            if image.mode == "RGBA":

                r, g, b, a = pixel

                if a == 0:

                    index = TRANSPARENT_INDEX

                else:

                    rgb999 = rgb888_to_rgb999(
                        (r, g, b)
                    )

                    index = rgb999_to_index[rgb999]

            else:

                r, g, b = pixel

                rgb999 = rgb888_to_rgb999(
                    (r, g, b)
                )

                index = rgb999_to_index[rgb999]

            memory[address] = index

    # --------------------------------------------------------
    # Escreve MIF
    # --------------------------------------------------------

    output_path = OUTPUT_DIR / PATTERN_MIF

    with open(output_path, "w") as file:

        file.write("WIDTH=8;\n")
        file.write(f"DEPTH={PATTERN_DEPTH};\n")
        file.write("ADDRESS_RADIX=DECIMAL;\n")
        file.write("DATA_RADIX=HEX;\n")
        file.write("CONTENT BEGIN\n")

        for address in range(256):

            file.write(
                f"    {address} : "
                f"{memory[address]:02X};\n"
            )

        file.write("END;\n")

    print(
        f"Pattern MIF gerado: {output_path}"
    )


# ============================================================
# GERA PALETA COMPLETA
# ============================================================

def generate_palette_mif(
    global_palette,
    sonic_palette
):

    memory = [0] * PALETTE_DEPTH

    # --------------------------------------------------------
    # BANCO 0
    # --------------------------------------------------------
    #
    # Preserva exatamente a paleta existente.
    # --------------------------------------------------------

    for address in range(256):

        memory[address] = global_palette[address]

    # --------------------------------------------------------
    # BANCO 1
    # --------------------------------------------------------
    #
    # Índice 0 = transparente
    #
    # Endereço 256 = índice 0
    # Endereço 257 = índice 1
    # Endereço 258 = índice 2
    # ...
    # --------------------------------------------------------

    memory[256] = 0

    for index, rgb999 in enumerate(
        sonic_palette,
        start=1
    ):

        address = 256 + index

        memory[address] = rgb999

    # --------------------------------------------------------
    # Escreve MIF
    # --------------------------------------------------------

    output_path = OUTPUT_DIR / PALETTE_MIF

    with open(output_path, "w") as file:

        file.write("WIDTH=9;\n")
        file.write(f"DEPTH={PALETTE_DEPTH};\n")
        file.write("ADDRESS_RADIX=DECIMAL;\n")
        file.write("DATA_RADIX=HEX;\n")
        file.write("CONTENT BEGIN\n")

        for address in range(PALETTE_DEPTH):

            file.write(
                f"    {address} : "
                f"{memory[address]:03X};\n"
            )

        file.write("END;\n")

    print(
        f"Palette MIF gerado: {output_path}"
    )


# ============================================================
# MAIN
# ============================================================

def main():

    OUTPUT_DIR.mkdir(
        parents=True,
        exist_ok=True
    )

    # --------------------------------------------------------
    # Verifica imagem
    # --------------------------------------------------------

    if not IMAGE_FILE.exists():

        raise FileNotFoundError(
            f"Imagem não encontrada:\n"
            f"{IMAGE_FILE}"
        )

    image = Image.open(IMAGE_FILE)

    print(
        f"Imagem: {image.size}"
    )

    print(
        f"Modo: {image.mode}"
    )

    # --------------------------------------------------------
    # Verifica tamanho
    # --------------------------------------------------------

    if image.size != (
        SPRITE_WIDTH,
        SPRITE_HEIGHT
    ):

        raise ValueError(
            f"A imagem deve possuir "
            f"{SPRITE_WIDTH}x{SPRITE_HEIGHT} pixels."
        )

    # --------------------------------------------------------
    # Garante RGB/RGBA
    # --------------------------------------------------------

    if image.mode not in (
        "RGB",
        "RGBA"
    ):

        image = image.convert("RGBA")

    # --------------------------------------------------------
    # Lê paleta existente
    # --------------------------------------------------------

    global_palette = load_global_palette()

    print(
        "Paleta global carregada."
    )

    # --------------------------------------------------------
    # Cria paleta do Sonic
    # --------------------------------------------------------

    sonic_palette, rgb999_to_index = (
        create_sonic_palette(image)
    )

    print(
        f"Cores distintas do Sonic: "
        f"{len(sonic_palette)}"
    )

    print(
        f"Banco da paleta: {PALETTE_BANK}"
    )

    print(
        "Índice 0: transparente"
    )

    # --------------------------------------------------------
    # Gera pattern
    # --------------------------------------------------------

    generate_pattern_mif(
        image,
        rgb999_to_index
    )

    # --------------------------------------------------------
    # Gera paleta completa
    # --------------------------------------------------------

    generate_palette_mif(
        global_palette,
        sonic_palette
    )

    print()
    print(
        "Arquivos gerados com sucesso."
    )

    print(
        f"Diretório: {OUTPUT_DIR}"
    )


# ============================================================
# EXECUÇÃO
# ============================================================

if __name__ == "__main__":
    main()