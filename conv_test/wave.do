onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /testbench/u_convolution_1/clock
add wave -noupdate /testbench/u_convolution_1/reset_n
add wave -noupdate /testbench/u_convolution_1/bias_memory
add wave -noupdate /testbench/u_convolution_1/weight_memory
add wave -noupdate /testbench/u_convolution_1/output_buffer
add wave -noupdate /testbench/u_convolution_1/images
add wave -noupdate /testbench/u_convolution_1/sh_reg
add wave -noupdate /testbench/u_convolution_1/in_image_no
add wave -noupdate /testbench/u_convolution_1/p_image_no
add wave -noupdate /testbench/u_convolution_1/out_image_no
add wave -noupdate /testbench/u_convolution_1/product_array
add wave -noupdate /testbench/u_convolution_1/row_sums
add wave -noupdate /testbench/u_convolution_1/filter_sums
add wave -noupdate /testbench/u_convolution_1/start_receive
add wave -noupdate /testbench/u_convolution_1/receiving
add wave -noupdate /testbench/u_convolution_1/done_receive
add wave -noupdate /testbench/u_convolution_1/start_process
add wave -noupdate /testbench/u_convolution_1/processing
add wave -noupdate /testbench/u_convolution_1/done_process
add wave -noupdate /testbench/u_convolution_1/start_send
add wave -noupdate /testbench/u_convolution_1/sending
add wave -noupdate /testbench/u_convolution_1/done_send
add wave -noupdate /testbench/u_convolution_1/send
add wave -noupdate /testbench/u_convolution_1/receive
add wave -noupdate /testbench/u_convolution_1/shifting
add wave -noupdate /testbench/u_convolution_1/in_index
add wave -noupdate /testbench/u_convolution_1/out_index
add wave -noupdate /testbench/u_convolution_1/p_index
add wave -noupdate /testbench/u_convolution_1/sr_idx
add wave -noupdate /testbench/u_convolution_1/state
add wave -noupdate /testbench/u_convolution_1/next_state
add wave -noupdate /testbench/u_convolution_1/rx_state
add wave -noupdate /testbench/u_convolution_1/next_rx_state
add wave -noupdate /testbench/u_convolution_1/tx_state
add wave -noupdate /testbench/u_convolution_1/next_tx_state
add wave -noupdate /testbench/u_convolution_1/in_col
add wave -noupdate /testbench/u_convolution_1/in_row
add wave -noupdate /testbench/u_convolution_1/offset
add wave -noupdate /testbench/u_convolution_1/out_row
add wave -noupdate /testbench/u_convolution_1/out_col
add wave -noupdate /testbench/u_convolution_1/features_in/features
add wave -noupdate /testbench/u_convolution_1/features_in/valid
add wave -noupdate /testbench/u_convolution_1/features_in/ready
add wave -noupdate /testbench/u_convolution_1/features_out/features
add wave -noupdate /testbench/u_convolution_1/features_out/valid
add wave -noupdate /testbench/u_convolution_1/features_out/ready
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {18183 ns}
