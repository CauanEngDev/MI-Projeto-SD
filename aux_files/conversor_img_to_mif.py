from PIL import Image
from pathlib import Path


# ============================================================
# CONFIGURAÇÕES
# ============================================================

PROJECT_DIR = Path(__file__).resolve().parent.parent

IMAGE_FILE = (
    PROJECT_DIR
    / "aux_files"
    / "Sonic.png"
)

OUTPUT_DIR = (
    PROJECT_DIR
    / "memory_files"
    / "initialization_files"
)

PALETTE_MIF = "sprite_palette_sonic.mif"


# ============================================================
# PALETA
# ============================================================

PALETTE_DEPTH = 512
MAX_COLORS = 255


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
# CRIA PALETA DO SONIC
# ============================================================

def create_sonic_palette(image):

    pixels = image.load()

    rgb999_to_index = {}
    sonic_palette = []

    for y in range(image.height):

        for x in range(image.width):

            pixel = pixels[x, y]

            # ------------------------------------------------
            # RGBA
            # ------------------------------------------------

            if image.mode == "RGBA":

                r, g, b, a = pixel

                # Transparência = índice 0
                if a == 0:
                    continue

            # ------------------------------------------------
            # RGB
            # ------------------------------------------------

            else:

                r, g, b = pixel

            rgb999 = rgb888_to_rgb999(
                (r, g, b)
            )

            # ------------------------------------------------
            # Nova cor
            # ------------------------------------------------

            if rgb999 not in rgb999_to_index:

                if len(sonic_palette) >= MAX_COLORS:

                    raise ValueError(
                        "O Sonic possui mais de "
                        "255 cores distintas em RGB999."
                    )

                # Índice 0 é reservado para transparente
                index = len(sonic_palette) + 1

                rgb999_to_index[rgb999] = index

                sonic_palette.append(rgb999)

    return sonic_palette


# ============================================================
# GERA PALETA MIF
# ============================================================

def generate_palette_mif(sonic_palette):

    memory = [0] * PALETTE_DEPTH

    # --------------------------------------------------------
    # BANCO 0
    # --------------------------------------------------------
    #
    # Endereço 0   = transparente
    # Endereço 1   = primeira cor do Sonic
    # Endereço 2   = segunda cor do Sonic
    # ...
    #
    # Todo o banco 0 corresponde ao Sonic.
    # --------------------------------------------------------

    for index, rgb999 in enumerate(
        sonic_palette,
        start=1
    ):

        memory[index] = rgb999

    # --------------------------------------------------------
    # BANCO 1
    # --------------------------------------------------------
    #
    # Não utilizado.
    # Permanece zerado.
    # --------------------------------------------------------

    for address in range(256, 512):

        memory[address] = 0

    # --------------------------------------------------------
    # ESCREVE MIF
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
        f"Paleta MIF gerada: {output_path}"
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
    # VERIFICA IMAGEM
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
    # GARANTE RGB/RGBA
    # --------------------------------------------------------

    if image.mode not in (
        "RGB",
        "RGBA"
    ):

        image = image.convert("RGBA")

    # --------------------------------------------------------
    # CRIA PALETA
    # --------------------------------------------------------

    sonic_palette = create_sonic_palette(
        image
    )

    print(
        f"Cores distintas do Sonic: "
        f"{len(sonic_palette)}"
    )

    print(
        "Banco utilizado: 0"
    )

    print(
        "Índice 0: transparente"
    )

    # --------------------------------------------------------
    # GERA PALETA
    # --------------------------------------------------------

    generate_palette_mif(
        sonic_palette
    )

    print()
    print(
        "Arquivo gerado com sucesso."
    )

    print(
        f"Arquivo: "
        f"{OUTPUT_DIR / PALETTE_MIF}"
    )


# ============================================================
# EXECUÇÃO
# ============================================================

if __name__ == "__main__":
    main()