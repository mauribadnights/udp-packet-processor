# Makefile for Verilator Simulation
#
# Usage:
#   make        - Compiles the simulation executable
#   make run    - Compiles and runs the simulation
#   make clean  - Removes all generated files

VERILATOR = verilator
WAVE_VIEWER = surfer

RTL_DIR = rtl
SIM_DIR = sim

VERILOG_FILES = \
	$(RTL_DIR)/eth_parser.v \
	$(RTL_DIR)/ip_parser.v \
	$(RTL_DIR)/top_module.v
	
TOP_MODULE = top_module
CPP_SOURCES = $(SIM_DIR)/testbench.cpp
SIM_EXEC = V$(TOP_MODULE)

VERILATOR_FLAGS = --cc --exe --build -j 0 -I./rtl

.PHONY: all run clean

all: obj_dir/$(SIM_EXEC)

run: all
	@echo "Running simulation..."
	./obj_dir/$(SIM_EXEC)
	$(WAVE_VIEWER) waveform.vcd
	

clean:
	@echo "Cleaning up..."
	rm -rf obj_dir

obj_dir/$(SIM_EXEC): $(VERILOG_FILES) $(CPP_SOURCES)
	@echo "--- Verilating and Compiling ---"
	verilator --trace --cc --exe --build -j 0 -I./rtl --top-module $(TOP_MODULE) $(VERILOG_FILES) $(CPP_SOURCES)