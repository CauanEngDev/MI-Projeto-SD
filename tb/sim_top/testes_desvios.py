#!/usr/bin/env python3
"""
Testes de sistema dos desvios (B / B_COND) no coprocessador_top completo.

Executar a partir da raiz do projeto:
    python3 tb/sim_top/testes_desvios.py            # todos os cenarios
    python3 tb/sim_top/testes_desvios.py basico condicoes   # so alguns

Requer: iverilog (Icarus Verilog) e python3. As IPs do Quartus (PLL, RAMs) sao
substituidas por modelos em stubs_ip_quartus.v.

Cenarios
  basico         soma 1..10 num laco (desvio para tras), B com deslocamento
                 literal e desvio para frente
  condicoes      as 15 condicoes (EQ..AL) apos SUB, em 6 pares de valores,
                 conferidas contra a comparacao matematica
  animacao       retangulo que quica nas bordas + trilha em laco (7 frames)
  ultima_palavra B na ultima palavra da memoria e volta (modulo 16384)
  cond_reservada B_COND com condicao 1111: nao desvia e sinaliza erro
"""
import os, re, subprocess, sys, tempfile

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SIM = os.path.join(RAIZ, "tb", "sim_top")
sys.path.insert(0, os.path.join(RAIZ, "aux_files"))
import montador  # noqa: E402

RTL = [
    "rtl/core/coprocessador_top.v", "rtl/core/unidade_de_busca_de_instrucoes.v",
    "rtl/core/avalia_condicao.v", "rtl/core/unidade_de_controle.v",
    "rtl/core/banco_registradores.v", "rtl/core/alu.v", "rtl/core/Program_counter.v",
    "rtl/core/Adder.v", "rtl/core/camada_composicao.v", "rtl/utils/fb_addr_gen.v",
    "rtl/utils/framebuffer.v", "rtl/drivers/vga_driver.v",
    "rtl/motores_independentes/motor_background.v", "rtl/motores_independentes/motor_sprite.v",
    "rtl/rasterizers/rasterizador_top.v", "rtl/rasterizers/rasterizador_quadrado.v",
    "rtl/rasterizers/rasterizador_triangulo.v", "rtl/utils/divisor_unsigned.v",
]
TMP = tempfile.mkdtemp(prefix="desvios_")
VVP = os.path.join(TMP, "top.vvp")


def compilar():
    cmd = ["iverilog", "-g2005", "-o", VVP, os.path.join(SIM, "tb_top_desvios.v"),
           os.path.join(SIM, "stubs_ip_quartus.v")] + [os.path.join(RAIZ, f) for f in RTL]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        print(r.stdout, r.stderr); sys.exit("falha ao compilar")


def hex_de_asm(texto, nome):
    prog, _ = montador.montar(texto.splitlines())
    return hex_de_palavras([w for w, _, _ in prog], nome)


def hex_de_palavras(palavras, nome):
    caminho = os.path.join(TMP, nome + ".hex")
    with open(caminho, "w") as f:
        for w in palavras:
            f.write(f"{w:08x}\n")
    return caminho


def simular(hexfile, frames=1):
    r = subprocess.run(["vvp", VVP, f"+HEX={hexfile}", f"+FRAMES={frames}"],
                       capture_output=True, text=True, timeout=3000)
    halts, frames_out = [], []
    for linha in r.stdout.splitlines():
        if linha.startswith("HALT"):
            halts.append({k: int(v, 2) if k == "ERR" else int(v)
                          for k, v in re.findall(r"(\w+)=(-?\w+)", linha)})
        elif linha.startswith("FRAME"):
            frames_out.append({k: int(v) for k, v in re.findall(r"(\w+)=(-?\d+)", linha)})
        elif linha.startswith("TIMEOUT"):
            sys.exit("TIMEOUT: " + linha)
    return halts, frames_out


# --------------------------------------------------------------------------
falhas = []


def confere(cenario, nome, obtido, esperado):
    if obtido == esperado:
        print(f"  ok    {nome}: {obtido}")
    else:
        print(f"  ERRO  {nome}: obtido {obtido}, esperado {esperado}")
        falhas.append(f"{cenario}: {nome}")


def carrega32(reg, v):
    """PASS/LSL/ADD que montam uma constante de 32 bits em reg."""
    v &= 0xFFFFFFFF
    return [f"PASS {reg}, #{v >> 20}", f"LSL {reg}, {reg}, #12",
            f"ADD {reg}, {reg}, #{(v >> 8) & 0xFFF}", f"LSL {reg}, {reg}, #8",
            f"ADD {reg}, {reg}, #{v & 0xFF}"]


def cenario_basico():
    asm = """
        PASS R1, #10
        PASS R2, #0
    laco:
        ADD  R2, R2, R1        ; R2 += R1
        SUB  R1, R1, #1
        B.NE laco              ; desvio para tras (R1 != 0)
        PASS R3, #1
        B    #2                ; deslocamento literal: pula a proxima instrucao
        PASS R3, #99           ; nao deve executar
        PASS R4, #7
        B    adiante           ; desvio para frente
        PASS R4, #99           ; nao deve executar
    adiante:
        SUB  XZR, R4, #7
        B.EQ fim               ; tomado (R4 == 7)
        PASS R5, #99           ; nao deve executar
    fim:
        HALT
    """
    h, _ = simular(hex_de_asm(asm, "basico"))
    r = h[0]
    confere("basico", "R2 = 10+9+...+1", r["R2"], 55)
    confere("basico", "R1 (contador)", r["R1"], 0)
    confere("basico", "R3 (B #2 pulou o PASS #99)", r["R3"], 1)
    confere("basico", "R4 (B label pulou o PASS #99)", r["R4"], 7)
    confere("basico", "R5 (B.EQ tomado)", r["R5"], 0)
    confere("basico", "sem erro", r["ERR"], 0)


def cond_verdade(c, a, b):
    ua, ub = a & 0xFFFFFFFF, b & 0xFFFFFFFF
    sa = ua - (1 << 32) if ua >> 31 else ua
    sb = ub - (1 << 32) if ub >> 31 else ub
    dif = (ua - ub) & 0xFFFFFFFF
    ovf = not (-(1 << 31) <= sa - sb < (1 << 31))
    return [ua == ub, ua != ub, ua >= ub, ua < ub, bool(dif >> 31), not (dif >> 31),
            ovf, not ovf, ua > ub, ua <= ub, sa >= sb, sa < sb, sa > sb, sa <= sb, True][c]


def cenario_condicoes():
    pares = [(3, 5), (5, 3), (5, 5), (-1, 1), (0x7FFFFFFF, -1), (0x80000000, 1)]
    linhas = ["PASS R10, #0", "PASS R9, #0"]
    for i, (a, b) in enumerate(pares):
        linhas += carrega32("R1", a) + carrega32("R2", b)
        for c, nome in enumerate(montador.CONDICOES):          # EQ..AL
            soma = "R10" if c < 12 else "R9"
            peso = 1 << (c if c < 12 else c - 12)
            linhas += [f"SUB XZR, R1, R2",
                       f"B.{nome} t{i}_{c}",
                       f"B f{i}_{c}",
                       f"t{i}_{c}:",
                       f"ADD {soma}, {soma}, #{peso}",
                       f"f{i}_{c}:"]
        linhas += ["LSL R9, R9, #12", f"ADD R{11 + i}, R10, R9", "PASS R10, #0", "PASS R9, #0"]
    linhas.append("HALT")
    h, _ = simular(hex_de_asm("\n".join(linhas), "condicoes"))
    for i, (a, b) in enumerate(pares):
        esp = sum(1 << c for c in range(15) if cond_verdade(c, a, b))
        confere("condicoes", f"mascara das condicoes para a={a:#x}, b={b:#x}", h[0][f"R{11 + i}"], esp)
    confere("condicoes", "sem erro", h[0]["ERR"], 0)


def cenario_animacao():
    with open(os.path.join(SIM, "programas", "animacao_quicando.asm")) as f:
        hexfile = hex_de_asm(f.read(), "animacao")
    h, fr = simular(hexfile, frames=7)
    xs_esperado = [100, 200, 270, 170, 70, 0, 100]          # com quique em 270 e em 0
    dx_esperado = [100, 100, -100, -100, -100, 100, 100]
    confere("animacao", "frames observados", len(fr), 7)
    for k in range(min(7, len(fr), len(h))):
        confere("animacao", f"frame {k + 1}: x do retangulo", fr[k]["red_xmin"], xs_esperado[k])
        confere("animacao", f"frame {k + 1}: R1 / R2 (x, dx)", (h[k]["R1"], h[k]["R2"]), (xs_esperado[k], dx_esperado[k]))
        confere("animacao", f"frame {k + 1}: pixels vermelho/azul/fundo",
                (fr[k]["red"], fr[k]["blue"], fr[k]["bg"]), (1600, 400, 76800 - 2000))
        confere("animacao", f"frame {k + 1}: contador da trilha (R5)", h[k]["R5"], 0)


def word_b(op_off):          # B com deslocamento (modulo 14 bits)
    return (0b10100 << 27) | (op_off & 0x3FFF)


def cenario_ultima_palavra():
    n = 16384
    mem = [0] * n
    mem[0] = word_b(n - 1)                       # palavra 0 -> ultima palavra
    mem[1] = montador.codificar("PASS", ["R3", "#99"])[0]
    mem[2] = montador.OPCODES["HALT"] << 27
    mem[n - 1] = word_b(2)                       # ultima palavra: +2 da a volta e cai na palavra 1
    h, _ = simular(hex_de_palavras(mem, "ultima"))
    confere("ultima_palavra", "R3 (passou pela ultima palavra e voltou)", h[0]["R3"], 99)
    confere("ultima_palavra", "sem erro", h[0]["ERR"], 0)


def cenario_cond_reservada():
    mem = [montador.codificar("PASS", ["R1", "#1"])[0],
           (0b10101 << 27) | (0b1111 << 23) | 2,         # B_COND, condicao 1111, +2
           montador.codificar("PASS", ["R3", "#5"])[0],
           montador.codificar("PASS", ["R4", "#6"])[0],
           montador.OPCODES["HALT"] << 27]
    h, _ = simular(hex_de_palavras(mem + [0] * (16384 - len(mem)), "reservada"))
    confere("cond_reservada", "R3 (nao desviou)", h[0]["R3"], 5)
    confere("cond_reservada", "R4 (nao desviou)", h[0]["R4"], 6)
    confere("cond_reservada", "erro sinalizado (LEDR[2])", h[0]["ERR"], 1)


CENARIOS = {"basico": cenario_basico, "condicoes": cenario_condicoes, "animacao": cenario_animacao,
            "ultima_palavra": cenario_ultima_palavra, "cond_reservada": cenario_cond_reservada}

if __name__ == "__main__":
    escolhidos = sys.argv[1:] or list(CENARIOS)
    compilar()
    for nome in escolhidos:
        print(f"[{nome}]")
        CENARIOS[nome]()
    print()
    if falhas:
        print(f"{len(falhas)} FALHA(S):"); [print("  -", f) for f in falhas]; sys.exit(1)
    print("testes_desvios: TODOS OS CENARIOS PASSARAM")
