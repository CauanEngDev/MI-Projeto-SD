#define _GNU_SOURCE
#include "acel.h"

#include <errno.h>
#include <fcntl.h>
#include <linux/i2c-dev.h>     /* I2C_SLAVE, I2C_SLAVE_FORCE */
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

/* Registradores do ADXL345 */
#define REG_DEVID        0x00
#define REG_BW_RATE      0x2C
#define REG_POWER_CTL    0x2D
#define REG_DATA_FORMAT  0x31
#define REG_DATAX0       0x32

#define BW_RATE_100HZ    0x0A   /* taxa de saida de 100 Hz (padrao do chip)         */
#define FMT_FULL_RES_2G  0x08   /* FULL_RES = 1, faixa +-2 g: 256 LSB por g          */
#define PWR_MEASURE      0x08   /* bit Measure                                       */
#define PWR_STANDBY      0x00

/* Backend i2c-dev: o contexto e o proprio acel_t, que guarda o descritor */
static int i2c_write_reg(void *ctx, uint8_t reg, uint8_t value)
{
    acel_t *a = ctx;
    uint8_t b[2] = { reg, value };
    return write(a->fd, b, 2) == 2 ? 0 : -1;
}

static int i2c_read_regs(void *ctx, uint8_t reg, uint8_t *buf, int n)
{
    acel_t *a = ctx;
    if (write(a->fd, &reg, 1) != 1) return -1;      /* aponta o registrador   */
    return read(a->fd, buf, (size_t)n) == n ? 0 : -1;
}

void acel_set_axes(acel_t *a, int sx, int sy, int sz)
{
    a->sign[0] = sx < 0 ? -1 : 1;
    a->sign[1] = sy < 0 ? -1 : 1;
    a->sign[2] = sz < 0 ? -1 : 1;
}

/* Configura o sensor sobre o barramento ja guardado em a->bus (nao mexe em a->fd) */
static int init_sensor(acel_t *a)
{
    uint8_t id = 0;
    if (a->bus.read_regs(a->bus.ctx, REG_DEVID, &id, 1) < 0) return ACEL_ERR_IO;
    if (id != ACEL_DEVID_VALUE) return ACEL_ERR_ID;

    /* Configura primeiro, liga a medicao por ultimo */
    if (a->bus.write_reg(a->bus.ctx, REG_BW_RATE,     BW_RATE_100HZ)   < 0) return ACEL_ERR_IO;
    if (a->bus.write_reg(a->bus.ctx, REG_DATA_FORMAT, FMT_FULL_RES_2G) < 0) return ACEL_ERR_IO;
    if (a->bus.write_reg(a->bus.ctx, REG_POWER_CTL,   PWR_MEASURE)     < 0) return ACEL_ERR_IO;

    a->is_open = 1;
    return ACEL_OK;
}

int acel_open_bus(acel_t *a, const acel_bus_t *bus)
{
    memset(a, 0, sizeof *a);
    a->fd = -1;                           /* barramento externo: nao ha descritor a fechar */
    a->bus = *bus;
    acel_set_axes(a, 1, 1, 1);
    return init_sensor(a);
}

/* Tenta um /dev/i2c-N: abre, escolhe o endereco 0x53 e inicializa o sensor */
static int try_dev(acel_t *a, const char *dev)
{
    int fd = open(dev, O_RDWR | O_CLOEXEC);
    if (fd < 0) return ACEL_ERR_OPEN;
    /* Se um driver do kernel ja reivindicou o endereco (EBUSY), usa o modo forcado */
    if (ioctl(fd, I2C_SLAVE, ACEL_ADDR) < 0 &&
        (errno != EBUSY || ioctl(fd, I2C_SLAVE_FORCE, ACEL_ADDR) < 0)) {
        close(fd);
        return ACEL_ERR_OPEN;
    }
    memset(a, 0, sizeof *a);
    a->fd = fd;
    a->bus.write_reg = i2c_write_reg;
    a->bus.read_regs = i2c_read_regs;
    a->bus.ctx = a;
    acel_set_axes(a, 1, 1, 1);
    int rc = init_sensor(a);
    if (rc != ACEL_OK) { close(fd); a->fd = -1; }
    return rc;
}

int acel_open(acel_t *a, const char *dev)
{
    memset(a, 0, sizeof *a);
    a->fd = -1;
    if (dev) return try_dev(a, dev);

    int best = ACEL_ERR_OPEN;
    for (int i = 0; i < 4; i++) {
        char path[32];
        snprintf(path, sizeof path, "/dev/i2c-%d", i);
        int rc = try_dev(a, path);
        if (rc == ACEL_OK) return ACEL_OK;
        if (rc != ACEL_ERR_OPEN) best = rc;       /* achou o barramento, mas nao o sensor */
        a->fd = -1;
    }
    return best;
}

int acel_read(acel_t *a, int32_t *x_mg, int32_t *y_mg, int32_t *z_mg)
{
    uint8_t b[6];
    if (!a->is_open || a->bus.read_regs(a->bus.ctx, REG_DATAX0, b, 6) < 0) return ACEL_ERR_IO;

    for (int i = 0; i < 3; i++) {
        int16_t raw = (int16_t)(uint16_t)(b[2 * i] | (b[2 * i + 1] << 8));   /* little-endian */
        a->raw[i] = raw;
        /* Resolucao total: 3,90625 mg por LSB (= 125/32) */
        int32_t mg = (int32_t)raw * 125 / 32 * a->sign[i];
        a->mg[i] = a->primed ? a->mg[i] + (mg - a->mg[i]) / 4 : mg;
    }
    a->primed = 1;

    if (x_mg) *x_mg = a->mg[0];
    if (y_mg) *y_mg = a->mg[1];
    if (z_mg) *z_mg = a->mg[2];
    return ACEL_OK;
}

void acel_close(acel_t *a)
{
    if (a->is_open) a->bus.write_reg(a->bus.ctx, REG_POWER_CTL, PWR_STANDBY);
    if (a->fd >= 0) close(a->fd);
    a->fd = -1;
    a->is_open = 0;
}