 
QUESTA_HOME = /pkgs/mentor/questa/2024.2/questasim


export MTI_VCO_MODE = 64

HW   = ../rtl
SW   = ../cpp

VLIB = $(QUESTA_HOME)/bin/vlib
VMAP = $(QUESTA_HOME)/bin/vmap
VLOG = $(QUESTA_HOME)/bin/vlog +acc=all +cover -work work
VSIM = $(QUESTA_HOME)/bin/vsim -voptargs=+acc -work work 

.PHONY: all compile sim gui clean

all:
	@echo " "
	@echo " make targets are: "
	@echo "   - clean   = remove created files and cruft "
	@echo "   - compile = analyze all input hdl files "
	@echo "   - sim     = run simulation in Questa (command line) "
	@echo "   - gui     = run simulation in Questa with GUI "
	@echo "   - fail    = run with INDUCE_FAILURE set, to show tests are effective "
	@echo "   - cover   = run with coverage, view coverage report "
	@echo " "

gui: compile
	$(VSIM) testbench -do gui_run.do

sim: compile
	$(VSIM) -c testbench -do sim_run.do
	@echo "All tests passed successfully!"

fail: compile
	$(VSIM) -c testbench -do sim_run.do -g INDUCE_FAILURE=1

gui_fail: compile
	$(VSIM) testbench -do gui_run.do -g INDUCE_FAILURE=1

compile: clean 
	rm -rf ./work

	$(VLIB) ./work
	$(VMAP) work ./work

	$(VLOG) $(HW)/mnist_pkg.sv
	$(VLOG) $(HW)/interface.sv
	$(VLOG) $(HW)/dense.sv
	$(VLOG) ./testbench.sv

CRUFT  = transcript
CRUFT += *.wlf
CRUFT += work
CRUFT += modelsim.ini

clean:
	rm -rf $(CRUFT)
