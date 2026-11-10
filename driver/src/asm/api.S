#include "hps_0.h"

@ ============================================================================
@ api.S - Mapeia a ponte lightweight HPS->FPGA (h2f_lw) em memoria virtual
@
@ ARM 32 bits (Cortex-A9), Linux EABI. Syscalls via SVC #0: numero em R7,
@ argumentos em R0..R5, retorno em R0 (erro = -errno, entre -4095 e -1).
@ O arquivo precisa ter extensao .S (maiuscula) por causa do #include.
@ ============================================================================

.syntax unified
.arm

@ Numeros das chamadas de sistema (Linux ARM EABI)
.equ SYS_WRITE,    4
.equ SYS_OPEN,     5
.equ SYS_CLOSE,    6
.equ SYS_MUNMAP,   91
.equ SYS_MMAP2,    192              @ mmap2: offset dado em PAGINAS de 4 KB

.equ OPEN_FLAGS,   0x101002         @ O_RDWR | O_SYNC (sem cache ao acessar a FPGA)
.equ PROT_RW,      3                @ PROT_READ | PROT_WRITE
.equ MAP_SHARED,   1
.equ STDERR,       2

@ Ponte lightweight (deve coincidir com HPS_LW_BASE / HPS_LW_SPAN do hps_bridges.h)
.equ LW_BRIDGE_SPAN,   0x00200000   @ 2 MB
.equ LW_BRIDGE_PGOFF,  0xFF200      @ 0xFF200000 >> 12 (offset em paginas)

@ Registradores do avalon_cmd_slave (offsets em bytes a partir da base da ponte LW;
@ o slave esta no offset 0x0 -> AVALON_CMD_SLAVE_0_BASE do hps_0.h)
.equ REG_CMD,          0x00         @ W: empurra uma palavra da ISA na fila
.equ REG_STATUS,       0x04         @ R
.equ REG_CTRL,         0x08         @ W
.equ REG_ID,           0x0C         @ R
.equ COPROC_ID,        0xC0DE0001

@ Bits do STATUS
.equ ST_FULL,          (1 << 0)     @ fila cheia
.equ ST_EMPTY,         (1 << 1)     @ fila vazia
.equ ST_RUNNING,       (1 << 2)     @ busca fora de HALT
.equ ST_WAITING,       (1 << 3)     @ motor ocupado executando uma instrucao
.equ ST_VBLANK,        (1 << 4)
.equ ST_ERROR,         (1 << 5)     @ trava: opcode invalido / comando rejeitado
.equ ST_OVERFLOW,      (1 << 6)     @ trava: escrita descartada em CMD
.equ ST_INIT_BUSY,     (1 << 7)     @ mapas de camadas sendo zerados
.equ ST_PLL_LOCKED,    (1 << 8)
.equ FRAME_SHIFT,      16           @ FRAME_COUNT = STATUS[31:16]

@ Bits do CTRL
.equ CTRL_SOFT_RESET,  (1 << 0)
.equ CTRL_CLEAR_FLAGS, (1 << 1)

@ Limite de tentativas de leitura do STATUS antes de desistir (evita travar o
@ ARM se o video nao andar: sem vblank a busca para e a fila nunca esvazia).
@ Cada leitura pela ponte LW leva da ordem de 1 us, entao ~1-2 s no total.
.equ POLL_TIMEOUT,     0x00200000

@ ----------------------------------------------------------------------------
@ Camada 2: opcodes da ISA (isa.vh) e registradores do banco
@ ----------------------------------------------------------------------------
.equ OP_NOP,               0
.equ OP_ADD,               1
.equ OP_SUB,               2
.equ OP_AND,               3
.equ OP_LSL,               4
.equ OP_LSR,               5
.equ OP_PASS,              6
.equ OP_SET_PALETTE,       7
.equ OP_DRAW_RECT,         8
.equ OP_DRAW_TRI,          9
.equ OP_SET_SPRITE_POS,    10
.equ OP_SET_SPRITE_ATTR,   11
.equ OP_SET_TILEMAP,       12
.equ OP_SCROLL_BG,         13
.equ OP_WRITE_SPRITE_DATA, 14
.equ OP_WRITE_TILE_DATA,   15
.equ OP_DRAW_BG,           16
.equ OP_DRAW_SPRITES,      17
.equ OP_WAIT_VBLANK,       18
.equ OP_HALT,              19

@ Registradores usados como rascunho para os operandos Ra e Rb das instrucoes
@ do formato G (SET_*, WRITE_*, SCROLL_BG). Qualquer registrador geral serviria.
.equ R_A,                  0
.equ R_B,                  1
.equ R_XZR,                31           @ le 0; escrita descartada

@ Registradores dedicados ao rasterizador (banco_registradores.v)
.equ R_V0X,                37           @ 9 bits
.equ R_V0Y,                38           @ 8 bits
.equ R_V1X,                39
.equ R_V1Y,                40
.equ R_V2X,                41
.equ R_V2Y,                42
.equ R_COLOR,              43           @ {palette_sel, indice} (9 bits)

@ ========================================================================
@ Bss = Block Started by Symbol
@ Reserva espaco para variaveis globais; o sistema entrega tudo zerado.
@ ========================================================================

.section .bss
.align 2
    hps_fd:         .space 4        @ descritor de /dev/mem (so existe durante hps_open)

@ ========================================================================
@ Dados com valor pre-definido
@ ========================================================================

.section .data
    err_open_file:  .asciz "ERRO: Não foi possível abrir o arquivo.\n"
    len_err_open_file = . - err_open_file - 1   @ -1: sem o terminador nulo

    devmem:         .asciz "/dev/mem"

@ ========================================================================
@ Instrucoes executaveis
@ ========================================================================

.section .text
    .global hps_open        @ void* hps_open(void)
    .global hps_close       @ int hps_close(void* lw_virtual)
    .global cop_init        @ int      cop_init(void* base)
    .global cop_push        @ int      cop_push(void* base, uint32_t palavra)
    .global cop_status      @ uint32_t cop_status(void* base)
    .global cop_has_error   @ uint32_t cop_has_error(void* base)
    .global cop_clear_flags @ void     cop_clear_flags(void* base)
    .global cop_wait_idle   @ int      cop_wait_idle(void* base)
    .global cop_frame_count @ uint32_t cop_frame_count(void* base)
    .global cop_wait_frame  @ uint32_t cop_wait_frame(void* base, uint32_t anterior)
    .global cop_draw_bg      @ int cop_draw_bg(void* base)
    .global cop_draw_sprites @ int cop_draw_sprites(void* base)
    .global cop_halt         @ int cop_halt(void* base)
    .global cop_present      @ uint32_t cop_present(void* base, uint32_t frame_anterior)
    .global cop_scroll_bg    @ int cop_scroll_bg(void* base, uint32_t x, uint32_t y)
    .global cop_set_sprite_pos  @ int cop_set_sprite_pos(void* base, id, x, y)
    .global cop_set_sprite_attr @ int cop_set_sprite_attr(void* base, id, attr)
    .global cop_draw_rect    @ int cop_draw_rect(void* base, x0, y0, x1, y1, cor)
    .global cop_draw_tri     @ int cop_draw_tri(void* base, x0, y0, x1, y1, x2, y2, cor)
    .global cop_clear_screen @ int cop_clear_screen(void* base, uint32_t cor)
    .global cop_set_palette  @ int cop_set_palette(void* base, sel, indice, rgb)
    .global cop_load_palette @ int cop_load_palette(void* base, sel, const uint16_t* rgb, n)
    .global cop_set_tilemap  @ int cop_set_tilemap(void* base, posicao, pattern_id)
    .global cop_write_tile_data   @ int cop_write_tile_data(void* base, tile_id, const uint8_t* px64)
    .global cop_write_sprite_data @ int cop_write_sprite_data(void* base, pattern_id, const uint8_t* px256)


@ ============================================================================
@ void* hps_open(void)
@ Abre /dev/mem, mapeia a ponte LW (0xFF200000, 2 MB) e devolve o endereco
@ virtual. Retorna NULL se falhar. O fd e fechado aqui mesmo: o mapeamento
@ continua valido depois do close, entao hps_close so precisa do munmap.
@ ============================================================================

.type hps_open, %function
hps_open:
    PUSH    {R4, R5, R7, LR}

    @ fd = open("/dev/mem", O_RDWR | O_SYNC)
    LDR     R0, =devmem
    LDR     R1, =OPEN_FLAGS
    MOV     R2, #0                  @ mode (ignorado, sem O_CREAT)
    MOV     R7, #SYS_OPEN
    SVC     #0
    CMN     R0, #4096               @ carry se R0 >= 0xFFFFF000, ou seja, -errno
    BHS     .Lho_err_open

    MOV     R4, R0                  @ R4 = fd
    LDR     R1, =hps_fd
    STR     R4, [R1]

    @ virt = mmap2(NULL, SPAN, PROT_READ|PROT_WRITE, MAP_SHARED, fd, base >> 12)
    MOV     R0, #0                  @ addr: o kernel escolhe
    LDR     R1, =LW_BRIDGE_SPAN
    MOV     R2, #PROT_RW
    MOV     R3, #MAP_SHARED
    @ R4 = fd (quinto argumento, ja carregado)
    LDR     R5, =LW_BRIDGE_PGOFF    @ sexto argumento
    MOV     R7, #SYS_MMAP2
    SVC     #0
    MOV     R5, R0                  @ guarda o resultado antes do close

    @ close(fd)
    MOV     R0, R4
    MOV     R7, #SYS_CLOSE
    SVC     #0
    MOV     R0, #0
    LDR     R1, =hps_fd
    STR     R0, [R1]

    @ mmap falhou? (-errno) => retorna NULL
    CMN     R5, #4096
    MOVHS   R5, #0
    MOV     R0, R5
    POP     {R4, R5, R7, PC}

.Lho_err_open:
    MOV     R0, #STDERR
    LDR     R1, =err_open_file
    LDR     R2, =len_err_open_file
    MOV     R7, #SYS_WRITE
    SVC     #0
    MOV     R0, #0                  @ retorna NULL
    POP     {R4, R5, R7, PC}
.size hps_open, . - hps_open
.ltorg


@ ============================================================================
@ int hps_close(void* lw_virtual)
@ Desfaz o mapeamento. Retorna 0 em sucesso, -1 em falha (ou se for NULL).
@ ============================================================================

.type hps_close, %function
hps_close:
    PUSH    {R7, LR}

    CMP     R0, #0
    BEQ     .Lhc_null

    @ munmap(lw_virtual, SPAN)
    LDR     R1, =LW_BRIDGE_SPAN
    MOV     R7, #SYS_MUNMAP
    SVC     #0
    CMN     R0, #4096
    MVNHS   R0, #0                  @ erro => -1 (se deu certo, R0 ja e 0)
    POP     {R7, PC}

.Lhc_null:
    MVN     R0, #0                  @ NULL => -1
    POP     {R7, PC}
.size hps_close, . - hps_close
.ltorg

@ ############################################################################
@ NUCLEO DA API DO COPROCESSADOR
@ Todas recebem em R0 o ponteiro devolvido por hps_open. Sao funcoes folha
@ (nao chamam outras), entao usam so R0-R3 (livres pela ABI) e retornam com
@ BX LR, sem PUSH/POP. Acessos sempre de 32 bits e alinhados. A memoria
@ mapeada via /dev/mem com O_SYNC e nao cacheavel, entao as leituras e
@ escritas chegam ao hardware na ordem em que aparecem aqui.
@ ############################################################################


@ ============================================================================
@ int cop_init(void* base)
@ Confere o ID, faz soft reset e espera o coprocessador ficar pronto
@ (INIT_BUSY = 0 e PLL_LOCKED = 1).
@ Retorno: 0 ok | -1 ID diferente de 0xC0DE0001 (ponte LW ou bitstream errado)
@          | -2 tempo esgotado (PLL do VGA nao travou ou mapas nao zeraram)
@ O soft reset zera FRAME_COUNT, OVERFLOW e ERROR (o topo usa reset_core =
@ reset | sw_reset) e tambem reinicia banco de registradores, motores e fila.
@ ============================================================================

.type cop_init, %function
cop_init:
    LDR     R1, [R0, #REG_ID]
    LDR     R2, =COPROC_ID
    CMP     R1, R2
    BNE     .Lci_bad_id             @ ID nao confere: nao mexe no hardware

    MOV     R1, #CTRL_SOFT_RESET
    STR     R1, [R0, #REG_CTRL]     @ reseta fila e busca por RESET_CICLOS ciclos

    LDR     R3, =POLL_TIMEOUT
.Lci_wait:
    LDR     R2, [R0, #REG_STATUS]
    AND     R2, R2, #(ST_INIT_BUSY | ST_PLL_LOCKED)
    CMP     R2, #ST_PLL_LOCKED      @ pronto = PLL travado e mapas ja zerados
    BEQ     .Lci_ok
    SUBS    R3, R3, #1
    BNE     .Lci_wait
    MVN     R0, #1                  @ MVN de 1 = 0xFFFFFFFE = -2
    BX      LR

.Lci_ok:
    MOV     R0, #0
    BX      LR

.Lci_bad_id:
    MVN     R0, #0                  @ -1
    BX      LR
.size cop_init, . - cop_init


@ ============================================================================
@ int cop_push(void* base, uint32_t palavra)
@ Empurra uma palavra da ISA na fila. Espera FULL = 0 antes de escrever, como
@ exige o slave (ele nao usa waitrequest: com a fila cheia a palavra seria
@ descartada e OVERFLOW seria setado).
@ Retorno: 0 ok | -1 tempo esgotado (fila continua cheia)
@ ============================================================================

.type cop_push, %function
cop_push:
    LDR     R3, =POLL_TIMEOUT
.Lcp_wait:
    LDR     R2, [R0, #REG_STATUS]
    TST     R2, #ST_FULL
    BEQ     .Lcp_write              @ FULL = 0: tem espaco
    SUBS    R3, R3, #1
    BNE     .Lcp_wait
    MVN     R0, #0                  @ -1: a fila nao esvaziou
    BX      LR

.Lcp_write:
    STR     R1, [R0, #REG_CMD]      @ R1 = palavra de 32 bits da ISA
    MOV     R0, #0
    BX      LR
.size cop_push, . - cop_push


@ ============================================================================
@ uint32_t cop_status(void* base)
@ Devolve o STATUS inteiro (bits em ST_*, FRAME_COUNT em [31:16]).
@ ============================================================================

.type cop_status, %function
cop_status:
    LDR     R0, [R0, #REG_STATUS]
    BX      LR
.size cop_status, . - cop_status


@ ============================================================================
@ uint32_t cop_has_error(void* base)
@ Diferente de 0 se ERROR ou OVERFLOW estiverem travados. Chame uma vez por
@ quadro: ERROR indica opcode invalido / comando rejeitado (sai com cop_init,
@ que faz soft reset); OVERFLOW indica palavra descartada (cop_clear_flags
@ ou cop_init limpam).
@ ============================================================================

.type cop_has_error, %function
cop_has_error:
    LDR     R0, [R0, #REG_STATUS]
    AND     R0, R0, #(ST_ERROR | ST_OVERFLOW)
    BX      LR
.size cop_has_error, . - cop_has_error


@ ============================================================================
@ void cop_clear_flags(void* base)
@ Zera a trava OVERFLOW (CTRL.CLEAR_FLAGS). ERROR nao e afetado (so o soft
@ reset, feito por cop_init, o limpa).
@ ============================================================================

.type cop_clear_flags, %function
cop_clear_flags:
    MOV     R1, #CTRL_CLEAR_FLAGS
    STR     R1, [R0, #REG_CTRL]
    BX      LR
.size cop_clear_flags, . - cop_clear_flags


@ ============================================================================
@ int cop_wait_idle(void* base)
@ Espera a fila esvaziar (EMPTY = 1) e o motor terminar (WAITING = 0).
@ Se o ultimo comando enviado foi HALT, isso so acontece depois que o HALT e
@ descartado no proximo vblank.
@ Retorno: 0 ok | -1 tempo esgotado
@ ============================================================================

.type cop_wait_idle, %function
cop_wait_idle:
    LDR     R3, =POLL_TIMEOUT
.Lcw_idle_loop:
    LDR     R2, [R0, #REG_STATUS]
    AND     R2, R2, #(ST_EMPTY | ST_WAITING)
    CMP     R2, #ST_EMPTY           @ EMPTY = 1 e WAITING = 0
    BEQ     .Lcw_idle_ok
    SUBS    R3, R3, #1
    BNE     .Lcw_idle_loop
    MVN     R0, #0                  @ -1
    BX      LR

.Lcw_idle_ok:
    MOV     R0, #0
    BX      LR
.size cop_wait_idle, . - cop_wait_idle


@ ============================================================================
@ uint32_t cop_frame_count(void* base)
@ Contador de frame_swap (0..65535, da a volta). Zera com o soft reset.
@ ============================================================================

.type cop_frame_count, %function
cop_frame_count:
    LDR     R0, [R0, #REG_STATUS]
    LSR     R0, R0, #FRAME_SHIFT
    BX      LR
.size cop_frame_count, . - cop_frame_count


@ ============================================================================
@ uint32_t cop_wait_frame(void* base, uint32_t anterior)
@ Bloqueia ate o FRAME_COUNT ser diferente de "anterior", ou seja, ate a
@ proxima troca de buffer. Uso no laco do jogo:
@     f = cop_frame_count(base);
@     ... monta o quadro e envia ate o HALT ...
@     f = cop_wait_frame(base, f);      @ sincroniza em 60 FPS
@ Retorno: novo FRAME_COUNT (0..65535) | 0xFFFFFFFF (-1) se o tempo esgotou
@ (nao colide com um contador de 16 bits).
@ ============================================================================

.type cop_wait_frame, %function
cop_wait_frame:
    LDR     R3, =POLL_TIMEOUT
.Lcw_frame_loop:
    LDR     R2, [R0, #REG_STATUS]
    LSR     R2, R2, #FRAME_SHIFT    @ R2 = FRAME_COUNT atual
    CMP     R2, R1
    BNE     .Lcw_frame_done         @ mudou: houve frame_swap
    SUBS    R3, R3, #1
    BNE     .Lcw_frame_loop
    MVN     R0, #0                  @ -1
    BX      LR

.Lcw_frame_done:
    MOV     R0, R2
    BX      LR
.size cop_wait_frame, . - cop_wait_frame
.ltorg


@ ############################################################################
@ CAMADA 2 - CONSTRUTORES DE INSTRUCAO DA ISA
@
@ Cada funcao monta as palavras de 32 bits da ISA e as envia com cop_push.
@ O hardware (unidade_de_controle.v) nao recebe operandos dentro da instrucao:
@   - formato A (ULA): Rd = Rn op (Rm | imm12), imm12 sem sinal (0..4095);
@   - formato G (SET_*, WRITE_*, SCROLL_BG): operandos nos registradores Ra e Rb;
@   - DRAW_RECT / DRAW_TRI: parametros nos registradores 37-43 (V0X..COLOR);
@   - DRAW_BG, DRAW_SPRITES, WAIT_VBLANK, HALT: sem operandos.
@ Por isso cada chamada carrega os registradores com PASS/LSL/ADD antes da
@ instrucao. A ULA e combinacional e escreve no mesmo ciclo em que a instrucao
@ sai da fila, entao a instrucao seguinte ja enxerga o valor (sem hazard).
@
@ Retorno de todas (exceto cop_present): 0 ok | -1 fila cheia (tempo esgotado)
@ | -3 argumento fora da faixa. Argumentos sao validados ANTES de enviar
@ qualquer palavra: o rasterizador rejeita x >= 320 ou y >= 240 e isso trava
@ ERROR no STATUS.
@
@ Convencao dos auxiliares internos (nao sao globais):
@   R4 = base da ponte, preservado pelo chamador.
@   Destroem R0-R3 e R12; preservam R5-R11.
@ ############################################################################


@ ----------------------------------------------------------------------------
@ Macros: carregar um registrador do coprocessador e checar erro
@ ----------------------------------------------------------------------------

@ CHK falha: se R0 != 0 (erro de cop_push), salta para "falha"
.macro CHK fail
    CMP     R0, #0
    BNE     \fail
.endm

@ LOADREG reg, src, falha: registrador do coprocessador "reg" recebe o valor do
@ registrador ARM "src" (qualquer valor de 32 bits)
.macro LOADREG reg, src, fail
    MOV     R0, #\reg
    MOV     R1, \src
    BL      load_imm
    CMP     R0, #0
    BNE     \fail
.endm

@ LOADCONST reg, const, falha: o mesmo, mas com uma constante
.macro LOADCONST reg, const, fail
    MOV     R0, #\reg
    LDR     R1, =\const
    BL      load_imm
    CMP     R0, #0
    BNE     \fail
.endm


@ ----------------------------------------------------------------------------
@ emit_alu_imm: envia uma instrucao da ULA com imediato (formato A, I = 1)
@   R4 = base | R0 = opcode | R1 = rd (0..43) | R2 = rn | R3 = imm12
@ Palavra: opcode<<27 | 1<<26 | rd[4:0]<<21 | rn<<15 | rd[5]<<14 | imm12
@ Retorno: o de cop_push (0 ou -1)
@ ----------------------------------------------------------------------------
emit_alu_imm:
    LSL     R0, R0, #27             @ opcode
    ORR     R0, R0, #(1 << 26)      @ I = 1: segundo operando e imediato
    AND     R12, R1, #31
    ORR     R0, R0, R12, LSL #21    @ Rd[4:0]
    LSR     R12, R1, #5
    ORR     R0, R0, R12, LSL #14    @ Rd[5] (permite os registradores 37-43)
    ORR     R0, R0, R2, LSL #15     @ Rn
    ORR     R0, R0, R3              @ imm12
    MOV     R1, R0
    MOV     R0, R4
    B       cop_push                @ cop_push retorna direto ao chamador


@ ----------------------------------------------------------------------------
@ emit_g: envia uma instrucao do formato G
@   R4 = base | R0 = opcode | R1 = ra | R2 = rb
@ Palavra: opcode<<27 | ra<<21 | rb<<15
@ ----------------------------------------------------------------------------
emit_g:
    LSL     R0, R0, #27
    ORR     R0, R0, R1, LSL #21     @ Ra
    ORR     R0, R0, R2, LSL #15     @ Rb
    MOV     R1, R0
    MOV     R0, R4
    B       cop_push


@ ----------------------------------------------------------------------------
@ emit_n: envia uma instrucao sem operandos
@   R4 = base | R0 = opcode
@ ----------------------------------------------------------------------------
emit_n:
    LSL     R1, R0, #27
    MOV     R0, R4
    B       cop_push


@ ----------------------------------------------------------------------------
@ load_imm: carrega um valor de 32 bits em um registrador do coprocessador
@   R4 = base | R0 = registrador de destino | R1 = valor
@ O imm12 so vai ate 4095, entao a sequencia depende do tamanho do valor:
@   ate 12 bits : PASS rd,#v                                  (1 palavra)
@   ate 24 bits : PASS rd,#hi ; LSL rd,rd,#12 ; ADD rd,rd,#lo (2 a 3 palavras)
@   ate 32 bits : PASS ; LSL 12 ; ADD ; LSL 8 ; ADD           (5 palavras)
@ Retorno: 0 ok | -1 fila cheia
@ ----------------------------------------------------------------------------
load_imm:
    PUSH    {R5, R6, R7, LR}
    MOV     R5, R0                  @ R5 = registrador destino
    MOV     R6, R1                  @ R6 = valor

    LSRS    R0, R6, #12             @ Z = 1 se o valor cabe em 12 bits
    BNE     .Lli_wide

    @ --- 1 palavra: PASS rd, #valor ---------------------------------------
    MOV     R0, #OP_PASS
    MOV     R1, R5
    MOV     R2, #R_XZR              @ PASS ignora Rn
    MOV     R3, R6
    BL      emit_alu_imm
    B       .Lli_end

.Lli_wide:
    LSRS    R0, R6, #24             @ Z = 1 se o valor cabe em 24 bits
    BNE     .Lli_full

    @ --- ate 24 bits: PASS rd,#(v>>12) ; LSL rd,rd,#12 ; ADD rd,rd,#(v&0xFFF)
    MOV     R0, #OP_PASS
    MOV     R1, R5
    MOV     R2, #R_XZR
    LSR     R3, R6, #12
    BL      emit_alu_imm
    CHK     .Lli_end
    MOV     R0, #OP_LSL
    MOV     R1, R5
    MOV     R2, R5
    MOV     R3, #12
    BL      emit_alu_imm
    CHK     .Lli_end
    LSL     R3, R6, #20
    LSRS    R3, R3, #20             @ R3 = v & 0xFFF ; Z = 1 se for zero
    BEQ     .Lli_end                @ parte baixa zero: R0 ja e 0, nada a somar
    MOV     R0, #OP_ADD
    MOV     R1, R5
    MOV     R2, R5
    BL      emit_alu_imm
    B       .Lli_end

.Lli_full:
    @ --- 32 bits: v = hi12 | mid12 | lo8 ----------------------------------
    MOV     R0, #OP_PASS
    MOV     R1, R5
    MOV     R2, #R_XZR
    LSR     R3, R6, #20             @ bits 31:20
    BL      emit_alu_imm
    CHK     .Lli_end
    MOV     R0, #OP_LSL
    MOV     R1, R5
    MOV     R2, R5
    MOV     R3, #12
    BL      emit_alu_imm
    CHK     .Lli_end
    LSR     R3, R6, #8
    LSL     R3, R3, #20
    LSR     R3, R3, #20             @ bits 19:8
    MOV     R0, #OP_ADD
    MOV     R1, R5
    MOV     R2, R5
    BL      emit_alu_imm
    CHK     .Lli_end
    MOV     R0, #OP_LSL
    MOV     R1, R5
    MOV     R2, R5
    MOV     R3, #8
    BL      emit_alu_imm
    CHK     .Lli_end
    AND     R3, R6, #0xFF           @ bits 7:0
    MOV     R0, #OP_ADD
    MOV     R1, R5
    MOV     R2, R5
    BL      emit_alu_imm

.Lli_end:
    POP     {R5, R6, R7, PC}


@ ----------------------------------------------------------------------------
@ write_pixels: grava "count" pixels (1 byte cada) numa RAM de padroes
@   R4 = base | R0 = opcode (WRITE_TILE_DATA ou WRITE_SPRITE_DATA)
@   R1 = endereco inicial | R2 = ponteiro dos pixels | R3 = quantidade
@ Ra guarda o endereco (incrementado com ADD #1), Rb guarda o indice de cor
@ (so e recarregado quando a cor muda). Ate 3 palavras por pixel.
@ Retorno: 0 ok | -1 fila cheia
@ ----------------------------------------------------------------------------
write_pixels:
    PUSH    {R5, R6, R7, R8, R9, LR}
    MOV     R5, R0                  @ R5 = opcode
    MOV     R6, R2                  @ R6 = ponteiro
    MOV     R7, R3                  @ R7 = pixels restantes
    MVN     R8, #0                  @ R8 = ultima cor em Rb (nenhuma ainda)

    MOV     R0, #R_A                @ Ra = endereco inicial (R1)
    BL      load_imm
    CHK     .Lwp_end

.Lwp_loop:
    LDRB    R9, [R6], #1            @ proxima cor
    CMP     R9, R8
    BEQ     .Lwp_write              @ mesma cor: Rb ja esta certo
    MOV     R8, R9
    MOV     R0, #OP_PASS            @ Rb = cor
    MOV     R1, #R_B
    MOV     R2, #R_XZR
    MOV     R3, R9
    BL      emit_alu_imm
    CHK     .Lwp_end
.Lwp_write:
    MOV     R0, R5                  @ WRITE_*_DATA Ra, Rb
    MOV     R1, #R_A
    MOV     R2, #R_B
    BL      emit_g
    CHK     .Lwp_end
    SUBS    R7, R7, #1
    BEQ     .Lwp_end                @ acabou (R0 = 0)
    MOV     R0, #OP_ADD             @ Ra = Ra + 1
    MOV     R1, #R_A
    MOV     R2, #R_A
    MOV     R3, #1
    BL      emit_alu_imm
    CHK     .Lwp_end
    B       .Lwp_loop

.Lwp_end:
    POP     {R5, R6, R7, R8, R9, PC}
.ltorg


@ ============================================================================
@ int cop_draw_bg(void* base)       - DRAW_BG: desenha o fundo (tilemap + scroll)
@ int cop_draw_sprites(void* base)  - DRAW_SPRITES: desenha os sprites ativos
@ int cop_halt(void* base)          - HALT: fim do quadro (espera o vblank)
@ Sao uma unica palavra; o cop_push retorna direto ao chamador.
@ ============================================================================

.type cop_draw_bg, %function
cop_draw_bg:
    MOV     R1, #(OP_DRAW_BG << 27)
    B       cop_push
.size cop_draw_bg, . - cop_draw_bg

.type cop_draw_sprites, %function
cop_draw_sprites:
    MOV     R1, #(OP_DRAW_SPRITES << 27)
    B       cop_push
.size cop_draw_sprites, . - cop_draw_sprites

.type cop_halt, %function
cop_halt:
    MOV     R1, #(OP_HALT << 27)
    B       cop_push
.size cop_halt, . - cop_halt


@ ============================================================================
@ uint32_t cop_present(void* base, uint32_t frame_anterior)
@ Fecha o quadro (HALT) e espera a troca de buffer no vblank seguinte, que e a
@ sincronizacao de 60 FPS do laco do jogo:
@     f = cop_frame_count(base);        @ no inicio do quadro
@     ... draw_*, set_* ...
@     f = cop_present(base, f);
@ Retorno: novo FRAME_COUNT | 0xFFFFFFFF (-1) se a fila encheu ou o tempo esgotou
@ ============================================================================

.type cop_present, %function
cop_present:
    PUSH    {R4, R5, R6, LR}
    MOV     R4, R0                  @ base
    MOV     R5, R1                  @ frame anterior
    BL      cop_halt                @ R0 = base
    CMP     R0, #0
    BNE     .Lpr_end                @ R0 = -1
    MOV     R0, R4
    MOV     R1, R5
    BL      cop_wait_frame
.Lpr_end:
    POP     {R4, R5, R6, PC}
.size cop_present, . - cop_present


@ ============================================================================
@ int cop_scroll_bg(void* base, uint32_t x, uint32_t y)
@ SCROLL_BG para os dois eixos (Ra = valor, Rb = eixo: 0 = X, 1 = Y).
@ O hardware so subtrai uma volta (x >= 320, y >= 240), entao x e y devem estar
@ em 0..319 e 0..239; faca o modulo em C. Fora da faixa: -3.
@ ============================================================================

.type cop_scroll_bg, %function
cop_scroll_bg:
    PUSH    {R4, R5, R6, LR}
    MOV     R4, R0
    MOV     R5, R1                  @ x
    MOV     R6, R2                  @ y
    CMP     R5, #320
    BHS     .Lsc_range
    CMP     R6, #240
    BHS     .Lsc_range

    LOADREG R_A, R5, .Lsc_end       @ Ra = x
    MOV     R0, #OP_SCROLL_BG       @ Rb = XZR = 0 -> eixo X
    MOV     R1, #R_A
    MOV     R2, #R_XZR
    BL      emit_g
    CHK     .Lsc_end

    LOADREG R_A, R6, .Lsc_end       @ Ra = y
    LOADCONST R_B, 1, .Lsc_end      @ Rb = 1 -> eixo Y
    MOV     R0, #OP_SCROLL_BG
    MOV     R1, #R_A
    MOV     R2, #R_B
    BL      emit_g
    B       .Lsc_end

.Lsc_range:
    MVN     R0, #2                  @ -3
.Lsc_end:
    POP     {R4, R5, R6, PC}
.size cop_scroll_bg, . - cop_scroll_bg


@ ============================================================================
@ int cop_set_sprite_pos(void* base, uint32_t id, uint32_t x, uint32_t y)
@ SET_SPRITE_POS: Ra = id (0..31), Rb = {y[7:0], x[8:0]}.
@ x em 0..511 e y em 0..255 (o sprite so aparece com x < 320 e y < 240).
@ ============================================================================

.type cop_set_sprite_pos, %function
cop_set_sprite_pos:
    PUSH    {R4, R5, R6, LR}
    MOV     R4, R0
    CMP     R1, #32
    BHS     .Lspp_range
    CMP     R2, #512
    BHS     .Lspp_range
    CMP     R3, #256
    BHS     .Lspp_range
    MOV     R5, R1                  @ id
    LSL     R6, R3, #9
    ORR     R6, R6, R2              @ R6 = {y, x}

    LOADREG R_A, R5, .Lspp_end
    LOADREG R_B, R6, .Lspp_end
    MOV     R0, #OP_SET_SPRITE_POS
    MOV     R1, #R_A
    MOV     R2, #R_B
    BL      emit_g
    B       .Lspp_end

.Lspp_range:
    MVN     R0, #2
.Lspp_end:
    POP     {R4, R5, R6, PC}
.size cop_set_sprite_pos, . - cop_set_sprite_pos


@ ============================================================================
@ int cop_set_sprite_attr(void* base, uint32_t id, uint32_t attr)
@ SET_SPRITE_ATTR: Ra = id (0..31), Rb = atributos de 15 bits:
@   [14] enable | [13:9] prioridade | [8] flip_v | [7] flip_h |
@   [6] palette_sel | [5:0] padrao   (macro COP_SPRITE_ATTR em cop_api.h)
@ ============================================================================

.type cop_set_sprite_attr, %function
cop_set_sprite_attr:
    PUSH    {R4, R5, R6, LR}
    MOV     R4, R0
    CMP     R1, #32
    BHS     .Lspa_range
    CMP     R2, #0x8000
    BHS     .Lspa_range
    MOV     R5, R1
    MOV     R6, R2

    LOADREG R_A, R5, .Lspa_end
    LOADREG R_B, R6, .Lspa_end
    MOV     R0, #OP_SET_SPRITE_ATTR
    MOV     R1, #R_A
    MOV     R2, #R_B
    BL      emit_g
    B       .Lspa_end

.Lspa_range:
    MVN     R0, #2
.Lspa_end:
    POP     {R4, R5, R6, PC}
.size cop_set_sprite_attr, . - cop_set_sprite_attr


@ ============================================================================
@ int cop_draw_rect(void* base, x0, y0, x1, y1, cor)
@   R0 = base, R1 = x0, R2 = y0, R3 = x1, pilha: y1, cor
@ Retangulo preenchido entre os cantos (x0,y0) e (x1,y1), inclusive, em
@ qualquer ordem. cor = {palette_sel, indice} (9 bits, macro COP_COLOR).
@ Escreve V0X, V0Y, V1X, V1Y, COLOR e dispara DRAW_RECT.
@ Faixas: x em 0..319, y em 0..239, cor em 0..511; fora disso: -3.
@ ============================================================================

.type cop_draw_rect, %function
cop_draw_rect:
    PUSH    {R4, R5, R6, R7, R8, R9, LR}    @ 28 bytes: y1 em [SP,#28], cor em [SP,#32]
    MOV     R4, R0
    MOV     R5, R1                  @ x0
    MOV     R6, R2                  @ y0
    MOV     R7, R3                  @ x1
    LDR     R8, [SP, #28]           @ y1
    LDR     R9, [SP, #32]           @ cor
    CMP     R5, #320
    BHS     .Ldr_range
    CMP     R7, #320
    BHS     .Ldr_range
    CMP     R6, #240
    BHS     .Ldr_range
    CMP     R8, #240
    BHS     .Ldr_range
    CMP     R9, #512
    BHS     .Ldr_range

    LOADREG R_V0X,   R5, .Ldr_end
    LOADREG R_V0Y,   R6, .Ldr_end
    LOADREG R_V1X,   R7, .Ldr_end
    LOADREG R_V1Y,   R8, .Ldr_end
    LOADREG R_COLOR, R9, .Ldr_end
    MOV     R0, #OP_DRAW_RECT
    BL      emit_n
    B       .Ldr_end

.Ldr_range:
    MVN     R0, #2
.Ldr_end:
    POP     {R4, R5, R6, R7, R8, R9, PC}
.size cop_draw_rect, . - cop_draw_rect


@ ============================================================================
@ int cop_draw_tri(void* base, x0, y0, x1, y1, x2, y2, cor)
@   R0 = base, R1 = x0, R2 = y0, R3 = x1, pilha: y1, x2, y2, cor
@ Triangulo preenchido pelos vertices (x0,y0), (x1,y1), (x2,y2).
@ Faixas: x em 0..319, y em 0..239, cor em 0..511; fora disso: -3.
@ ============================================================================

.type cop_draw_tri, %function
cop_draw_tri:
    PUSH    {R4, R5, R6, R7, R8, R9, R10, R11, LR}  @ 36 bytes; pilha a partir de [SP,#36]
    MOV     R4, R0
    MOV     R5, R1                  @ x0
    MOV     R6, R2                  @ y0
    MOV     R7, R3                  @ x1
    LDR     R8, [SP, #36]           @ y1
    LDR     R9, [SP, #40]           @ x2
    LDR     R10, [SP, #44]          @ y2
    LDR     R11, [SP, #48]          @ cor
    CMP     R5, #320
    BHS     .Ldt_range
    CMP     R7, #320
    BHS     .Ldt_range
    CMP     R9, #320
    BHS     .Ldt_range
    CMP     R6, #240
    BHS     .Ldt_range
    CMP     R8, #240
    BHS     .Ldt_range
    CMP     R10, #240
    BHS     .Ldt_range
    CMP     R11, #512
    BHS     .Ldt_range

    LOADREG R_V0X,   R5,  .Ldt_end
    LOADREG R_V0Y,   R6,  .Ldt_end
    LOADREG R_V1X,   R7,  .Ldt_end
    LOADREG R_V1Y,   R8,  .Ldt_end
    LOADREG R_V2X,   R9,  .Ldt_end
    LOADREG R_V2Y,   R10, .Ldt_end
    LOADREG R_COLOR, R11, .Ldt_end
    MOV     R0, #OP_DRAW_TRI
    BL      emit_n
    B       .Ldt_end

.Ldt_range:
    MVN     R0, #2
.Ldt_end:
    POP     {R4, R5, R6, R7, R8, R9, R10, R11, PC}
.size cop_draw_tri, . - cop_draw_tri


@ ============================================================================
@ int cop_clear_screen(void* base, uint32_t cor)
@ Preenche (0,0)-(319,239) com uma cor, via DRAW_RECT. Cobre o fundo, mas NAO
@ os sprites ja desenhados no mesmo quadro (sprites tem prioridade maxima).
@ ============================================================================

.type cop_clear_screen, %function
cop_clear_screen:
    PUSH    {R4, R5, R6, LR}
    MOV     R4, R0
    MOV     R5, R1                  @ cor
    CMP     R5, #512
    BHS     .Lcs_range

    LOADCONST R_V0X,   0,   .Lcs_end
    LOADCONST R_V0Y,   0,   .Lcs_end
    LOADCONST R_V1X,   319, .Lcs_end
    LOADCONST R_V1Y,   239, .Lcs_end
    LOADREG   R_COLOR, R5,  .Lcs_end
    MOV     R0, #OP_DRAW_RECT
    BL      emit_n
    B       .Lcs_end

.Lcs_range:
    MVN     R0, #2
.Lcs_end:
    POP     {R4, R5, R6, PC}
.size cop_clear_screen, . - cop_clear_screen


@ ============================================================================
@ int cop_set_palette(void* base, uint32_t sel, uint32_t indice, uint32_t rgb)
@ SET_PALETTE: Ra = {palette_sel, indice}, Rb = cor RGB de 9 bits
@ ({R[2:0], G[2:0], B[2:0]}, macro COP_RGB). sel em 0..1, indice em 0..255,
@ rgb em 0..511.
@ ============================================================================

.type cop_set_palette, %function
cop_set_palette:
    PUSH    {R4, R5, R6, LR}
    MOV     R4, R0
    CMP     R1, #2
    BHS     .Lpal_range
    CMP     R2, #256
    BHS     .Lpal_range
    CMP     R3, #512
    BHS     .Lpal_range
    LSL     R5, R1, #8
    ORR     R5, R5, R2              @ R5 = {sel, indice}
    MOV     R6, R3                  @ R6 = rgb

    LOADREG R_A, R5, .Lpal_end
    LOADREG R_B, R6, .Lpal_end
    MOV     R0, #OP_SET_PALETTE
    MOV     R1, #R_A
    MOV     R2, #R_B
    BL      emit_g
    B       .Lpal_end

.Lpal_range:
    MVN     R0, #2
.Lpal_end:
    POP     {R4, R5, R6, PC}
.size cop_set_palette, . - cop_set_palette


@ ============================================================================
@ int cop_load_palette(void* base, uint32_t sel, const uint16_t* rgb, uint32_t n)
@ Carrega as n primeiras cores (n <= 256) de uma paleta: indice i recebe rgb[i].
@ ============================================================================

.type cop_load_palette, %function
cop_load_palette:
    PUSH    {R4, R5, R6, R7, R8, LR}
    MOV     R4, R0                  @ base
    MOV     R5, R1                  @ sel
    MOV     R6, R2                  @ ponteiro
    MOV     R7, R3                  @ n
    CMP     R5, #2
    BHS     .Llp_range
    CMP     R7, #256
    BHI     .Llp_range
    CMP     R6, #0
    BEQ     .Llp_range
    MOV     R8, #0                  @ indice atual
    MOV     R0, #0                  @ n = 0: nada a fazer
.Llp_loop:
    CMP     R8, R7
    BHS     .Llp_end
    MOV     R0, R4
    MOV     R1, R5
    MOV     R2, R8
    LDRH    R3, [R6], #2
    BL      cop_set_palette
    CMP     R0, #0
    BNE     .Llp_end                @ erro de cop_set_palette (-1 ou -3)
    ADD     R8, R8, #1
    B       .Llp_loop

.Llp_range:
    MVN     R0, #2
.Llp_end:
    POP     {R4, R5, R6, R7, R8, PC}
.size cop_load_palette, . - cop_load_palette


@ ============================================================================
@ int cop_set_tilemap(void* base, uint32_t posicao, uint32_t pattern_id)
@ SET_TILEMAP: Ra = posicao (linha*40 + coluna, 0..1199), Rb = padrao (0..255).
@ ============================================================================

.type cop_set_tilemap, %function
cop_set_tilemap:
    PUSH    {R4, R5, R6, LR}
    MOV     R4, R0
    CMP     R1, #1200
    BHS     .Ltm_range
    CMP     R2, #256
    BHS     .Ltm_range
    MOV     R5, R1
    MOV     R6, R2

    LOADREG R_A, R5, .Ltm_end
    LOADREG R_B, R6, .Ltm_end
    MOV     R0, #OP_SET_TILEMAP
    MOV     R1, #R_A
    MOV     R2, #R_B
    BL      emit_g
    B       .Ltm_end

.Ltm_range:
    MVN     R0, #2
.Ltm_end:
    POP     {R4, R5, R6, PC}
.size cop_set_tilemap, . - cop_set_tilemap


@ ============================================================================
@ int cop_write_tile_data(void* base, uint32_t tile_id, const uint8_t* px64)
@ Grava um tile 8x8 (64 bytes de indices de cor, linha a linha) na Tile Pattern
@ RAM, a partir do endereco tile_id*64. tile_id em 0..255.
@ ============================================================================

.type cop_write_tile_data, %function
cop_write_tile_data:
    PUSH    {R4, LR}
    MOV     R4, R0
    CMP     R1, #256
    BHS     .Lwt_range
    CMP     R2, #0
    BEQ     .Lwt_range
    LSL     R1, R1, #6              @ endereco = tile_id * 64
    MOV     R3, #64
    MOV     R0, #OP_WRITE_TILE_DATA
    BL      write_pixels
    B       .Lwt_end

.Lwt_range:
    MVN     R0, #2
.Lwt_end:
    POP     {R4, PC}
.size cop_write_tile_data, . - cop_write_tile_data


@ ============================================================================
@ int cop_write_sprite_data(void* base, uint32_t pattern_id, const uint8_t* px256)
@ Grava um sprite 16x16 (256 bytes) na Sprite Pattern RAM, a partir do
@ endereco pattern_id*256. pattern_id em 0..63.
@ ATENCAO: o hardware monta o sprite de 4 blocos 8x8 na ordem
@   0 = superior esquerdo, 1 = superior direito, 2 = inferior esquerdo,
@   3 = inferior direito, cada bloco linha a linha. Os 256 bytes devem estar
@ nessa ordem (cop_sprite16_to_ram, em cop_api.h, converte de linha a linha).
@ ============================================================================

.type cop_write_sprite_data, %function
cop_write_sprite_data:
    PUSH    {R4, LR}
    MOV     R4, R0
    CMP     R1, #64
    BHS     .Lws_range
    CMP     R2, #0
    BEQ     .Lws_range
    LSL     R1, R1, #8              @ endereco = pattern_id * 256
    MOV     R3, #256
    MOV     R0, #OP_WRITE_SPRITE_DATA
    BL      write_pixels
    B       .Lws_end

.Lws_range:
    MVN     R0, #2
.Lws_end:
    POP     {R4, PC}
.size cop_write_sprite_data, . - cop_write_sprite_data
.ltorg


.section .note.GNU-stack, "", %progbits