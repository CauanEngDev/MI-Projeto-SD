#include <stdio.h>
#include <stdint.h>
#include "cop_api_c.h"
#include "hps_bridges.h"

int main(void) {
    void *base = hps_open();

    if (!base) {
        perror("hps_open");
        return 1;
    }

    volatile uint32_t *id =
        (volatile uint32_t *)((uintptr_t)base +
        HPS_LW_COPROC_OFFSET + COPROC_REG_ID);

    volatile uint32_t *ctrl =
        (volatile uint32_t *)((uintptr_t)base +
        HPS_LW_COPROC_OFFSET + COPROC_REG_CTRL);

    volatile uint32_t *status =
        (volatile uint32_t *)((uintptr_t)base +
        HPS_LW_COPROC_OFFSET + COPROC_REG_STATUS);

    printf("Endereco do coprocessador: 0x%08X\n",
           (unsigned)HPS_LW_COPROC_PHYS);
    printf("ID esperado: 0x%08X\n", COPROC_ID_VALUE);
    printf("ID lido:     0x%08X\n", *id);
    printf("STATUS:      0x%08X\n", *status);

    if (*id == COPROC_ID_VALUE) {
        *ctrl = COPROC_CTRL_SOFT_RESET;

        for (volatile unsigned i = 0; i < 1000000; i++);

        printf("STATUS apos reset: 0x%08X\n", *status);
    }

    hps_close(base);
    return 0;
}
