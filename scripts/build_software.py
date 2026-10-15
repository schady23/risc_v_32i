#!/usr/bin/env python3
"""Build the JTAG ROM loader using bare-metal GCC (works on Windows too)."""
import argparse
import os
from pathlib import Path
import subprocess
from elf_to_vhdl import render_package

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prefix', default=os.environ.get('RISCV_PREFIX', 'riscv64-unknown-elf-'),
                        help='tool prefix, optionally including its directory')
    args = parser.parse_args()
    build = ROOT / 'software' / 'build'
    build.mkdir(parents=True, exist_ok=True)
    flags = ['-march=rv32i', '-mabi=ilp32', '-mcmodel=medany', '-nostdlib',
             '-nostartfiles', '-ffreestanding', '-ffunction-sections', '-fdata-sections',
             '-Os', '-msmall-data-limit=0', '-fno-builtin', '-fstack-usage']
    for name, extension in [('startup', 'S'), ('loader', 'c')]:
        subprocess.run([args.prefix + 'gcc', *flags, '-c', f'software/{name}.{extension}',
                        '-o', str(build / (name + '.o'))], cwd=ROOT, check=True)
    elf = build / 'loader.elf'
    subprocess.run([args.prefix + 'gcc', *flags, '-T', 'software/linker.ld',
                    '-Wl,--gc-sections,--no-relax,--build-id=none,-Map,' + str(build / 'loader.map'),
                    str(build / 'startup.o'), str(build / 'loader.o'), '-o', str(elf)],
                   cwd=ROOT, check=True)
    binary = build / 'loader.bin'
    subprocess.run([args.prefix + 'objcopy', '-O', 'binary', str(elf), str(binary)], check=True)
    with (build / 'loader.dump').open('w') as dump:
        subprocess.run([args.prefix + 'objdump', '-d', '-M', 'no-aliases', str(elf)],
                       stdout=dump, check=True)
    output = ROOT / 'rtl/memory/program_image_pkg.vhd'
    output.write_text(render_package(binary.read_bytes()), encoding='ascii')
    print(f'Built {len(binary.read_bytes())}-byte JTAG loader: {output}')


if __name__ == '__main__':
    main()
