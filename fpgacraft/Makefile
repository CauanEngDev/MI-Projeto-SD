CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -std=c11
CPPFLAGS := -Iinclude
COMMON := src/minecraft.c

.PHONY: all host fpga clean
all: host

host: fpgacraft-host
fpgacraft-host: $(COMMON) src/main_host.c src/video_host.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $^ -o $@

# Compilacao na DE1-SoC (Linux ARM 32-bit). Toda a API de comunicacao tambem e C.
fpga: fpgacraft-fpga
fpgacraft-fpga: $(COMMON) src/main_fpga.c src/video_fpga.c src/cop_api.c src/input.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $^ -o $@

clean:
	rm -f fpgacraft-host fpgacraft-fpga fpgacraft.ppm
