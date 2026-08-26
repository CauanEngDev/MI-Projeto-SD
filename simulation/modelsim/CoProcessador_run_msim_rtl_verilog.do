transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+F:/Pbl\ Sd\ 1 {F:/Pbl Sd 1/tile_memory.v}
vlog -vlog01compat -work work +incdir+F:/Pbl\ Sd\ 1 {F:/Pbl Sd 1/vga_driver.v}
vlog -vlog01compat -work work +incdir+F:/Pbl\ Sd\ 1 {F:/Pbl Sd 1/top_video.v}

