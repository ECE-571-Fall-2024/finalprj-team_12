onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {Convolution 1}
add wave -noupdate /testbench/dut/u_convolution_1/features_in/features
add wave -noupdate /testbench/dut/u_convolution_1/features_in/valid
add wave -noupdate /testbench/dut/u_convolution_1/features_in/ready
add wave -noupdate /testbench/dut/u_convolution_1/clock
add wave -noupdate /testbench/dut/u_convolution_1/reset_n
add wave -noupdate /testbench/dut/u_convolution_1/sum
add wave -noupdate /testbench/dut/u_convolution_1/r
add wave -noupdate /testbench/dut/u_convolution_1/c
add wave -noupdate /testbench/dut/u_convolution_1/features_out/features
add wave -noupdate /testbench/dut/u_convolution_1/features_out/valid
add wave -noupdate /testbench/dut/u_convolution_1/features_out/ready
add wave -noupdate -divider {Max Pool 1}
add wave -noupdate /testbench/dut/u_max_pool_1/features_in/features
add wave -noupdate /testbench/dut/u_max_pool_1/features_in/valid
add wave -noupdate /testbench/dut/u_max_pool_1/features_in/ready
add wave -noupdate /testbench/dut/u_max_pool_1/clock
add wave -noupdate /testbench/dut/u_max_pool_1/reset_n
add wave -noupdate /testbench/dut/u_max_pool_1/max
add wave -noupdate /testbench/dut/u_max_pool_1/features_out/features
add wave -noupdate /testbench/dut/u_max_pool_1/features_out/valid
add wave -noupdate /testbench/dut/u_max_pool_1/features_out/ready
add wave -noupdate -divider {Convolution 2}
add wave -noupdate /testbench/dut/u_convolution_2/features_in/features
add wave -noupdate /testbench/dut/u_convolution_2/features_in/valid
add wave -noupdate /testbench/dut/u_convolution_2/features_in/ready
add wave -noupdate /testbench/dut/u_convolution_2/clock
add wave -noupdate /testbench/dut/u_convolution_2/reset_n
add wave -noupdate /testbench/dut/u_convolution_2/sum
add wave -noupdate /testbench/dut/u_convolution_2/r
add wave -noupdate /testbench/dut/u_convolution_2/c
add wave -noupdate /testbench/dut/u_convolution_2/features_out/features
add wave -noupdate /testbench/dut/u_convolution_2/features_out/valid
add wave -noupdate /testbench/dut/u_convolution_2/features_out/ready
add wave -noupdate -divider {Max Pool 2}
add wave -noupdate /testbench/dut/u_max_pool_2/features_in/features
add wave -noupdate /testbench/dut/u_max_pool_2/features_in/valid
add wave -noupdate /testbench/dut/u_max_pool_2/features_in/ready
add wave -noupdate /testbench/dut/u_max_pool_2/clock
add wave -noupdate /testbench/dut/u_max_pool_2/reset_n
add wave -noupdate /testbench/dut/u_max_pool_2/max
add wave -noupdate /testbench/dut/u_max_pool_2/features_out/features
add wave -noupdate /testbench/dut/u_max_pool_2/features_out/valid
add wave -noupdate /testbench/dut/u_max_pool_2/features_out/ready
add wave -noupdate -divider {Dense 1}
add wave -noupdate /testbench/dut/u_dense_1/features_in/features
add wave -noupdate /testbench/dut/u_dense_1/features_in/valid
add wave -noupdate /testbench/dut/u_dense_1/features_in/ready
add wave -noupdate /testbench/dut/u_dense_1/clock
add wave -noupdate /testbench/dut/u_dense_1/reset_n
add wave -noupdate /testbench/dut/u_dense_1/feature_in_count
add wave -noupdate /testbench/dut/u_dense_1/feature_out_count
add wave -noupdate /testbench/dut/u_dense_1/feature
add wave -noupdate /testbench/dut/u_dense_1/sum
add wave -noupdate /testbench/dut/u_dense_1/features_out/features
add wave -noupdate /testbench/dut/u_dense_1/features_out/valid
add wave -noupdate /testbench/dut/u_dense_1/features_out/ready
add wave -noupdate -divider {Dense 2}
add wave -noupdate /testbench/dut/u_dense_2/features_in/features
add wave -noupdate /testbench/dut/u_dense_2/features_in/valid
add wave -noupdate /testbench/dut/u_dense_2/features_in/ready
add wave -noupdate /testbench/dut/u_dense_2/clock
add wave -noupdate /testbench/dut/u_dense_2/reset_n
add wave -noupdate /testbench/dut/u_dense_2/feature_in_count
add wave -noupdate /testbench/dut/u_dense_2/feature_out_count
add wave -noupdate /testbench/dut/u_dense_2/feature
add wave -noupdate /testbench/dut/u_dense_2/sum
add wave -noupdate /testbench/dut/u_dense_2/features_out/features
add wave -noupdate /testbench/dut/u_dense_2/features_out/valid
add wave -noupdate /testbench/dut/u_dense_2/features_out/ready
add wave -noupdate -divider Softmax
add wave -noupdate /testbench/dut/u_softmax/features_in/features
add wave -noupdate /testbench/dut/u_softmax/features_in/valid
add wave -noupdate /testbench/dut/u_softmax/features_in/ready
add wave -noupdate /testbench/dut/u_softmax/clock
add wave -noupdate /testbench/dut/u_softmax/reset_n
add wave -noupdate /testbench/dut/u_softmax/features_out/features
add wave -noupdate /testbench/dut/u_softmax/features_out/valid
add wave -noupdate /testbench/dut/u_softmax/features_out/ready
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
WaveRestoreZoom {0 ns} {1 us}
