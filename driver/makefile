# Compilacao do Pac-Man para Linux/DE1-SoC.
# Na placa, use o gcc nativo. Para cross-compilacao, informe CC na chamada do make.

CC       ?= gcc
CFLAGS   ?= -O2 -Wall -Wextra -std=gnu99
CPPFLAGS += -Iinclude
LDFLAGS  += -no-pie
LDLIBS   += -lrt

BIN      := pacman

PAC_OBJS := \
	build/pac_main.o \
	build/pac_app.o \
	build/pac_core.o \
	build/pac_input.o \
	build/pac_render.o \
	build/pac_assets_data.o \
	build/maze.o \
	build/perf.o \
	build/input.o \
	build/api.o

.PHONY: all clean

all: $(BIN)

$(BIN): $(PAC_OBJS)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

build/%.o: src/%.c | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# api.S usa o pre-processador do compilador C.
build/api.o: src/asm/api.S | build
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

build:
	mkdir -p $@

clean:
	rm -rf build $(BIN)
