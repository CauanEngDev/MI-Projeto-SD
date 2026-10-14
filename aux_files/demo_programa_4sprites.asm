; ============================================================================
; Demo: fundo, dois sprites, um quadrado e um triangulo.
;
;   sprite 0 (Sonic)  : padrao 0, paleta do banco 0. Anda pela tela e, a cada
;                       vez que bate em uma borda, e espelhado:
;                         borda esquerda/direita  -> inverte flip_h
;                         borda superior/inferior -> inverte flip_v
;   sprite 1 (Shadow) : padrao 1, paleta do BANCO 1. Aparece espelhado na tela,
;                       em (304 - x, 224 - y), com os mesmos flips do sprite 0.
;   sprite 2 (Sonic) e sprite 3 (Shadow): PARADOS no meio da tela, lado a lado,
;                       um de cada padrao (padrao 0 com banco 0, padrao 1 com banco 1).
;   quadrado e triangulo: ficam sobre o fundo e sob os sprites.
;
; Memorias carregadas pelos .mif (o programa nao as inicializa):
;   palette_ram          floresta_palette_shadow.mif     (banco 0: fundo + Sonic; banco 1: Shadow)
;   bg_tile_ram          floresta_tilemap.mif
;   bg_tile_pattern_ram  floresta_patterns.mif
;   sprite_pattern_ram   sprite_pattern_sonic_shadow.mif (padrao 0 = Sonic, padrao 1 = Shadow)
;
; Estado que persiste de um quadro para o outro (os registradores nao zeram
; quando o programa reinicia no vblank):
;     R1 = x        R2 = dx (passo em x, com sinal; 0 = ainda nao inicializado)
;     R3 = y        R4 = dy (passo em y, com sinal)
;     R5 = flip_h   R6 = flip_v        (0 ou 1)
; Temporarios: R7 a R13.
;
; Sprite 16x16, tela 320x240: x vai de 0 a 304 e y de 0 a 224.
; Ajuste os valores marcados com "<-".
; ============================================================================

; ---- primeiro quadro: posicao e velocidades iniciais (dx = 0 so apos o reset)
SUB   XZR, R2, #0
B.NE  inicializado
PASS  R1, #100            ; <- x inicial
PASS  R3, #80             ; <- y inicial
PASS  R2, #3              ; <- velocidade em x (pixels por quadro)
PASS  R4, #2              ; <- velocidade em y
inicializado:

; ---- anda
ADD   R1, R1, R2
ADD   R3, R3, R4

; ---- borda direita (x > 304): trava em 304, inverte dx e flip_h
SUB   XZR, R1, #304
B.LE  ok_dir
PASS  R1, #304
SUB   R2, XZR, R2         ; dx = -dx
PASS  R7, #1
SUB   R5, R7, R5          ; flip_h = 1 - flip_h
ok_dir:

; ---- borda esquerda (x < 0, comparacao com sinal)
SUB   XZR, R1, #0
B.GE  ok_esq
PASS  R1, #0
SUB   R2, XZR, R2
PASS  R7, #1
SUB   R5, R7, R5
ok_esq:

; ---- borda inferior (y > 224): trava em 224, inverte dy e flip_v
SUB   XZR, R3, #224
B.LE  ok_baixo
PASS  R3, #224
SUB   R4, XZR, R4         ; dy = -dy
PASS  R7, #1
SUB   R6, R7, R6          ; flip_v = 1 - flip_v
ok_baixo:

; ---- borda superior (y < 0)
SUB   XZR, R3, #0
B.GE  ok_cima
PASS  R3, #0
SUB   R4, XZR, R4
PASS  R7, #1
SUB   R6, R7, R6
ok_cima:

; ---- posicao do sprite: {y[7:0], x[8:0]} = y * 512 + x
PASS  R8, #0              ; <- id do sprite (0 a 31)
LSL   R9, R3, #9
ADD   R9, R9, R1
SET_SPRITE_POS R8, R9

; ---- atributos: {enable, prioridade[4:0], flip_v, flip_h, paleta, padrao[5:0]}
PASS  R10, #33            ; <- 32 + prioridade (enable = bit 14; aqui prioridade 1)
LSL   R10, R10, #9
LSL   R11, R6, #8         ; flip_v no bit 8
ADD   R10, R10, R11
LSL   R11, R5, #7         ; flip_h no bit 7
ADD   R10, R10, R11
ADD   R10, R10, #0        ; <- (paleta << 6) | padrao   ex.: #64 = paleta 1, padrao 0
SET_SPRITE_ATTR R8, R10

; ---- segundo sprite (id 1): padrao 1 (Shadow) com a paleta do BANCO 1.
; Aparece espelhado na tela: posicao (304 - x, 224 - y).
PASS  R12, #304
SUB   R12, R12, R1        ; x2 = 304 - x
PASS  R13, #224
SUB   R13, R13, R3        ; y2 = 224 - y
LSL   R9, R13, #9
ADD   R9, R9, R12         ; {y2, x2}
PASS  R8, #1              ; <- id do segundo sprite
SET_SPRITE_POS R8, R9
ADD   R10, R10, #65       ; mesmos atributos do sprite 0 + banco 1 da paleta (bit 6 = 64) + padrao 1 (Shadow)
SET_SPRITE_ATTR R8, R10

; ---- sprites parados no meio da tela, um de cada padrao (ids 2 e 3)
; Os dois lado a lado ocupam x = 144..175 e y = 112..127, centrados em (160, 120).
PASS  R10, #33            ; <- enable + prioridade 1 (mesmo valor dos outros sprites)
LSL   R10, R10, #9        ; atributos sem flips: {enable, prioridade, 0, 0, paleta, padrao}

; sprite 2: padrao 0 (Sonic), paleta do banco 0
PASS  R8, #2              ; <- id
PASS  R9, #112            ; <- y
LSL   R9, R9, #9
ADD   R9, R9, #144        ; <- x      {y, x} = y * 512 + x
SET_SPRITE_POS R8, R9
ADD   R11, R10, #0        ; <- (paleta << 6) | padrao = banco 0, padrao 0
SET_SPRITE_ATTR R8, R11

; sprite 3: padrao 1 (Shadow), paleta do banco 1
PASS  R8, #3              ; <- id
PASS  R9, #112            ; <- y
LSL   R9, R9, #9
ADD   R9, R9, #160        ; <- x
SET_SPRITE_POS R8, R9
ADD   R11, R10, #65       ; <- (paleta << 6) | padrao = 64 + 1 = banco 1, padrao 1
SET_SPRITE_ATTR R8, R11

; ---- desenha. A ordem entre camadas nao importa: fundo < quadrado/triangulo < sprite
DRAW_BG                   ; fundo (mif)

; quadrado: cantos opostos V0 e V1 (aqui 50 x 50, canto inferior esquerdo)
PASS  V0X, #20            ; <- x do canto superior esquerdo
PASS  V0Y, #150           ; <- y do canto superior esquerdo
PASS  V1X, #69            ; <- x do canto inferior direito
PASS  V1Y, #199           ; <- y do canto inferior direito
PASS  COLOR, #1           ; <- cor = indice na paleta (bit 8 escolhe o banco 0 ou 1)
DRAW_RECT

; triangulo: tres vertices V0, V1 e V2 (aqui no canto superior direito)
PASS  V0X, #250           ; <- vertice 0
PASS  V0Y, #30
PASS  V1X, #210           ; <- vertice 1
PASS  V1Y, #100
PASS  V2X, #290           ; <- vertice 2
PASS  V2Y, #100
PASS  COLOR, #4           ; <- cor do triangulo
DRAW_TRI

DRAW_SPRITES              ; sprite (mif), por cima de tudo
HALT
