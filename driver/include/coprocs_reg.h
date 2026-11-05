#ifndef COPROC_REGS_H
#define COPROC_REGS_H
#include "hps_0.h"

#define HW_REGS_BASE    0xFF200000u              /* ponte h2f_lw (Cyclone V) */
#define HW_REGS_SPAN    0x00200000u              /* mmap de /dev/mem */
#define COPROC_OFFSET   AVALON_CMD_SLAVE_0_BASE  /* dentro da ponte */

/* offsets em bytes a partir de COPROC_OFFSET */
#define REG_CMD     0x00   /* W: empurra palavra da ISA na fila */
#define REG_STATUS  0x04   /* R */
#define REG_CTRL    0x08   /* W */
#define REG_ID      0x0C   /* R */
#define COPROC_ID   0xC0DE0001u

/* STATUS */
#define ST_FULL        (1u << 0)
#define ST_EMPTY       (1u << 1)
#define ST_RUNNING     (1u << 2)
#define ST_WAITING     (1u << 3)
#define ST_VBLANK      (1u << 4)
#define ST_ERROR       (1u << 5)   /* trava */
#define ST_OVERFLOW    (1u << 6)   /* trava */
#define ST_INIT_BUSY   (1u << 7)
#define ST_PLL_LOCKED  (1u << 8)
#define ST_FRAME_COUNT(s)  ((s) >> 16)

/* CTRL */
#define CTRL_SOFT_RESET   (1u << 0)
#define CTRL_CLEAR_FLAGS  (1u << 1)
#endif