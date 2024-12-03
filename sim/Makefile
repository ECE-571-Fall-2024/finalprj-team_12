 
QUESTA_HOME = /pkgs/mentor/questa/2024.2/questasim

HW   = ../rtl
SW   = ../cpp

VLIB = $(QUESTA_HOME)/bin/vlib
VMAP = $(QUESTA_HOME)/bin/vmap
#VLOG = $(QUESTA_HOME)/bin/vlog +acc=all -work work
VLOG = $(QUESTA_HOME)/bin/vlog +acc -work work
VSIM = $(QUESTA_HOME)/bin/vsim -voptargs=+acc -work work -sv_lib softmax
#VSIM = $(QUESTA_HOME)/bin/vsim -debugdb -work work -sv_lib softmax
#VSIM = $(QUESTA_HOME)/bin/vsim +acc -debugdb -work work -sv_lib softmax

.PHONY: all compile sim gui clean

all:
	@echo " "
	@echo " make targets are: "
	@echo "   - clean   = remove created files and cruft "
	@echo "   - compile = analyze all input hdl files "
	@echo "   - sim     = run simulation in Questa (command line) "
	@echo "   - gui     = run simulation in Questa with GUI "
	@echo "   - fail    = run simulation with induced failure "
	@echo " "

gui: compile
	$(VSIM) testbench -do gui_run.do

sim: compile
	$(VSIM) -c testbench -do sim_run.do

fail: compile
	$(VSIM) -c testbench -do sim_run.do -g INDUCE_FAILURE=1

compile: clean softmax.so
	rm -rf ./work

	$(VLIB) ./work
	$(VMAP) work ./work

	$(VLOG) $(HW)/mnist_pkg.sv
	$(VLOG) $(HW)/interface.sv
	$(VLOG) $(HW)/convolution.sv
	$(VLOG) $(HW)/dense.sv
	$(VLOG) $(HW)/max_pool.sv
	$(VLOG) $(HW)/softmax.sv
	$(VLOG) $(HW)/mnist.sv
	$(VLOG) $(HW)/testbench.sv

softmax.so: $(SW)/softmax.c
	gcc -m64 -fPIC -shared -o softmax.so $(SW)/softmax.c -I $(QUESTA_HOME)/include

CRUFT  = transcript
CRUFT += *.wlf
CRUFT += work
CRUFT += modelsim.ini
CRUFT += softmax.so

clean:
	rm -rf $(CRUFT)
