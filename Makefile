SHELL := /bin/bash

TOP          := moesi_tb_top
BUILD_DIR    := build
RTL_DIR      := rtl
VERIF_DIR    := verification

VERILATOR    := verilator
VFLAGS       := -Wall --sv --timing --cc --exe -O2 \
                --top-module $(TOP) \
                -I$(RTL_DIR) -I$(VERIF_DIR)

UVM_FLAGS    := +define+UVM_NO_DEPRECATED \
                +define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR \
                +incdir+$(VERIF_DIR)

RTLSRCS      := $(wildcard $(RTL_DIR)/*.sv)
VERIFSRCS    := $(wildcard $(VERIF_DIR)/*.sv)

TB_SRCS      := $(VERIFSRCS) $(RTLSRCS)

.PHONY: compile run_test coverage clean

compile:
	@mkdir -p $(BUILD_DIR)
	$(VERILATOR) $(VFLAGS) $(UVM_FLAGS) \
		--Mdir $(BUILD_DIR) \
		$(TB_SRCS)
	$(MAKE) -C $(BUILD_DIR) -f V$(TOP).mk

run_test: compile
	@./$(BUILD_DIR)/V$(TOP) +UVM_TESTNAME=$(TEST)

coverage: compile
	@./$(BUILD_DIR)/V$(TOP) +UVM_TESTNAME=$(TEST) \
		+UVM_COVERAGE
	@echo "Coverage run complete (check Verilator coverage output if enabled)."

clean:
	@rm -rf $(BUILD_DIR) *.vcd *.log *.dmp
