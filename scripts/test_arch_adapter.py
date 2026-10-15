#!/usr/bin/env python3
"""Exercise pass, explicit fail, trap, and timeout paths of the local adapter."""
from pathlib import Path
import os
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
build = root / 'build' / 'arch-test'
build.mkdir(parents=True, exist_ok=True)
# Compile the tracked source to exercise the actual assembly/image path.
prefix = os.environ.get('RISCV_PREFIX')
if prefix:
    compiler = [prefix+'gcc', '-march=rv32i', '-mabi=ilp32', '-nostdlib', '-nostartfiles',
                '-Wl,--build-id=none,--no-relax', '-T', 'sim/arch-test/linker.ld']
    objcopy = prefix+'objcopy'
else:
    compiler = ['clang', '--target=riscv32-unknown-elf', '-march=rv32i', '-mabi=ilp32',
                '-nostdlib', '-fuse-ld=lld', '-Wl,-T,sim/arch-test/linker.ld']
    objcopy = 'llvm-objcopy'
subprocess.run([*compiler, 'sim/arch-test/adapter_selftest.S', '-o', str(build/'adapter.elf')],
               cwd=root, check=True)
subprocess.run([objcopy, '-O', 'binary', str(build/'adapter.elf'), str(build/'pass.bin')], check=True)
data=(build/'pass.bin').read_bytes()
fail=bytearray(data); fail[8:12]=(0x00200313).to_bytes(4,'little')
(build/'fail.bin').write_bytes(fail)
(build/'trap.bin').write_bytes((0x00100073).to_bytes(4,'little'))
(build/'timeout.bin').write_bytes((0x0000006f).to_bytes(4,'little'))
for name,message in [('pass','tb_arch_program passed'),('fail','program reported failure'),
                     ('trap','unexpected architectural trap'),('timeout','architectural program timeout')]:
    result=subprocess.run([sys.executable,'scripts/run_arch_binary.py',str(build/(name+'.bin')),
        '--max-cycles','200'],cwd=root,text=True,capture_output=True)
    assert (result.returncode==0)==(name=='pass'), (name,result.stdout,result.stderr)
    assert message in result.stdout, (name,result.stdout,result.stderr)
    print(f'Adapter {name} path checked')
print('Architectural adapter self-test passed (not upstream certification)')
