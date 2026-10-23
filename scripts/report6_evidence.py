#!/usr/bin/env python3
"""Save Report 6 assertions and plots from measured simulation traces.

Requires GHDL and Pillow. Set GHDL and RISCV_PREFIX for local tool paths.
Run after changing the Report 6 tests to refresh the archived evidence.
"""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
from PIL import Image, ImageDraw
from report4_evidence import read_vcd, panel, font

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/progress_reports/evidence'


def run(args, name, required=True):
    try:
        result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True,
                                timeout=120)
        transcript = result.stdout + result.stderr
        code = result.returncode
    except FileNotFoundError as exc:
        transcript, code = str(exc) + '\n', 127
    (OUT / name).write_text('$ ' + ' '.join(map(str, args)) + '\n' + transcript +
                            f'\nExit status: {code}\n', encoding='utf-8')
    if required and code:
        raise RuntimeError(f'{name} failed; see archived transcript')
    print(f'{name}: exit {code}')
    return code


def plots():
    traces = read_vcd(OUT/'report-6-reset.vcd', 'tb_core_reset_extended')
    resets = [t for t, v in traces['reset'] if t > 20 and v == '1']
    assert len(resets) == 4, resets
    im = Image.new('RGB', (2000, 1560), 'white')
    d = ImageDraw.Draw(im)
    d.text((40, 20), 'Reset during fetch and load responses', font=font(37, True), fill='black')
    d.text((40, 78), 'Actual GHDL VCD   |   10 ns clock   |   hexadecimal bus values', font=font(25), fill='#444444')
    rows = [('clk','Clock','bit'), ('reset','Reset','bit'), ('iq','Fetch request','bit'),
            ('ia','Fetch PC','hex'), ('dq','Data request','bit'),
            ('rv','Retire valid','bit'), ('rw','Register write','bit'),
            ('load_commits','Load commits','dec')]
    y = panel(d, traces, rows, resets[1]-20, resets[1]+68, 140,
              'A   Accepted instruction fetch is discarded by reset',
              [(resets[1], 'Reset asserted')])
    panel(d, traces, rows, resets[3]-20, resets[3]+68, y+20,
          'B   Accepted load response cannot write a register during reset',
          [(resets[3], 'Reset asserted')])
    d.text((40, 1504), 'All four cases also check restart at PC zero and x8 clearing. Full assertions and raw traces are archived.',
           font=font(23), fill='#444444')
    im.save(OUT/'report-6-reset-waveform.png')

    traces = read_vcd(OUT/'report-6-mixed.vcd', 'tb_program')
    def at(key, time):
        return int(next(v for t,v in reversed(traces[key]) if t <= time), 2)
    stores = []
    for t,v in traces['clk']:
        # Sample just before the rising acceptance edge (before delta changes).
        if v == '1' and t > 0 and at('dq',t-0.001) and at('dw',t-0.001):
            stores.append((t,at('da',t-0.001),at('wd',t-0.001)))
    assert [v for _,_,v in stores] == [1,3,6,10,15], stores
    assert [a for _,a,_ in stores] == list(range(0x10000,0x10014,4)), stores
    (OUT/'report-6-mixed-stores.json').write_text(json.dumps([
        {'time_ns':t,'address':f'{a:08X}','value':v} for t,a,v in stores],indent=2)+'\n')
    im = Image.new('RGB',(1800,650),'white'); d=ImageDraw.Draw(im)
    d.text((40,25),'Mixed RAM loop measured store results',font=font(36,True),fill='black')
    d.text((40,85),'Five loop iterations   |   41 checked retirements   |   15 data requests',font=font(25),fill='#444444')
    for x,label in [(60,'Iteration'),(310,'Time ns'),(610,'RAM address'),(1050,'Expected'),(1410,'Observed')]:
        d.text((x,165),label,font=font(27,True),fill='black')
    for index,(t,a,v) in enumerate(stores):
        y=225+index*64
        d.line((40,y-12,1750,y-12),fill='#d9d9d9',width=2)
        for x,label in [(60,str(index+1)),(310,f'{t:g}'),(610,f'0x{a:08X}'),
                        (1050,str([1,3,6,10,15][index])),(1410,str(v))]:
            d.text((x,y),label,font=font(29),fill='black')
    d.text((40,590),'All five final RAM words are read back and checked before the expected EBREAK trap.',font=font(24),fill='#444444')
    im.save(OUT/'report-6-mixed-results.png')


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    ghdl=os.environ.get('GHDL','ghdl')
    run([sys.executable,'scripts/simulate.py'],'report-6-regression.txt')
    run([ghdl,'--elab-run','--std=08','--workdir=build/ghdl',
         'tb_core_reset_extended','--assert-level=error',
         f'--wave={OUT}/report-6-reset.ghw',f'--vcd={OUT}/report-6-reset.vcd'],
        'report-6-reset-simulation.txt')
    run([ghdl,'--elab-run','--std=08','--workdir=build/ghdl','tb_program',
         f'-gIMAGE_FILE={ROOT}/build/execution/mixed_ram_loop.hex',
         f'-gTRACE_FILE={ROOT}/build/execution/mixed_ram_loop.trace',
         '-gEXPECT_CAUSE=3','-gEXPECT_PC=68','-gEXPECT_TVAL=0','-gEXPECT_REQUESTS=15',
         '--assert-level=error',f'--wave={OUT}/report-6-mixed.ghw',
         f'--vcd={OUT}/report-6-mixed.vcd'],'report-6-mixed-simulation.txt')
    for suffix in ['hex','trace']:
        shutil.copyfile(ROOT/f'build/execution/mixed_ram_loop.{suffix}',
                        OUT/f'report-6-mixed.{suffix}')
    run([sys.executable,'scripts/test_jtag_console.py'],'report-6-host-tests.txt')
    run([sys.executable,'scripts/test_arch_adapter.py'],'report-6-adapter.txt')
    # Capture an actual build-tool preflight failure when Quartus is unavailable.
    run(['quartus_sh','--version'],'report-6-quartus-preflight.txt',required=False)
    plots()


if __name__ == '__main__':
    plots() if '--plots-only' in sys.argv else main()
