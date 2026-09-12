SIM_DIR = sim
HDL_DIR = hdl
TB = $(SIM_DIR)/tb_project_rise.v
RTL = $(HDL_DIR)/project_rise_core.v
OUT = sim.vvp

all: test

compile:
	iverilog -o $(OUT) $(TB) $(RTL)

test: compile
	vvp $(OUT)

clean:
	rm -f $(OUT) wave.vcd
