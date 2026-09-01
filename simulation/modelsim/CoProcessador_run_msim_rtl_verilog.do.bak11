transcript on
if ![file isdirectory CoProcessador_iputf_libs] {
	file mkdir CoProcessador_iputf_libs
}

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

###### Libraries for IPUTF cores 
###### End libraries for IPUTF cores 
###### MIF file copy and HDL compilation commands for IPUTF cores 


vlog "E:/CoprocessadorGrafico/pll01_sim/pll01.vo"

vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico/memory_files {E:/CoprocessadorGrafico/memory_files/framebuffer_ram.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico/memory_files {E:/CoprocessadorGrafico/memory_files/bg_tile_ram.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/DE1_SOC_golden_top.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/vga_driver.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/top_video.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/tb_vga_memory.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/motor_background.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/motor_sprite.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/fb_addr_gen.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/framebuffer.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/rasterizador_quadrado.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/rasterizador_triangulo.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/rasterizador_top.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/divisor_unsigned.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico/memory_files {E:/CoprocessadorGrafico/memory_files/sprite_attribute_ram.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico/memory_files {E:/CoprocessadorGrafico/memory_files/sprite_pattern_ram.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico/memory_files {E:/CoprocessadorGrafico/memory_files/palette_ram.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/compositor.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico/memory_files {E:/CoprocessadorGrafico/memory_files/bg_tile_pattern_ram.v}
vlog -vlog01compat -work work +incdir+E:/CoprocessadorGrafico {E:/CoprocessadorGrafico/test_driver.v}

