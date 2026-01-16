transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vcom -93 -work work {C:/Users/Felix/Documents/QUARTUS/lcd/lcd_controller.vhd}
vcom -93 -work work {C:/Users/Felix/Documents/QUARTUS/lcd/lcd_top.vhd}
vcom -93 -work work {C:/Users/Felix/Documents/QUARTUS/lcd/tb_lcd_morse.vhd}

vsim -t 1ns -L altera -L lpm -L sgate -L altera_mf -L altera_lnsim -L cyclonev -L rtl_work -L work -voptargs="+acc"  tb_lcd_morse

# Main Visibility
add wave -noupdate -divider "TOP SIGNALS"
add wave -noupdate -position end  sim:/tb_lcd_morse/clk
add wave -noupdate -position end  sim:/tb_lcd_morse/reset_n
add wave -noupdate -position end  sim:/tb_lcd_morse/btn
add wave -noupdate -position end  -radix ascii sim:/tb_lcd_morse/lcd_char_view
add wave -noupdate -position end  sim:/tb_lcd_morse/e

add wave -noupdate -divider "FSM STATES"
add wave -noupdate -label "Top State" sim:/tb_lcd_morse/uut/state
add wave -noupdate -label "LCD State" sim:/tb_lcd_morse/uut/u1/state

add wave -noupdate -divider "MORSE INTERNAL"
add wave -noupdate -label "Char Ready" sim:/tb_lcd_morse/uut/char_ready
add wave -noupdate -radix hex -label "Decoded Hex" sim:/tb_lcd_morse/uut/decoded_char
add wave -noupdate -label "Pattern Len" sim:/tb_lcd_morse/uut/pattern_length
add wave -noupdate -label "Dots/Dashes" sim:/tb_lcd_morse/uut/dots_dashes

add wave -noupdate -divider "LCD CONTROL"
add wave -noupdate -label "LCD Busy" sim:/tb_lcd_morse/uut/lcd_busy
add wave -noupdate -label "LCD Enable" sim:/tb_lcd_morse/uut/lcd_enable
add wave -noupdate -radix hex -label "LCD Data Bus" sim:/tb_lcd_morse/uut/lcd_data

configure wave -namecolwidth 200
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2

view structure
view signals
run -all
