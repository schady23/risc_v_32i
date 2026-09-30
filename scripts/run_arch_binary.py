#!/usr/bin/env python3
"""Run an RV32I flat ROM binary with the local RAM completion convention."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--max-cycles', type=int, default=100000)
    args = parser.parse_args()
    data = args.binary.read_bytes()
    if not data or len(data) > 16384 or args.max_cycles < 1:
        parser.error('binary must contain 1..16384 bytes and max-cycles must be positive')
    data += bytes((-len(data)) % 4)
    output = ROOT / 'build' / 'arch-test' / 'image.hex'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(''.join(f'{int.from_bytes(data[i:i+4], "little"):08X}\n' for i in range(0,len(data),4)))
    subprocess.run([os.environ.get('GHDL','ghdl'), '--elab-run', '--std=08',
        '--workdir=build/ghdl','tb_arch_program', f'-gIMAGE_FILE={output}',
        f'-gMAX_CYCLES={args.max_cycles}', '--assert-level=error'], cwd=ROOT, check=True, timeout=30)

if __name__ == '__main__':
    main()
