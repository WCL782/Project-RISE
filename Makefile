# =========================================================================
# Project-RISE Automation Makefile v4 (2-Space Standard)
# Architect: Chali Wang
# License: MIT
# Description: Fully aligned with RTL v4 (Tamper Mesh, 8-CH TRNG, Lockdown)
# =========================================================================

# Tool Chain Configuration
IVERILOG  = iverilog
VVP       = vvp
VERILATOR = verilator
YOSYS     = yosys
CXX       = g++
CXXFLAGS  = -Wall -Wextra -Werror -std=c++17

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
WAVE_OUT  = wave.vcd
LOG_OUT   = $(BUILD_DIR)/synth_report.log

.PHONY: all sim lint synth hal clean help

# Default Target (Build & Run Complete Test Pipeline)
all: lint sim hal

# 1. RTL Simulation (Icarus Verilog SystemVerilog 2012 Mode)
sim: $(SIM_BIN)
  @echo "===> Running RTL Simulation with Icarus Verilog..."
  @$(VVP) $(SIM_BIN)

$(SIM_BIN): $(RTL_SRC) $(TB_SRC)
  @mkdir -p $(BUILD_DIR)
  @echo "===> Compiling RTL & Testbench (v4 Core)..."
  @$(IVERILOG) -g2012 -o $(SIM_BIN) $(RTL_SRC) $(TB_SRC)

# 2. Verilator Static Analysis & Lint Check (Strict Rules)
lint:
  @echo "===> Running Verilator Lint Analysis (RTL v4)..."
  @$(VERILATOR) --lint-only -Wall -Wno-fatal $(RTL_SRC)

# 3. Yosys Open Hardware Synthesis Check & Resource Analysis
synth:
  @mkdir -p $(BUILD_DIR)
  @echo "===> Running Yosys Hardware Synthesizability Check..."
  @$(YOSYS) -p "read_verilog -sv $(RTL_SRC); synth_ice40 -top project_rise_core" > $(LOG_OUT)
  @grep -A 15 "Printing statistics" $(LOG_OUT) || cat $(LOG_OUT)

# 4. Compile & Execute C++ HAL Driver Verification
hal: $(HAL_BIN)
  @echo "===> Executing C++ HAL Driver Unit Tests..."
  @./$(HAL_BIN)

$(HAL_BIN): $(HAL_SRC)
  @mkdir -p $(BUILD_DIR)
  @echo "===> Compiling C++ HAL Driver (v3/v4 Abstraction)..."
  @$(CXX) $(CXXFLAGS) $(HAL_SRC) -o $(HAL_BIN)

# 5. Clean Build Directory and Generated Waveforms
clean:
  @echo "===> Cleaning Build Artifacts..."
  @rm -rf $(BUILD_DIR) $(WAVE_OUT)
  @echo "Clean completed."

# Help Menu
help:
  @echo "Project-RISE Automation Commands:"
  @echo "  make sim    - Compile & execute RTL v4 self-checking simulation"
  @echo "  make lint   - Run Verilator static analysis on RTL v4 core"
  @echo "  make synth  - Run Yosys synthesis check for ice40 FPGA"
  @echo "  make hal    - Build and test C++ HAL driver"
  @echo "  make clean  - Remove output files, logs, and VCD waveforms"
