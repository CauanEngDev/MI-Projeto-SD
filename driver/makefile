# Estrutura esperada (a do repositorio):
#   driver/Makefile
#   driver/include/   hps_0.h  hps_bridges.h  cop_api.h  input.h  acel.h  game.h  app.h
#   driver/src/       main.c  app.c  game.c  input.c  acel.c
#   driver/src/asm/   api.S
# Compile na propria DE1-SoC (gcc nativo) ou use CC=arm-linux-gnueabihf-gcc.

CC      ?= gcc
CFLAGS  ?= -O2 -Wall -Wextra -std=gnu11
INC     := -Iinclude

OBJ     := build/main.o build/app.o build/game.o build/input.o build/acel.o build/api.o
BIN     := estrelas

all: $(BIN)

$(BIN): $(OBJ)
	$(CC) $(CFLAGS) -no-pie -o $@ $(OBJ) -lrt

build/%.o: src/%.c | build
	$(CC) $(CFLAGS) $(INC) -c $< -o $@

# api.S usa #include, entao precisa do pre-processador (extensao .S maiuscula)
build/api.o: src/asm/api.S | build
	$(CC) $(INC) -c $< -o $@

build:
	mkdir -p build

clean:
	rm -rf build $(BIN)

.PHONY: all clean