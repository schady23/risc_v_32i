#!/usr/bin/env python3
"""Generate independent directed instruction/retirement vectors and run GHDL.

No RTL decoder or ALU is used to produce the expected values. Images stay in
build/ and do not replace the board ROM. Requires a preceding make test.
"""
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build' / 'execution'
BUILD.mkdir(parents=True, exist_ok=True)
GHDL = os.environ.get('GHDL', 'ghdl')
MASK = 0xffffffff

def imm(op, rd, f3, rs, value):
    return ((value & 4095) << 20) | (rs << 15) | (f3 << 12) | (rd << 7) | op

def store(f3, rs, value):
    return ((value & 0xfe0) << 20) | (rs << 20) | (1 << 15) | (f3 << 12) | ((value & 31) << 7) | 0x23

def branch(f3, a, b, offset):
    v = offset & 8191
    return ((v >> 12) << 31) | (((v >> 5) & 63) << 25) | (b << 20) | (a << 15) | (f3 << 12) | (((v >> 1) & 15) << 8) | (((v >> 11) & 1) << 7) | 0x63

class Program:
    def __init__(self):
        self.words, self.trace = [], []
        self.requests = 0
    def emit(self, word, rd=0, result=0, retires=True):
        pc = len(self.words) * 4
        self.words.append(word)
        if retires:
            self.trace.append(f'{pc:08X} {word:08X} {int(rd != 0)} {rd} {result & MASK:08X}\n')
        return pc
    def li(self, rd, value):
        value &= MASK
        upper = ((value + 0x800) >> 12) & 0xfffff
        self.emit((upper << 12) | (rd << 7) | 0x37, rd, upper << 12)
        self.emit(imm(0x13, rd, 0, rd, value), rd, value)
    def finish(self, name, cause=3, tval=0, terminal=0x00100073):
        pc = self.emit(terminal, retires=False)
        self.run(name, cause, pc, tval)
    def run(self, name, cause, pc, tval):
        image, trace = BUILD / (name+'.hex'), BUILD / (name+'.trace')
        image.write_text(''.join(f'{w:08X}\n' for w in self.words))
        trace.write_text(''.join(self.trace))
        subprocess.run([GHDL, '--elab-run', '--std=08', '--workdir=build/ghdl', 'tb_program',
            f'-gIMAGE_FILE={image}', f'-gTRACE_FILE={trace}', f'-gEXPECT_CAUSE={cause}',
            f'-gEXPECT_PC={pc}', f'-gEXPECT_TVAL={tval}', f'-gEXPECT_REQUESTS={self.requests}',
            '--assert-level=error'], cwd=ROOT, check=True, timeout=30)

p = Program()
p.li(1, 0x10000)
p.li(2, 0x80ff7f01)
p.emit(store(2,2,0)); p.requests += 1
# All four byte lanes, both halfword lanes, and sign/zero extension.
for offset, signed, unsigned in [(0,1,1),(1,127,127),(2,-1,255),(3,-128,128)]:
    for f3, value in [(0,signed),(4,unsigned)]:
        p.emit(imm(3,3,f3,1,offset),3,value); p.requests += 1
for offset, signed, unsigned in [(0,0x7f01,0x7f01),(2,-32513,0x80ff)]:
    for f3,value in [(1,signed),(5,unsigned)]:
        p.emit(imm(3,3,f3,1,offset),3,value); p.requests += 1
p.emit(imm(3,3,2,1,0),3,0x80ff7f01); p.requests += 1
# Byte and halfword stores must preserve every unselected lane.
word = 0x80ff7f01
p.li(2,0xa5)
for lane in range(4):
    p.emit(store(0,2,lane)); p.requests += 1
    word = (word & ~(255 << (lane*8))) | (0xa5 << (lane*8))
    p.emit(imm(3,3,2,1,0),3,word); p.requests += 1
p.li(2,0x8123)
for lane in [0,2]:
    p.emit(store(1,2,lane)); p.requests += 1
    word = (word & ~(65535 << (lane*8))) | (0x8123 << (lane*8))
    p.emit(imm(3,3,2,1,0),3,word); p.requests += 1
p.emit(imm(3,0,2,1,0)); p.requests += 1 # valid load to x0 still accesses memory
p.emit(imm(0x13,0,0,0,123))
p.emit(imm(0x13,3,0,0,0),3,0) # x0 write ignored
p.finish('lanes')

p = Program()
# Fixed expected boundary results for all ten ALU operations and all shifts.
for a,b in [(0xffffffff,1),(0x80000000,31),(0x7fffffff,0xffffffff),(0x12345678,32),(0x80000000,0)]:
    p.li(1,a); p.li(2,b)
    sa = a if a < 0x80000000 else a - 0x100000000
    sb = b if b < 0x80000000 else b - 0x100000000
    for f3,f7,value in [(0,0,a+b),(0,32,a-b),(1,0,a << (b&31)),(2,0,int(sa<sb)),
        (3,0,int(a<b)),(4,0,a^b),(5,0,a>>(b&31)),(5,32,sa>>(b&31)),(6,0,a|b),(7,0,a&b)]:
        p.emit((f7<<25)|(2<<20)|(1<<15)|(f3<<12)|(3<<7)|0x33,3,value)
for shift in [0,1,31]:
    for f3,upper,value in [(1,0,0x80000001<<shift),(5,0,0x80000001>>shift),(5,0x400,-2147483647>>shift)]:
        p.li(1,0x80000001)
        p.emit(imm(0x13,3,f3,1,upper|shift),3,value)
p.emit(0x0000000f) # FENCE no write
pc=len(p.words)*4
p.emit(0x00001197,3,pc+4096) # AUIPC
p.finish('alu_boundaries')

p = Program()
for f3,a,b,taken in [(0,5,5,True),(0,5,6,False),(1,5,6,True),(1,5,5,False),
    (4,0xffffffff,1,True),(4,1,0xffffffff,False),(5,1,0xffffffff,True),(5,0xffffffff,1,False),
    (6,1,0xffffffff,True),(6,0xffffffff,1,False),(7,0xffffffff,1,True),(7,1,0xffffffff,False)]:
    p.li(1,a); p.li(2,b)
    p.emit(branch(f3,1,2,8 if taken else 2)) # unused misaligned targets must not trap
    p.emit(imm(0x13,3,0,0,99),3,99,retires=not taken)
# JALR clears bit zero, writes link, and skips an instruction.
target=(len(p.words)+2)*4+8
p.li(1,target|1)
pc=len(p.words)*4
p.emit(imm(0x67,4,0,1,0),4,pc+4)
p.emit(imm(0x13,3,0,0,77),retires=False)
p.finish('branches_jalr')

for kind,f3,offset in [('load',1,1),('load',5,3),('load',2,2),('store',1,3),('store',2,2)]:
    p=Program(); p.li(1,0x10000)
    terminal=imm(3,3,f3,1,offset) if kind=='load' else store(f3,2,offset)
    p.finish(f'misaligned_{kind}_{f3}_{offset}',4 if kind=='load' else 6,0x10000+offset,terminal)
for name,address,f3,write in [('load_x0_fault',0x20000,2,False),('rom_store',0,2,True),
    ('uart_byte',0x40000008,0,False),('uart_half',0x40000008,1,False),('readonly_store',0x40000004,2,True)]:
    p=Program(); p.li(1,address); p.requests=1
    terminal=store(f3,2,0) if write else imm(3,0,f3,1,0)
    p.finish(name,7 if write else 5,address,terminal)
# Mixed loop: sum 1..5 in RAM, store each intermediate sum, then check all
# five final words through loads. Expected values are fixed independent values.
p = Program()
p.li(1, 0x10000)
p.emit(imm(0x13,2,0,0,1),2,1)  # counter
p.emit(imm(0x13,3,0,0,6),3,6)  # exclusive limit
p.emit(imm(0x13,4,0,0,0),4,0)  # sum
p.emit(imm(0x13,5,0,1,0),5,0x10000)  # output pointer
loop_pc = len(p.words)*4
loop_words = [
    (2<<20)|(4<<15)|(4<<7)|0x33,                # ADD x4,x4,x2
    (4<<20)|(5<<15)|(2<<12)|0x23,              # SW x4,0(x5)
    imm(3,6,2,5,0),                            # LW x6,0(x5)
    imm(0x13,5,0,5,4),                         # ADDI x5,x5,4
    imm(0x13,2,0,2,1),                         # ADDI x2,x2,1
    branch(1,2,3,-20),                         # BNE x2,x3,loop
]
p.words.extend(loop_words)
for iteration,total in enumerate([1,3,6,10,15],1):
    values = [(4,total),(0,0),(6,total),(5,0x10000+4*iteration),
              (2,iteration+1),(0,0)]
    for index,(dest,value) in enumerate(values):
        p.trace.append(f'{loop_pc+4*index:08X} {loop_words[index]:08X} '
                       f'{int(dest != 0)} {dest} {value:08X}\n')
    p.requests += 2
for offset,total in enumerate([1,3,6,10,15]):
    p.emit(imm(3,7,2,1,4*offset),7,total)
    p.requests += 1
p.finish('mixed_ram_loop')
print('Directed execution suite passed: 14 programs')
