# ------------------------------------------------------------------------------
# Generic Makefile for SystemVerilog Verification
# ------------------------------------------------------------------------------

# Select simulator tool choice (Options: modelsim, vcs, verilator)
# You can override this from the command line: make SIM=vcs
SIM ?= modelsim

# List of test cases to execute in regression
TOPS = axi_basic_test axi_random_test axi_error_test

# Design and Verification Source Files
SRC = \
    apb_if.sv \
    axi_lite_if.sv \
    apb_slave_regs.sv \
    axi_lite_trans.sv \
    axi_lite_driver.sv \
    axi_lite_monitor.sv \
    axi_lite_scoreboard.sv \
    axi_lite_coverage.sv \
    axi_lite_to_apb_bridge.sv \
    axi_env_tb.sv \
    axi_basic_test.sv \
    axi_random_test.sv \
    axi_error_test.sv

# ------------------------------------------------------------------------------
# Simulator Tool Configurations
# ------------------------------------------------------------------------------

ifeq ($(SIM), modelsim)
    COMPILE_CMD = vlib work && vmap work work && vlog
    SIM_CMD     = vsim -c
    SIM_ARGS    = -do "run -all; quit"
    GREP_ERRORS = '^\# \*\* (Error|Fatal):|^\# Errors: [1-9]'
else ifeq ($(SIM), vcs)
    COMPILE_CMD = vcs -sverilog +v2k -timescale=1ns/1ps
    SIM_CMD     = ./simv
    SIM_ARGS    = +vcs+finish+maxfail+1
    GREP_ERRORS = 'Error|Fatal'
else ifeq ($(SIM), verilator)
    COMPILE_CMD = verilator --binary -cc
    SIM_CMD     = ./obj_dir/V
    SIM_ARGS    = 
    GREP_ERRORS = '%Error|%Fatal'
else
    $(error Unknown simulator selection: $(SIM))
endif

# ------------------------------------------------------------------------------
# Build Targets
# ------------------------------------------------------------------------------

.PHONY: all compile run clean

all: clean compile run

compile:
	@echo "Compiling sources using $(SIM)..."
	$(COMPILE_CMD) $(SRC)

run:
	@mkdir -p logs
	@fail=0; \
	for t in $(TOPS); do \
		echo "Running test: $$t..."; \
		if [ "$(SIM)" = "modelsim" ]; then \
			$(SIM_CMD) $$t $(SIM_ARGS) > logs/$$t.log 2>&1; \
		else \
			$(SIM_CMD) +TESTNAME=$$t $(SIM_ARGS) > logs/$$t.log 2>&1; \
		fi; \
		if grep -Eq $(GREP_ERRORS) logs/$$t.log; then \
			echo "   => $$t FAILED"; \
			fail=1; \
		else \
			echo "   => $$t PASSED"; \
		fi; \
	done; \
	exit $$fail

clean:
	@echo "Cleaning up build artifacts..."
	@rm -rf work vsim.wlf transcript *.log logs/ obj_dir/ simv* csrc/
