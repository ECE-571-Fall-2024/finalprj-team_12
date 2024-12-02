mem load -filldata 0 testbench.dut.u_convolution_1.images
mem load -filldata 0 testbench.dut.u_convolution_2.images
do wave.do
run 100 ms
