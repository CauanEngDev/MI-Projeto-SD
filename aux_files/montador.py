#!/usr/bin/env python3
"""
Montador da ISA do coprocessador grafico.

Uso:
    python3 montador.py programa.asm                 # gera programa.mif, .hex e .lst
    python3 montador.py programa.asm -o saida        # gera saida.mif, saida.hex e saida.lst
    python3 montador.py programa.asm --depth 16384   # profundidade da memoria

Saidas:
    .mif  conteudo inicial da instruction_memory (init_file no Quartus)
    .hex  uma palavra por linha, para $readmemh nas simulacoes
    .lst  listagem com endereco, palavra, campos em binario e a linha de origem

Sintaxe (um comando por linha; comentarios com ';' ou '//'):
    PASS  R0, #10            ; Rd = imm12
    ADD   R2, R0, R1         ; Rd = Rn + Rm
    LSL   R5, R4, #1         ; Rd = Rn << 1
    SET_PALETTE R3, R4       ; Ra, Rb
    DRAW_RECT                ; sem operandos (argumentos em R0-R7)
    HALT

Registradores: R0..R30, R31 (ou XZR), R36 (ou FLAGS) como fonte.
Imediatos: #10, #0x1F, #0b101 (0 a 4095; para LSL/LSR, 0 a 31).
"""
import argparse
import re
import sys

OPCODES = {
    "NOP": 0b00000, "ADD": 0b00001, "SUB": 0b00010, "AND": 0b00011,
    "LSL": 0b00100, "LSR": 0b00101, "PASS": 0b00110,
    "SET_PALETTE": 0b00111, "DRAW_RECT": 0b01000, "DRAW_TRI": 0b01001,
    "SET_SPRITE_POS": 0b01010, "SET_SPRITE_ATTR": 0b01011,
    "SET_TILEMAP": 0b01100, "SCROLL_BG": 0b01101,
    "WRITE_SPRITE_DATA": 0b01110, "WRITE_TILE_DATA": 0b01111,
    "DRAW_BG": 0b10000, "DRAW_SPRITES": 0b10001,
    "WAIT_VBLANK": 0b10010, "HALT": 0b10011,
}
FMT_A3 = {"ADD", "SUB", "AND", "LSL", "LSR"}     # Rd, Rn, Rm|#imm
FMT_A2 = {"PASS"}                                # Rd, Rm|#imm
FMT_G = {"SET_PALETTE", "SET_SPRITE_POS", "SET_SPRITE_ATTR", "SET_TILEMAP",
         "SCROLL_BG", "WRITE_SPRITE_DATA", "WRITE_TILE_DATA"}   # Ra, Rb
FMT_N = {"NOP", "DRAW_RECT", "DRAW_TRI", "DRAW_BG", "DRAW_SPRITES",
         "WAIT_VBLANK", "HALT"}


class ErroMontagem(Exception):
    pass


def reg(token, max_reg):
    t = token.strip().upper()
    if t == "XZR":
        return 31
    if t == "FLAGS":
        return 36
    m = re.fullmatch(r"R(\d+)", t)
    if not m:
        raise ErroMontagem(f"registrador invalido: '{token.strip()}'")
    n = int(m.group(1))
    if n > max_reg:
        raise ErroMontagem(f"R{n} fora do intervalo (maximo R{max_reg})")
    return n


def imediato(token):
    t = token.strip()
    if not t.startswith("#"):
        raise ErroMontagem(f"imediato deve comecar com '#': '{t}'")
    try:
        v = int(t[1:], 0)
    except ValueError:
        raise ErroMontagem(f"imediato invalido: '{t}'")
    if not 0 <= v <= 4095:
        raise ErroMontagem(f"imediato {v} fora de 0..4095 (imm12 sem sinal)")
    return v


def segundo_operando(token, mnem):
    """Retorna (I, valor): registrador Rm ou imediato imm12."""
    if token.strip().startswith("#"):
        v = imediato(token)
        if mnem in ("LSL", "LSR") and v > 31:
            raise ErroMontagem(f"{mnem}: deslocamento {v} fora de 0..31")
        return 1, v
    return 0, reg(token, 36)


def codificar(mnem, ops):
    """Retorna (palavra, descricao_dos_campos)."""
    op = OPCODES[mnem]
    if mnem in FMT_N:
        if ops:
            raise ErroMontagem(f"{mnem} nao tem operandos")
        w = op << 27
        return w, f"{op:05b} {w & 0x7FFFFFF:027b}"
    if mnem in FMT_G:
        if len(ops) != 2:
            raise ErroMontagem(f"{mnem} espera 2 operandos (Ra, Rb)")
        ra, rb = reg(ops[0], 36), reg(ops[1], 36)
        w = (op << 27) | (ra << 21) | (rb << 15)
        return w, f"{op:05b} {ra:06b} {rb:06b} {0:015b}"
    if mnem in FMT_A3:
        if len(ops) != 3:
            raise ErroMontagem(f"{mnem} espera 3 operandos (Rd, Rn, Rm|#imm)")
        rd, rn = reg(ops[0], 31), reg(ops[1], 36)
        i, v = segundo_operando(ops[2], mnem)
    else:  # PASS
        if len(ops) != 2:
            raise ErroMontagem("PASS espera 2 operandos (Rd, Rm|#imm)")
        rd, rn = reg(ops[0], 31), 31
        i, v = segundo_operando(ops[1], mnem)
    w = (op << 27) | (i << 26) | (rd << 21) | (rn << 15) | v
    return w, f"{op:05b} {i:01b} {rd:05b} {rn:06b} {0:03b} {v:012b}"


def montar(linhas):
    prog = []   # (palavra, campos, texto_original)
    for num, bruto in enumerate(linhas, 1):
        texto = re.split(r";|//", bruto, maxsplit=1)[0].strip()
        if not texto:
            continue
        partes = texto.split(None, 1)
        mnem = partes[0].upper()
        ops = [o for o in (partes[1].split(",") if len(partes) > 1 else []) if o.strip()]
        if mnem not in OPCODES:
            raise ErroMontagem(f"linha {num}: instrucao desconhecida '{partes[0]}'")
        try:
            w, campos = codificar(mnem, ops)
        except ErroMontagem as e:
            raise ErroMontagem(f"linha {num}: {e}")
        prog.append((w, campos, " ".join(texto.split())))
    return prog


def escrever(base, prog, depth, origem):
    largura = max(4, (depth - 1).bit_length() // 4 + 1)
    with open(base + ".mif", "w") as f:
        f.write(f"-- gerado por montador.py a partir de {origem}\n")
        f.write(f"WIDTH=32;\nDEPTH={depth};\n")
        f.write("ADDRESS_RADIX=HEX;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n")
        for a, (w, _, t) in enumerate(prog):
            f.write(f"    {a:0{largura}X} : {w:08X};  -- {t}\n")
        if len(prog) < depth:
            f.write(f"    [{len(prog):0{largura}X}..{depth-1:0{largura}X}] : 00000000;  -- NOP (preenchimento)\n")
        f.write("END;\n")
    with open(base + ".hex", "w") as f:
        for a, (w, _, t) in enumerate(prog):
            f.write(f"{w:08X} // {a:04X}: {t}\n")
    with open(base + ".lst", "w") as f:
        f.write("end  palavra   campos (binario)                                   fonte\n")
        for a, (w, c, t) in enumerate(prog):
            f.write(f"{a:04X} {w:08X}  {c:<50} {t}\n")


def main():
    ap = argparse.ArgumentParser(description="Montador da ISA do coprocessador grafico")
    ap.add_argument("fonte")
    ap.add_argument("-o", "--saida", help="prefixo dos arquivos de saida")
    ap.add_argument("--depth", type=int, default=16384, help="palavras da memoria (padrao 16384)")
    a = ap.parse_args()
    base = a.saida or re.sub(r"\.[^.]*$", "", a.fonte)
    with open(a.fonte) as f:
        linhas = f.readlines()
    try:
        prog = montar(linhas)
    except ErroMontagem as e:
        print(f"erro: {e}", file=sys.stderr)
        sys.exit(1)
    if len(prog) > a.depth:
        print(f"erro: {len(prog)} instrucoes excedem a profundidade {a.depth}", file=sys.stderr)
        sys.exit(1)
    if not any(t.split()[0].upper() == "HALT" for _, _, t in prog):
        print("aviso: o programa nao tem HALT; a busca so para no fim da memoria", file=sys.stderr)
    escrever(base, prog, a.depth, a.fonte)
    print(f"{len(prog)} instrucoes -> {base}.mif, {base}.hex, {base}.lst")


if __name__ == "__main__":
    main()
