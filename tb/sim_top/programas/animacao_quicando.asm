; ============================================================
; Animacao: retangulo que quica nas bordas, com trilha de quadrados
; ------------------------------------------------------------
; Estado persistente entre frames (os registradores nao zeram no reinicio):
;   R1 = x do retangulo     R2 = dx (passo, com sinal)
; Usa: desvio condicional (inicializacao unica, limites) e um laco
; com contador (trilha), com DRAW_RECT dentro do laco.
; ============================================================

; paleta 0: 1 = fundo (verde), 2 = retangulo (vermelho), 3 = trilha (azul)
PASS R10, #1
PASS R11, #56
SET_PALETTE R10, R11
PASS R10, #2
PASS R11, #448
SET_PALETTE R10, R11
PASS R10, #3
PASS R11, #7
SET_PALETTE R10, R11

; dx = 100 no primeiro frame (R2 = 0 so logo apos o reset)
SUB   XZR, R2, #0
B.NE  inicializado
PASS  R2, #100
inicializado:

; x = x + dx; quica nos limites [0, 270]
ADD   R1, R1, R2
SUB   XZR, R1, #270
B.LE  ok_dir              ; x <= 270 (com sinal)
PASS  R1, #270
SUB   R2, XZR, R2         ; dx = -dx
ok_dir:
SUB   XZR, R1, #0
B.GE  ok_esq              ; x >= 0 (com sinal; x negativo cai aqui)
PASS  R1, #0
SUB   R2, XZR, R2
ok_esq:

; limpa a tela com a cor 1 (retangulo de tela cheia)
PASS  V0X, #0
PASS  V0Y, #0
PASS  V1X, #319
PASS  V1Y, #239
PASS  COLOR, #1
DRAW_RECT

; retangulo principal 40x40 em (x, 100)
ADD   V0X, R1, #0
ADD   V1X, R1, #39
PASS  V0Y, #100
PASS  V1Y, #139
PASS  COLOR, #2
DRAW_RECT

; trilha: 4 quadrados 10x10 em y = 10..19, x = 10, 40, 70, 100
PASS  V0X, #10
PASS  V1X, #19
PASS  V0Y, #10
PASS  V1Y, #19
PASS  COLOR, #3
PASS  R5, #4
trilha:
DRAW_RECT
ADD   V0X, V0X, #30
ADD   V1X, V1X, #30
SUB   R5, R5, #1
B.NE  trilha
HALT
