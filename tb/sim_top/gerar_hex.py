import sys, os
OP = dict(NOP=0,ADD=1,SUB=2,AND=3,LSL=4,LSR=5,PASS=6,SET_PALETTE=7,DRAW_RECT=8,DRAW_TRI=9,
          SET_SPRITE_POS=10,SET_SPRITE_ATTR=11,SET_TILEMAP=12,SCROLL_BG=13,WRITE_SPRITE_DATA=14,
          WRITE_TILE_DATA=15,DRAW_BG=16,DRAW_SPRITES=17,WAIT_VBLANK=18,HALT=19)
def A(op, rd, rn, imm=None, rm=None):
    w = OP[op]<<27 | (rd&31)<<21 | ((rd>>5)&1)<<14 | (rn&63)<<15
    if imm is not None: w |= 1<<26 | imm
    else: w |= rm
    return w
def PASS(rd, imm): return A("PASS", rd, 0, imm=imm)
def G(op, ra, rb): return OP[op]<<27 | (ra&63)<<21 | (rb&63)<<15
def N(op): return OP[op]<<27

def prog(order):
    p=[]
    for idx,col in ((1,0b000_111_000),(2,0b111_000_000),(3,0b000_000_111)):
        p += [PASS(10,idx), PASS(11,col), G("SET_PALETTE",10,11)]
    for a in range(64):   p += [PASS(10,a), PASS(11,1), G("WRITE_TILE_DATA",10,11)]
    for a in range(256):  p += [PASS(10,a), PASS(11,3), G("WRITE_SPRITE_DATA",10,11)]
    # sprite 0 em (120,120), prioridade 1, habilitado
    p += [PASS(10,0), PASS(11,120), A("LSL",12,11,imm=9), A("ADD",11,12,imm=120), G("SET_SPRITE_POS",10,11)]
    p += [PASS(11,33), A("LSL",11,11,imm=9), G("SET_SPRITE_ATTR",10,11)]
    # retangulo (100,100)-(139,139), cor = paleta 0 indice 2   (V0X=37 V0Y=38 V1X=39 V1Y=40 COLOR=43)
    p += [PASS(37,100), PASS(38,100), PASS(39,139), PASS(40,139), PASS(43,2)]
    for o in order: p.append(N(o))
    p.append(N("HALT"))
    return p
for name, order in (("inv", ["DRAW_SPRITES","DRAW_RECT","DRAW_BG"]),
                    ("ok",  ["DRAW_BG","DRAW_RECT","DRAW_SPRITES"]),
                    ("fundo_depois", ["DRAW_RECT","DRAW_SPRITES","DRAW_BG","DRAW_RECT"])):
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), f"prog_{name}.hex"),"w") as f:
        for w in prog(order): f.write(f"{w:08x}\n")
    print(name, len(prog(order)), "instrucoes")
