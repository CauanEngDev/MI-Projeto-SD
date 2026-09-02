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


vlog "F:/CoprocessadorGrafico/pll01_sim/pll01.vo"

vlog  -work work +incdir+F:/CoprocessadorGrafico/memory_files {F:/CoprocessadorGrafico/memory_files/framebuffer_ram.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico/memory_files {F:/CoprocessadorGrafico/memory_files/bg_tile_ram.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/DE1_SOC_golden_top.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/vga_driver.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/top_video.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/tb_vga_memory.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/motor_background.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/motor_sprite.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/fb_addr_gen.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/framebuffer.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/rasterizador_quadrado.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/rasterizador_triangulo.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/rasterizador_top.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/divisor_unsigned.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico/memory_files {F:/CoprocessadorGrafico/memory_files/sprite_attribute_ram.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico/memory_files {F:/CoprocessadorGrafico/memory_files/sprite_pattern_ram.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico/memory_files {F:/CoprocessadorGrafico/memory_files/palette_ram.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/compositor.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico/memory_files {F:/CoprocessadorGrafico/memory_files/bg_tile_pattern_ram.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/test_driver.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/sprite_mover_flip.v}
vlog  -work work +incdir+F:/CoprocessadorGrafico {F:/CoprocessadorGrafico/sprite_spawner.v}

