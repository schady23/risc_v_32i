.DEFAULT_GOAL := help
QUARTUS_SH ?= quartus_sh
QUARTUS_STA ?= quartus_sta
PYTHON ?= python3
CABLE ?= USB-Blaster

.PHONY: help test project build timing program software image

help:
	@echo "make test      Run the seven active GHDL testbenches"
	@echo "make project   Generate the DE10-Lite Quartus project"
	@echo "make build     Compile the CPU system and check timing"
	@echo "make timing    Recheck timing for an existing compilation"
	@echo "make program   Configure the board with the existing .sof"
	@echo "make image     Build software and regenerate the ROM package"

test:
	bash scripts/simulate.sh

project:
	$(QUARTUS_SH) -t scripts/create_project.tcl

build:
	$(QUARTUS_SH) -t scripts/build.tcl

timing:
	$(QUARTUS_STA) -t scripts/check_timing.tcl

program:
	$(QUARTUS_SH) -t scripts/program.tcl "$(CABLE)"

software:
	$(MAKE) -C software

image: software
	$(PYTHON) scripts/elf_to_vhdl.py software/build/smoke.bin rtl/memory/program_image_pkg.vhd
