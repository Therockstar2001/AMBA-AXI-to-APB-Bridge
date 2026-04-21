# -----------------------------
# Makefile for AXI Verification
# -----------------------------

VLOG = vlog
VSIM = vsim -c
TOPS = axi_basic_test axi_random_test axi_error_test

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

all: compile run

compile:
	vlib work
	vmap work work
	$(VLOG) $(SRC)

run:
	@mkdir -p logs
	@fail=0; \
	for t in $(TOPS); do \
		echo "Running $$t..."; \
		$(VSIM) $$t -do "run -all; quit" > logs/$$t.log; \
		if grep -Eq '^\# \*\* (Error|Fatal):|^\# Errors: [1-9]' logs/$$t.log; then \
			echo "$$t FAILED"; \
			fail=1; \
		else \
			echo "$$t PASSED"; \
		fi; \
	done; \
	if [ $$fail -eq 1 ]; then \
		echo "REGRESSION FAILED"; \
	else \
		echo "REGRESSION PASSED"; \
	fi

clean:
	rm -rf work transcript vsim.wlf logs
