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


vlog "E:/FINAL/pll01_sim/pll01.vo"

vlog -vlog01compat -work work +incdir+E:/FINAL/memory_files {E:/FINAL/memory_files/framebuffer_ram.v}
vlog -vlog01compat -work work +incdir+E:/FINAL/memory_files {E:/FINAL/memory_files/bg_tile_ram.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/DE1_SOC_golden_top.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/vga_driver.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/top_video.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/motor_background.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/motor_sprite.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/fb_addr_gen.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/framebuffer.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/rasterizador_quadrado.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/rasterizador_triangulo.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/rasterizador_top.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/divisor_unsigned.v}
vlog -vlog01compat -work work +incdir+E:/FINAL/memory_files {E:/FINAL/memory_files/sprite_attribute_ram.v}
vlog -vlog01compat -work work +incdir+E:/FINAL/memory_files {E:/FINAL/memory_files/sprite_pattern_ram.v}
vlog -vlog01compat -work work +incdir+E:/FINAL/memory_files {E:/FINAL/memory_files/palette_ram.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/compositor.v}
vlog -vlog01compat -work work +incdir+E:/FINAL/memory_files {E:/FINAL/memory_files/bg_tile_pattern_ram.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/test_driver.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/sprite_mover_flip.v}
vlog -vlog01compat -work work +incdir+E:/FINAL {E:/FINAL/sprite_spawner.v}

