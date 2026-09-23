#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

GHDL_BIN=${GHDL:-ghdl}
mkdir -p build/ghdl
sources=(
  rtl/pkg/rv32i_pkg.vhd
  rtl/pkg/memory_map_pkg.vhd
  rtl/memory/program_image_pkg.vhd
  rtl/core/rv32i_alu.vhd
  rtl/core/rv32i_regfile.vhd
  rtl/core/rv32i_decoder.vhd
  rtl/core/rv32i_core.vhd
  rtl/memory/instruction_rom.vhd
  rtl/memory/data_ram.vhd
  rtl/peripheral/gpio.vhd
  rtl/interconnect/memory_bus.vhd
  rtl/board/reset_synchronizer.vhd
  rtl/board/de10_lite_top.vhd
  sim/tb_alu.vhd
  sim/tb_decoder.vhd
  sim/tb_regfile.vhd
  sim/tb_memory_bus.vhd
  sim/tb_de10_lite_top.vhd
  sim/tb_core.vhd
  sim/tb_core_execution.vhd
)
"$GHDL_BIN" -a --std=08 --workdir=build/ghdl "${sources[@]}"
for tb in tb_alu tb_decoder tb_regfile tb_memory_bus tb_de10_lite_top tb_core tb_core_execution; do
  timeout 30s "$GHDL_BIN" --elab-run --std=08 --workdir=build/ghdl "$tb" \
    --assert-level=error
done
