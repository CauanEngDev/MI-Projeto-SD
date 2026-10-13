#!/bin/sh
# Simulacao do coprocessador_top completo (Icarus Verilog) com o programa em ordem
# invertida: SPRITES -> RECT -> BG. Executar a partir da raiz do projeto:
#     sh tb/sim_top/run.sh [inv|ok|fundo_depois]
# As IPs do Quartus (PLL e RAMs) sao substituidas por modelos em stubs_ip_quartus.v.
set -e
PROG=${1:-inv}
D=tb/sim_top
python3 $D/gerar_hex.py > /dev/null
iverilog -g2005 -o /tmp/top_prio.vvp $D/tb_top_prioridade.v $D/stubs_ip_quartus.v \
  rtl/core/coprocessador_top.v rtl/core/unidade_de_busca_de_instrucoes.v rtl/core/unidade_de_controle.v rtl/core/avalia_condicao.v \
  rtl/core/banco_registradores.v rtl/core/alu.v rtl/core/Program_counter.v rtl/core/Adder.v \
  rtl/core/camada_composicao.v rtl/utils/fb_addr_gen.v rtl/utils/framebuffer.v rtl/drivers/vga_driver.v \
  rtl/motores_independentes/motor_background.v rtl/motores_independentes/motor_sprite.v \
  rtl/rasterizers/rasterizador_top.v rtl/rasterizers/rasterizador_quadrado.v \
  rtl/rasterizers/rasterizador_triangulo.v rtl/utils/divisor_unsigned.v
vvp /tmp/top_prio.vvp +HEX=$D/prog_$PROG.hex
