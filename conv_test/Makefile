 
QUESTA_HOME = /pkgs/mentor/questa/2024.2/questasim

HW   = ../rtl
SW   = ../cpp

VLIB = $(QUESTA_HOME)/bin/vlib
VMAP = $(QUESTA_HOME)/bin/vmap
VLOG = $(QUESTA_HOME)/bin/vlog +acc=all -work work
VSIM = $(QUESTA_HOME)/bin/vsim -voptargs=+acc -work work 

.PHONY: all compile sim gui clean

all:
	@echo " "
	@echo " make targets are: "
	@echo "   - clean   = remove created files and cruft "
	@echo "   - compile = analyze all input hdl files "
	@echo "   - sim     = run simulation in Questa (command line) "
	@echo "   - gui     = run simulation in Questa with GUI "
	@echo " "

gui: compile
	$(VSIM) testbench -do gui_run.do

sim: compile
	$(VSIM) -c testbench -do sim_run.do

compile: clean 
	rm -rf ./work

	$(VLIB) ./work
	$(VMAP) work ./work

	$(VLOG) $(HW)/mnist_pkg.sv
	$(VLOG) $(HW)/interface.sv
	$(VLOG) $(HW)/convolution.sv
	$(VLOG) ./testbench.sv

CRUFT  = transcript
CRUFT += *.wlf
CRUFT += work
CRUFT += modelsim.ini

clean:
	rm -rf $(CRUFT)
