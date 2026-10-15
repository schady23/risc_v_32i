#!/usr/bin/env python3
"""Portable GHDL runner. GHDL may be a path to ghdl.exe on Windows."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    ghdl = os.environ.get('GHDL', 'ghdl')
    (ROOT / 'build/ghdl').mkdir(parents=True, exist_ok=True)
    # Keep the same source order as the Quartus project.
    sources = [
        'rtl/pkg/rv32i_pkg.vhd', 'rtl/pkg/memory_map_pkg.vhd',
        'rtl/memory/program_image_pkg.vhd', 'rtl/core/rv32i_alu.vhd',
        'rtl/core/rv32i_regfile.vhd', 'rtl/core/rv32i_decoder.vhd',
        'rtl/core/rv32i_core.vhd', 'rtl/memory/instruction_rom.vhd',
        'rtl/memory/ram_byte_bank.vhd', 'rtl/memory/data_ram.vhd',
        'rtl/peripheral/jtag_uart_adapter.vhd', 'rtl/interconnect/memory_bus.vhd',
        'rtl/board/reset_synchronizer.vhd', 'rtl/board/rv32i_system.vhd',
        'sim/jtag_uart_sim_pkg.vhd', 'sim/jtag_uart_system.vhd',
        'rtl/board/de10_lite_top.vhd',
    ]
    benches = ['tb_alu', 'tb_decoder', 'tb_decoder_focused', 'tb_regfile',
               'tb_jtag_uart', 'tb_memory_bus', 'tb_de10_lite_top', 'tb_core',
               'tb_core_execution', 'tb_core_reset']
    sources += [f'sim/{name}.vhd' for name in benches + ['tb_arch_program', 'tb_program']]
    subprocess.run([ghdl, '-a', '--std=08', '--workdir=build/ghdl', *sources],
                   cwd=ROOT, check=True, timeout=60)
    for bench in benches:
        subprocess.run([ghdl, '--elab-run', '--std=08', '--workdir=build/ghdl',
                        bench, '--assert-level=error'], cwd=ROOT, check=True, timeout=30)
    subprocess.run([sys.executable, 'scripts/test_execution.py'], cwd=ROOT, check=True)


if __name__ == '__main__':
    main()
