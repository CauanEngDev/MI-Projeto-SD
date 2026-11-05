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

.section .note.GNU-stack, "", %progbits