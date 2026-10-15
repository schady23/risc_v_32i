#!/usr/bin/env python3
"""Build an RV32I assembly/C application for the ROM loader's 12 KiB RAM area."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FLAGS = ['-march=rv32i', '-mabi=ilp32', '-mcmodel=medany', '-msmall-data-limit=0',
         '-Os', '-nostdlib', '-nostartfiles', '-ffreestanding', '-fno-builtin',
         '-ffunction-sections', '-fdata-sections', '-fstack-usage']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--prefix', default=os.environ.get('RISCV_PREFIX', 'riscv64-unknown-elf-'))
    parser.add_argument('--output', type=Path, help='output prefix, defaults to software/build/<source stem>')
    parser.add_argument('--test-image', type=Path, help='also write a padded hex image for GHDL')
    args = parser.parse_args()
    output = (args.output or ROOT / 'software/build' / args.source.stem).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    objects = []
    for source, name in [(ROOT / 'software/app_startup.S', 'entry'), (args.source.resolve(), 'main')]:
        obj = output.with_name(output.name + '_' + name + '.o')
        subprocess.run([args.prefix+'gcc', *FLAGS, '-c', str(source), '-o', str(obj)], check=True)
        objects.append(str(obj))
    elf = output.with_suffix('.elf')
    subprocess.run([args.prefix+'gcc', *FLAGS, '-T', str(ROOT/'software/app.ld'),
                    '-Wl,--gc-sections,--no-relax,--build-id=none', *objects, '-o', str(elf)], check=True)
    binary = output.with_suffix('.bin')
    subprocess.run([args.prefix+'objcopy', '-O', 'binary', str(elf), str(binary)], check=True)
    if args.test_image:
        data = binary.read_bytes()
        data += bytes((-len(data)) % 4)
        args.test_image.parent.mkdir(parents=True, exist_ok=True)
        args.test_image.write_text(''.join(f'{int.from_bytes(data[i:i+4], "little"):08X}\n'
                                          for i in range(0, len(data), 4)), encoding='ascii')
    with output.with_suffix('.dump').open('w') as dump:
        subprocess.run([args.prefix+'objdump', '-d', '-M', 'no-aliases', str(elf)], stdout=dump, check=True)
    print(f'Application: {binary} ({binary.stat().st_size} bytes, entry 0x10000)')


if __name__ == '__main__':
    main()
