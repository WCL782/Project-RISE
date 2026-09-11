VERILATOR = verilator
VERILATOR_FLAGS = -Wall --cc --trace --exe

# RTL 與 Testbench 源碼路徑
RTL_SRC = hdl/project_rise_core.v
TB_SRC = sim/tb_project_rise.cpp

all: test

test:
	@echo "Building Verilator Model..."
	$(VERILATOR) $(VERILATOR_FLAGS) $(RTL_SRC) $(TB_SRC) -Mdir obj_dir
	@echo "Compiling C++ Target..."
	make -C obj_dir -f Vproject_rise_core.mk Vproject_rise_core
	@echo "Executing High-Assurance Hardware Verification Suite..."
	./obj_dir/Vproject_rise_core

clean:
	rm -rf obj_dir

.PHONY: all test clean
