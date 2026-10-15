.DEFAULT_GOAL := help
QUARTUS_SH ?= quartus_sh
QUARTUS_STA ?= quartus_sta
PYTHON ?= python3
CABLE ?= USB-Blaster

.PHONY: help test project build timing program software image app test-adapter

help:
	@echo "make test      Run CPU, JTAG loader, memory, and upload-client checks"
	@echo "make project   Generate the DE10-Lite Quartus project"
	@echo "make build     Compile the CPU system and check timing"
	@echo "make timing    Recheck timing for an existing compilation"
	@echo "make program   Configure the board with the existing .sof"
	@echo "make image     Build the ROM loader and regenerate its VHDL image"
	@echo "make app       Build the uploadable hello assembly example"

test:
	$(PYTHON) scripts/simulate.py
	$(PYTHON) scripts/test_jtag_console.py

project:
	$(QUARTUS_SH) -t scripts/create_project.tcl

build:
	$(QUARTUS_SH) -t scripts/build.tcl

timing:
	$(QUARTUS_STA) -t scripts/check_timing.tcl

program:
	$(QUARTUS_SH) -t scripts/program.tcl "$(CABLE)"

software:
	$(PYTHON) scripts/build_software.py

image: software

app:
	$(PYTHON) scripts/build_app.py software/hello.S --test-image sim/images/hello.hex

# Analyze benches first. Uses LLVM, or GNU tools when RISCV_PREFIX is exported.
test-adapter: test
	$(PYTHON) scripts/test_arch_adapter.py
