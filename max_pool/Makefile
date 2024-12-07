# Set the path to QuestaSim installation
QUESTA_HOME = /pkgs/mentor/questa/2024.2/questasim

# QuestaSim commands
VLIB = $(QUESTA_HOME)/bin/vlib
VMAP = $(QUESTA_HOME)/bin/vmap
VLOG = $(QUESTA_HOME)/bin/vlog +acc
VSIM = $(QUESTA_HOME)/bin/vsim -voptargs=+acc

# File names and directories
DESIGN    = max_pool.sv
TESTBENCH = max_pool_tb.sv
#RTL_DIR   = ../rtl  # Directory containing mnist_pkg.sv and other dependencies
TRANSCRIPT = max_pool_transcript

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
	$(VLOG) -sv $(DESIGN)
	$(VLOG) -sv $(TESTBENCH)

# Simulation step
sim: compile
	$(VSIM) -c max_pool_tb -do "run -all; quit;" -l $(TRANSCRIPT)

# GUI simulation step
gui: compile
	$(VSIM) max_pool_tb -do "run -all"

# Clean step
clean:
	rm -rf work transcript *.wlf $(TRANSCRIPT)

