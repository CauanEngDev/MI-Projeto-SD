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
    PASS  V0X, #80           ; Rd = 37 (vertice 0, X)
    SET_PALETTE R3, R4       ; Ra, Rb
    DRAW_RECT                ; sem operandos (vertices/cor em V0X..COLOR)
    HALT

Labels e desvios:
    loop:                    ; label (sozinho na linha ou antes da instrucao)
        SUB   R5, R5, #1
        B.NE  loop           ; desvia se Z = 0 (flags da ultima instrucao da ULA)
        B     fim            ; incondicional
    fim:  HALT
    B     #-3                ; tambem aceita deslocamento literal, em palavras,
                             ; relativo a propria instrucao de desvio
  Condicoes (B.cond): EQ NE HS LO MI PL VS VC HI LS GE LT GT LE AL.
  Comparar sem guardar o resultado: SUB XZR, Rn, Rm|#imm (XZR descarta o
  resultado, mas as flags sao atualizadas).

Registradores: R0..R30, XZR (31), STATUS (33, so leitura), FLAGS (36, so
leitura), V0X V0Y V1X V1Y V2X V2Y COLOR (37 a 43, ou R37..R43).
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
    "B": 0b10100, "B_COND": 0b10101,
}
CONDICOES = {
    "EQ": 0, "NE": 1, "HS": 2, "LO": 3, "MI": 4, "PL": 5, "VS": 6, "VC": 7,
    "HI": 8, "LS": 9, "GE": 10, "LT": 11, "GT": 12, "LE": 13, "AL": 14,
}
ALIAS_REG = {
    "XZR": 31, "STATUS": 33, "FLAGS": 36,
    "V0X": 37, "V0Y": 38, "V1X": 39, "V1Y": 40, "V2X": 41, "V2Y": 42, "COLOR": 43,
}
REG_MAX = 43                      # maior registrador enderecavel
RD_VALIDOS = set(range(0, 32)) | set(range(37, 44))   # destinos aceitos
OFFSET_BITS = 14                  # campo de deslocamento dos desvios (palavras)
FMT_A3 = {"ADD", "SUB", "AND", "LSL", "LSR"}     # Rd, Rn, Rm|#imm
FMT_A2 = {"PASS"}                                # Rd, Rm|#imm
FMT_G = {"SET_PALETTE", "SET_SPRITE_POS", "SET_SPRITE_ATTR", "SET_TILEMAP",
         "SCROLL_BG", "WRITE_SPRITE_DATA", "WRITE_TILE_DATA"}   # Ra, Rb
FMT_N = {"NOP", "DRAW_RECT", "DRAW_TRI", "DRAW_BG", "DRAW_SPRITES",
         "WAIT_VBLANK", "HALT"}


class ErroMontagem(Exception):
    pass


def reg(token, max_reg=REG_MAX, destino=False):
    t = token.strip().upper()
    if t in ALIAS_REG:
        n = ALIAS_REG[t]
    else:
        m = re.fullmatch(r"R(\d+)", t)
        if not m:
            raise ErroMontagem(f"registrador invalido: '{token.strip()}'")
        n = int(m.group(1))
    if n > max_reg:
        raise ErroMontagem(f"R{n} fora do intervalo (maximo R{max_reg})")
    if destino and n not in RD_VALIDOS:
        raise ErroMontagem(f"R{n} nao pode ser destino (aceitos: R0-R30, XZR, R37-R43)")
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
    return 0, reg(token)


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
        ra, rb = reg(ops[0]), reg(ops[1])
        w = (op << 27) | (ra << 21) | (rb << 15)
        return w, f"{op:05b} {ra:06b} {rb:06b} {0:015b}"
    if mnem in FMT_A3:
        if len(ops) != 3:
            raise ErroMontagem(f"{mnem} espera 3 operandos (Rd, Rn, Rm|#imm)")
        rd, rn = reg(ops[0], destino=True), reg(ops[1])
        i, v = segundo_operando(ops[2], mnem)
    else:  # PASS
        if len(ops) != 2:
            raise ErroMontagem("PASS espera 2 operandos (Rd, Rm|#imm)")
        rd, rn = reg(ops[0], destino=True), 31
        i, v = segundo_operando(ops[1], mnem)
    # Rd tem 6 bits: Rd = {bit 14, bits 25:21}
    w = (op << 27) | (i << 26) | ((rd & 31) << 21) | (rn << 15) | ((rd >> 5) << 14) | v
    return w, f"{op:05b} {i:01b} {rd & 31:05b} {rn:06b} {rd >> 5:01b}{0:02b} {v:012b}"


def codificar_desvio(mnem, cond, destino, indice, rotulos):
    """B / B_COND. destino: label ou '#deslocamento'. Retorna (palavra, campos)."""
    op = OPCODES[mnem]
    d = destino.strip()
    if d.startswith("#"):
        try:
            off = int(d[1:], 0)
        except ValueError:
            raise ErroMontagem(f"deslocamento invalido: '{d}'")
        lim = 1 << (OFFSET_BITS - 1)
        if not -lim <= off < lim:
            raise ErroMontagem(f"deslocamento {off} fora de {-lim}..{lim - 1}")
    else:
        if d not in rotulos:
            raise ErroMontagem(f"label indefinido: '{d}'")
        # o hardware soma o deslocamento ao PC com 14 bits de palavra (da a volta)
        off = rotulos[d] - indice
    campo = off & ((1 << OFFSET_BITS) - 1)
    w = (op << 27) | (cond << 23) | campo
    return w, f"{op:05b} {cond:04b} {0:09b} {campo:014b}"


ID_LABEL = r"[A-Za-z_][A-Za-z0-9_]*"


def montar(linhas):
    """Duas passadas: 1) separa labels e instrucoes; 2) codifica."""
    instr = []      # (num_linha, mnem, ops, texto)
    rotulos = {}    # nome -> indice da instrucao
    for num, bruto in enumerate(linhas, 1):
        texto = re.split(r";|//", bruto, maxsplit=1)[0].strip()
        while True:                       # zero ou mais "label:" no inicio
            m = re.match(rf"({ID_LABEL})\s*:\s*", texto)
            if not m:
                break
            nome = m.group(1)
            if nome in rotulos:
                raise ErroMontagem(f"linha {num}: label '{nome}' definido duas vezes")
            rotulos[nome] = len(instr)
            texto = texto[m.end():]
        if not texto:
            continue
        partes = texto.split(None, 1)
        mnem = partes[0].upper()
        ops = [o for o in (partes[1].split(",") if len(partes) > 1 else []) if o.strip()]
        instr.append((num, mnem, ops, " ".join(texto.split())))

    prog = []   # (palavra, campos, texto_original)
    for indice, (num, mnem, ops, texto) in enumerate(instr):
        try:
            if mnem == "B" or re.fullmatch(r"B\.[A-Z]{2}", mnem):
                if mnem == "B":
                    cond, nome_op = 0, "B"
                else:
                    c = mnem[2:]
                    if c not in CONDICOES:
                        raise ErroMontagem(f"condicao desconhecida '{c}' (use {' '.join(CONDICOES)})")
                    cond, nome_op = CONDICOES[c], "B_COND"
                if len(ops) != 1:
                    raise ErroMontagem(f"{mnem} espera 1 operando (label ou #deslocamento)")
                w, campos = codificar_desvio(nome_op, cond, ops[0], indice, rotulos)
            elif mnem in OPCODES and mnem != "B_COND":
                w, campos = codificar(mnem, ops)
            else:
                raise ErroMontagem(f"instrucao desconhecida '{mnem}'")
        except ErroMontagem as e:
            raise ErroMontagem(f"linha {num}: {e}")
        prog.append((w, campos, texto))
    return prog, rotulos


def escrever(base, prog, depth, origem, rotulos=None):
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
        por_end = {}
        for nome, a in (rotulos or {}).items():
            por_end.setdefault(a, []).append(nome)
        for a, (w, c, t) in enumerate(prog):
            for nome in por_end.get(a, []):
                f.write(f"                                                                {nome}:\n")
            f.write(f"{a:04X} {w:08X}  {c:<50} {t}\n")
        for nome in por_end.get(len(prog), []):   # label apos a ultima instrucao
            f.write(f"{'':64}{nome}:\n")


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
        prog, rotulos = montar(linhas)
    except ErroMontagem as e:
        print(f"erro: {e}", file=sys.stderr)
        sys.exit(1)
    if len(prog) > a.depth:
        print(f"erro: {len(prog)} instrucoes excedem a profundidade {a.depth}", file=sys.stderr)
        sys.exit(1)
    if not any(t.split()[0].upper() == "HALT" for _, _, t in prog):
        print("aviso: o programa nao tem HALT; a busca so para no fim da memoria", file=sys.stderr)
    escrever(base, prog, a.depth, a.fonte, rotulos)
    print(f"{len(prog)} instrucoes -> {base}.mif, {base}.hex, {base}.lst")


if __name__ == "__main__":
    main()
