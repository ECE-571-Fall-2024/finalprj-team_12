
# Set the path to QuestaSim installation
QUESTA_HOME = /pkgs/mentor/questa/2024.2/questasim

# QuestaSim commands
VLIB = $(QUESTA_HOME)/bin/vlib
VMAP = $(QUESTA_HOME)/bin/vmap
VLOG = $(QUESTA_HOME)/bin/vlog +acc
VSIM = $(QUESTA_HOME)/bin/vsim -voptargs=+acc

# Targets
.PHONY: all compile sim gui clean

# Default target
all: sim

# Compilation step
compile:
	$(VLIB) ./work
	$(VMAP) work ./work
	$(VLOG) -sv ../rtl/mnist_pkg.sv
	$(VLOG) -sv ../rtl/interface.sv
	$(VLOG) -sv dense.sv
	$(VLOG) -sv testbench.sv

# Simulation step
sim: compile
	$(VSIM) -c dense_tb -do "run -all; quit;" -l transcript

# GUI simulation step
gui: compile
	$(VSIM) dense_tb -do "run -all"

# Clean step
clean:
	rm -rf work transcript *.wlf transcript

