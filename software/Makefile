PYTHON ?= python3
RISCV_PREFIX ?= riscv64-unknown-elf-
.PHONY: all app
all:
	$(PYTHON) ../scripts/build_software.py --prefix "$(RISCV_PREFIX)"
app:
	$(PYTHON) ../scripts/build_app.py hello.S --prefix "$(RISCV_PREFIX)" --test-image ../sim/images/hello.hex
	$(PYTHON) ../scripts/build_app.py mixed_ram.S --prefix "$(RISCV_PREFIX)" --test-image ../sim/images/mixed_ram.hex
