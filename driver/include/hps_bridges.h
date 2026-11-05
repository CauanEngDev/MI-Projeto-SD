/* ============================================================================
 * hps_bridges.h - Pontes HPS <-> FPGA do Cyclone V SoC (DE1-SoC) usadas pelo
 * coprocessador grafico.
 *
 * Escrito a mao. NAO substitui o hps_0.h (gerado pelo swinfo2header a partir
 * do soc_system.sopcinfo e sobrescrito a cada regeneracao): este arquivo
 * inclui o hps_0.h e so acrescenta o que o .sopcinfo nao informa.
 *
 * Estado de cada ponte conforme rtl/core/hps/soc_system.qsys:
 *   h2f_lw : habilitada, ligada ao avalon_cmd_slave_0  -> CAMINHO DOS COMANDOS
 *   h2f    : habilitada (S2F_Width=2), SEM escravo ligado
 *   f2h    : habilitada (F2S_Width=2), SEM mestre ligado
 *   F2SDRAM: nao habilitada
 *   f2h_irq: habilitada (F2SINTERRUPT_Enable), SEM conexao
 * Clock das tres pontes AXI: clk_0 = 50 MHz (mesmo do avalon_cmd_slave).
 *
 * Itens marcados "CONFERIR" vem do Cyclone V HPS TRM (nao do projeto) e
 * devem ser confirmados antes de uso.
 * ========================================================================== */
#ifndef HPS_BRIDGES_H
#define HPS_BRIDGES_H

#include <stdint.h>
#include "hps_0.h"

/* ----------------------------------------------------------------------------
 * 1) Ponte lightweight HPS->FPGA (h2f_lw)  -  USADA
 *    AXI-3, 32 bits fixo. Destinada a registradores de controle (baixo
 *    throughput, alta latencia). Acessos de 32 bits e alinhados.
 * -------------------------------------------------------------------------- */
#define HPS_LW_BASE            0xFF200000u   /* endereco fisico (ARM)        */
#define HPS_LW_SPAN            0x00200000u   /* 2 MB                         */
#define HPS_LW_DATA_WIDTH      32            /* bits                         */
#define HPS_LW_ENABLED         1             /* LWH2F_Enable = true          */
#define HPS_LW_IN_USE          1

/* Posicao do avalon_cmd_slave_0 dentro da ponte (vem do hps_0.h) */
#define HPS_LW_COPROC_OFFSET   AVALON_CMD_SLAVE_0_BASE   /* 0x0              */
#define HPS_LW_COPROC_SPAN     AVALON_CMD_SLAVE_0_SPAN   /* 16 bytes         */
#define HPS_LW_COPROC_PHYS     (HPS_LW_BASE + HPS_LW_COPROC_OFFSET)

/* Registradores do avalon_cmd_slave (offsets em bytes a partir do slave) */
#define COPROC_REG_CMD         0x00u   /* W: empurra palavra da ISA na fila   */
#define COPROC_REG_STATUS      0x04u   /* R                                   */
#define COPROC_REG_CTRL        0x08u   /* W                                   */
#define COPROC_REG_ID          0x0Cu   /* R: confere ponte e bitstream        */
#define COPROC_ID_VALUE        0xC0DE0001u

/* STATUS */
#define COPROC_ST_FULL         (1u << 0)
#define COPROC_ST_EMPTY        (1u << 1)
#define COPROC_ST_RUNNING      (1u << 2)
#define COPROC_ST_WAITING      (1u << 3)
#define COPROC_ST_VBLANK       (1u << 4)
#define COPROC_ST_ERROR        (1u << 5)    /* trava                         */
#define COPROC_ST_OVERFLOW     (1u << 6)    /* trava                         */
#define COPROC_ST_INIT_BUSY    (1u << 7)
#define COPROC_ST_PLL_LOCKED   (1u << 8)
#define COPROC_ST_FRAME_COUNT(s)  ((uint32_t)(s) >> 16)

/* CTRL */
#define COPROC_CTRL_SOFT_RESET  (1u << 0)
#define COPROC_CTRL_CLEAR_FLAGS (1u << 1)

/* Uso (Linux): mmap de /dev/mem (O_SYNC), offset HPS_LW_BASE, tamanho
 * HPS_LW_SPAN, ponteiros volatile uint32_t. Fluxo de envio:
 *   1. ler ID e conferir COPROC_ID_VALUE
 *   2. esperar STATUS.FULL == 0
 *   3. escrever a palavra de 32 bits da ISA em CMD
 * O slave NAO tem waitrequest, byteenable nem rajada.                       */
#define HPS_REG32(virt_base, off) \
    (*(volatile uint32_t *)((uintptr_t)(virt_base) + (uintptr_t)(off)))
#define COPROC_REG32(lw_virt, reg) \
    HPS_REG32((lw_virt), HPS_LW_COPROC_OFFSET + (reg))

/* ----------------------------------------------------------------------------
 * 2) Ponte HPS->FPGA (h2f)  -  HABILITADA, NAO USADA
 *    AXI-3, largura configuravel 32/64/128 bits. Para cargas grandes (imagens,
 *    tiles); exigiria escravo Avalon com rajada. Hoje sem escravo conectado.
 * -------------------------------------------------------------------------- */
#define HPS_H2F_BASE           0xC0000000u
#define HPS_H2F_SPAN           0x3C000000u   /* 960 MB (CONFERIR)            */
#define HPS_H2F_DATA_WIDTH     64            /* S2F_Width = 2 no qsys        */
#define HPS_H2F_ENABLED        1
#define HPS_H2F_IN_USE         0

/* ----------------------------------------------------------------------------
 * 3) Ponte FPGA->HPS (f2h)  -  HABILITADA, NAO USADA
 *    AXI-3, 32/64/128 bits. A FPGA e mestre e enxerga o espaco de enderecos
 *    do HPS. Nao serve para o driver enviar dados ao coprocessador.
 * -------------------------------------------------------------------------- */
#define HPS_F2H_DATA_WIDTH     64            /* F2S_Width = 2 no qsys        */
#define HPS_F2H_ENABLED        1
#define HPS_F2H_IN_USE         0

/* ----------------------------------------------------------------------------
 * 4) FPGA->controlador SDRAM (F2SDRAM)  -  NAO HABILITADA
 *    Ate 6 portas, 32 a 256 bits cada, acesso direto a DDR3 do HPS. So
 *    seria necessaria se o coprocessador lesse a DDR3 por conta propria.
 * -------------------------------------------------------------------------- */
#define HPS_F2SDRAM_ENABLED    0
#define HPS_F2SDRAM_IN_USE     0

/* ----------------------------------------------------------------------------
 * 5) Interrupcoes FPGA->HPS (f2h_irq)  -  HABILITADA, SEM CONEXAO
 *    Hoje a sincronizacao e por polling em STATUS. f2h_irq0[31:0] e
 *    f2h_irq1[31:0] chegam ao GIC como SPIs (CONFERIR IDs no TRM).
 * -------------------------------------------------------------------------- */
#define HPS_F2H_IRQ_ENABLED    1
#define HPS_F2H_IRQ_IN_USE     0
#define HPS_F2H_IRQ0_GIC_BASE  72u           /* CONFERIR */
#define HPS_F2H_IRQ1_GIC_BASE  104u          /* CONFERIR */

/* ----------------------------------------------------------------------------
 * Clock e reset
 * -------------------------------------------------------------------------- */
#define HPS_BRIDGE_CLK_HZ      50000000u     /* clk_0 -> h2f, h2f_lw, f2h    */

/* Bare-metal: liberar as pontes do reset (Reset Manager, brgmodrst).
 * Em Linux isso e feito pelo preloader / driver de ponte do kernel.
 * CONFERIR enderecos e bits no TRM.                                         */
#define HPS_RSTMGR_BASE        0xFFD05000u
#define HPS_RSTMGR_BRGMODRST   0x1Cu
#define HPS_BRGMODRST_H2F      (1u << 0)
#define HPS_BRGMODRST_LWH2F    (1u << 1)
#define HPS_BRGMODRST_F2H      (1u << 2)

/* ----------------------------------------------------------------------------
 * Verificacoes em tempo de compilacao
 * -------------------------------------------------------------------------- */
/* Macro portatil: funciona em C89/C99 (fallback com typedef de array de
 * tamanho negativo), C11 (_Static_assert) e C++11 (static_assert). */
#define HPS_CAT_(a, b) a##b
#define HPS_CAT(a, b)  HPS_CAT_(a, b)
#if defined(__cplusplus) && (__cplusplus >= 201103L)
#  define HPS_STATIC_ASSERT(cond, msg) static_assert(cond, msg)
#elif defined(__STDC_VERSION__) && (__STDC_VERSION__ >= 201112L)
#  define HPS_STATIC_ASSERT(cond, msg) _Static_assert(cond, msg)
#else
#  define HPS_STATIC_ASSERT(cond, msg) \
     typedef char HPS_CAT(hps_static_assert_, __LINE__)[(cond) ? 1 : -1]
#endif

HPS_STATIC_ASSERT(HPS_LW_COPROC_OFFSET + HPS_LW_COPROC_SPAN <= HPS_LW_SPAN,
                  "avalon_cmd_slave fora da janela da ponte lightweight");
HPS_STATIC_ASSERT((HPS_LW_BASE & 0xFFFu) == 0,
                  "base da ponte LW precisa ser alinhada a pagina para o mmap");

#endif /* HPS_BRIDGES_H */