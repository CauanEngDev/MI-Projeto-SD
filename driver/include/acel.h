/* ============================================================================
 * acel.h - Acelerometro ADXL345 da DE1-SoC, lido pelo ARM via I2C (i2c-dev)
 *
 * No hardware da placa o ADXL345 esta ligado ao I2C do HPS (nao a FPGA), entao
 * e lido pelo Linux em /dev/i2c-N, no endereco 0x53. Os valores saem em
 * milli-g (1000 = 1 g) ja filtrados.
 *
 * O acesso ao barramento fica atras de duas funcoes (acel_bus_t), o que permite
 * testar toda a logica sem o hardware.
 * ========================================================================== */
#ifndef ACEL_H
#define ACEL_H

#include <stdint.h>

#define ACEL_ADDR        0x53     /* ADXL345 com ALT ADDRESS em GND */
#define ACEL_DEVID_VALUE 0xE5

/* Codigos de retorno */
#define ACEL_OK           0
#define ACEL_ERR_OPEN    (-1)     /* nenhum /dev/i2c-N utilizavel                  */
#define ACEL_ERR_ID      (-2)     /* nao respondeu como ADXL345 (DEVID != 0xE5)    */
#define ACEL_ERR_IO      (-3)     /* falha de leitura/escrita no barramento        */

typedef struct acel_bus {
    int   (*write_reg)(void *ctx, uint8_t reg, uint8_t value);           /* 0 ok, <0 erro */
    int   (*read_regs)(void *ctx, uint8_t reg, uint8_t *buf, int n);     /* 0 ok, <0 erro */
    void  *ctx;
} acel_bus_t;

typedef struct {
    acel_bus_t bus;
    int        fd;            /* descritor do /dev/i2c-N (-1 se nao for i2c-dev) */
    int        is_open;
    int        primed;        /* o filtro ja recebeu a primeira amostra          */
    int        sign[3];       /* +1 ou -1 por eixo (orientacao da placa)         */
    int16_t    raw[3];        /* ultima amostra, em LSB                          */
    int32_t    mg[3];         /* ultima amostra filtrada, em milli-g             */
} acel_t;

/* Abre o i2c-dev: com "dev" (ex.: "/dev/i2c-0") usa esse; com NULL procura em
 * /dev/i2c-0../dev/i2c-3 o primeiro onde o endereco 0x53 responde como ADXL345.
 * Configura 100 Hz, resolucao total e inicia a medicao. */
int  acel_open(acel_t *a, const char *dev);

/* O mesmo, sobre um barramento fornecido (testes ou outra camada de acesso). */
int  acel_open_bus(acel_t *a, const acel_bus_t *bus);

/* Inverte o sentido de cada eixo (+1 ou -1). Padrao: +1, +1, +1. */
void acel_set_axes(acel_t *a, int sx, int sy, int sz);

/* Le uma amostra e atualiza o filtro (media movel exponencial, 1/4 por leitura).
 * Devolve ACEL_OK ou ACEL_ERR_IO (a ultima amostra valida e mantida). Os ponteiros
 * de saida podem ser NULL. */
int  acel_read(acel_t *a, int32_t *x_mg, int32_t *y_mg, int32_t *z_mg);

/* Coloca o sensor em standby e fecha o descritor. */
void acel_close(acel_t *a);

#endif /* ACEL_H */