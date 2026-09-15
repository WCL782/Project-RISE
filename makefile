# ==============================================================================
# Project-RISE Automation Makefile (CI/CD Aligned)
# ==============================================================================

# Toolchain Definitions
VERILATOR = verilator
YOSYS     = yosys
IVERILOG  = iverilog
VVP       = vvp
CXX       = g++
CXXFLAGS  = -Wall -Wextra -std=c++17 -Ihal

# Directory Structure
HDL_DIR   = hdl
SIM_DIR   = sim
HAL_DIR   = hal
BUILD_DIR = build

# Source Files
RTL_SRC   = $(HDL_DIR)/project_rise_core.v
TB_SRC    = $(SIM_DIR)/tb_project_rise_core.v
HAL_SRC   = $(HAL_DIR)/hardware_hal_v3.cpp

# Target Executables and Artifacts
SIM_BIN   = $(BUILD_DIR)/sim.vvp
HAL_BIN   = $(BUILD_DIR)/hal_driver_test
LOG_OUT   = $(BUILD_DIR)/synth_report.log

.PHONY: all sim lint synth hal clean help

# Default Target (Build & Run Complete Verification Pipeline)
all: lint synth sim hal

# 1. Verilator Static Analysis & Strict Lint Check
lint:
	@mkdir -p $(BUILD_DIR)
	@echo "===> Running Verilator Static Analysis & Lint..."
	$(VERILATOR) +1800-2012ext+v -DSIMULATION -y $(HDL_DIR) --lint-only -Wall -Wno-fatal -Wno-UNOPTFLAT -Wno-STYLE -Wno-DECLFILENAME $(RTL_SRC)

# 2. Yosys Open Hardware Synthesizability Check
synth:
	@mkdir -p $(BUILD_DIR)
	@echo "===> Running Yosys Hardware Synthesis Verification..."
	$(YOSYS) -p "read_verilog -sv $(RTL_SRC); synth_ice40 -top project_rise_core" > $(LOG_OUT) 2>&1
	@echo "===> Synthesis complete. Report generated at $(LOG_OUT)"

# 3. RTL Behavioral Simulation (Icarus Verilog + VVP)
sim: $(SIM_BIN)
	@echo "===> Running Behavioral Waveform Simulation..."
	$(VVP) $(SIM_BIN)

$(SIM_BIN): $(RTL_SRC) $(TB_SRC)
	@mkdir -p $(BUILD_DIR)
	@echo "===> Compiling RTL Core and Testbench..."
	$(IVERILOG) -DSIMULATION -I $(HDL_DIR) -g2012 -o $(SIM_BIN) $(RTL_SRC) $(TB_SRC)

# 4. C++ Hardware Abstraction Layer (HAL) Verification
hal: $(HAL_BIN)
	@echo "===> Executing C++ HAL Driver Verification..."
	./$(HAL_BIN)

$(HAL_BIN): $(HAL_SRC)
	@mkdir -p $(BUILD_DIR)
	@echo "===> Compiling C++ HAL Test Suite..."
	$(CXX) $(CXXFLAGS) $(HAL_SRC) -o $(HAL_BIN)

# 5. Clean Build Directory and Generated Artifacts
clean:
	@echo "===> Cleaning Build Artifacts..."
	rm -rf $(BUILD_DIR) wave.vcd
	@echo "Clean completed."

# Help Menu
help:
	@echo "Project-RISE Automation Commands:"
	@echo "  make lint   - Run Verilator static analysis & lint"
	@echo "  make synth  - Run Yosys hardware synthesis check"
	@echo "  make sim    - Compile & execute Icarus Verilog RTL simulation"
	@echo "  make hal    - Build and test C++ HAL driver"
	@echo "  make all    - Execute full verification pipeline (lint -> synth -> sim -> hal)"
	@echo "  make clean  - Remove build output folder"
