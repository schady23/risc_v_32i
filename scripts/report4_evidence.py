#!/usr/bin/env python3
"""Re-run Report 4 checks and save real GHDL traces and readable waveform plots.

Requires GHDL and Pillow. Set GHDL to a full executable path if needed.
The PNGs are rendered from VCD transitions, never from expected test vectors.
"""
from pathlib import Path
import os
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/progress_reports/evidence'


def run_log(args, name):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, timeout=120)
    (OUT / name).write_text('$ ' + ' '.join(map(str, args)) + '\n' +
                            result.stdout + result.stderr +
                            f'\nExit status: {result.returncode}\n', encoding='utf-8')
    result.check_returncode()
    print(name + ': passed')


def read_vcd(path, top):
    scope, names, traces = [], {}, {}
    now = 0
    for line in path.read_text().splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == '$scope':
            scope.append(parts[2])
        elif parts[0] == '$upscope':
            scope.pop()
        elif parts[0] == '$var' and scope == [top]:
            names[parts[3]] = parts[4].split('[')[0]
            traces[names[parts[3]]] = []
        elif line[0] == '#':
            now = int(line[1:]) / 1_000_000  # GHDL emits 1 fs units.
        elif line[0] in 'bB':
            value, code = parts[0][1:], parts[1]
            if code in names:
                traces[names[code]].append((now, value))
        elif line[0] in '01xXzZ' and line[1:] in names:
            traces[names[line[1:]]].append((now, line[0]))
    return traces


def val(binary, mode):
    if any(c not in '01' for c in binary):
        return binary.upper()
    number = int(binary, 2)
    if isinstance(mode, list):
        return mode[number]
    if mode == 'hex':
        return f'{number:08X}'
    return str(number)


def font(size, bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/' + ('arialbd.ttf' if bold else 'arial.ttf'), size)


def panel(draw, traces, rows, start, end, y, title, markers=()):
    left, right, row_h = 275, 1930, 64
    draw.text((40, y), title, font=font(29, True), fill='#111111')
    y += 94
    top = y
    def x(t):
        return left + (t - start) * (right - left) / (end - start)
    for t in range(int(start), int(end) + 1, max(5, int((end-start)/14)//5*5)):
        draw.line((x(t), top-8, x(t), top + len(rows)*row_h), fill='#e1e5e8', width=1)
        draw.text((x(t), top-31), str(t), font=font(18), fill='#555555', anchor='mm')
    for i, (key, label, mode) in enumerate(rows):
        yy = top + i * row_h
        draw.text((40, yy+19), label, font=font(24), fill='#111111')
        draw.line((left, yy+57, right, yy+57), fill='#eeeeee')
        entries = traces[key]
        current = next((v for t, v in reversed(entries) if t <= start), 'U')
        points = [(start, current)] + [(t, v) for t, v in entries if start < t < end] + [(end, None)]
        for (a, v), (b, _) in zip(points, points[1:]):
            if mode == 'bit':
                height = yy + (10 if v == '1' else 43)
                draw.line((x(a), height, x(b), height), fill='#166a84', width=3)
                if b < end:
                    draw.line((x(b), yy+10, x(b), yy+43), fill='#166a84', width=2)
            else:
                xx1, xx2 = x(a), x(b)
                draw.line([(xx1, yy+27), (xx1+5, yy+7), (xx2-5, yy+7),
                           (xx2, yy+27), (xx2-5, yy+48), (xx1+5, yy+48),
                           (xx1, yy+27)], fill='#166a84', width=2)
                label_value = val(v, mode)
                if draw.textlength(label_value, font=font(22)) + 12 < xx2-xx1:
                    draw.text(((xx1+xx2)/2, yy+27), label_value, font=font(22),
                              fill='#143849', anchor='mm')
    bottom = top+len(rows)*row_h
    for t, label in markers:
        draw.line((x(t), top-7, x(t), bottom), fill='#b54b28', width=2)
        draw.text((x(t)+6, bottom+12), label, font=font(21, True), fill='#933b20')
    draw.text((right, top-32), 'ns', font=font(19), fill='#555555', anchor='lm')
    return bottom+65


def plots():
    decoder = read_vcd(OUT/'goal-2-decoder.vcd', 'tb_decoder_focused')
    image = Image.new('RGB', (2000, 976), 'white')
    draw = ImageDraw.Draw(image)
    draw.text((40, 20), 'Goal 2   Decoder simulation', font=font(37, True), fill='black')
    draw.text((40, 77), 'GHDL trace   |   10 ns per input   |   7 checked cases   |   buses in hexadecimal', font=font(25), fill='#444444')
    rows = [('case_index', 'Case', ['0', 'ADDI', 'LW', 'SW', 'BEQ', 'JAL', 'Illegal', 'NOP']),
            ('instruction', 'Instruction', 'hex'), ('immediate', 'Immediate', 'hex'),
            ('kind_code', 'Kind', ['ILLEGAL', 'ALU', 'LUI', 'AUIPC', 'JAL', 'JALR', 'BRANCH', 'LOAD', 'STORE', 'FENCE', 'ECALL', 'EBREAK']),
            ('legal', 'Legal', 'bit'), ('rd_write', 'Write intent', 'bit'),
            ('size_code', 'Memory size', ['BYTE', 'HALF', 'WORD']),
            ('lhs_code', 'ALU lhs', ['RS1', 'PC', 'ZERO']),
            ('wb_code', 'Writeback', ['ALU', 'MEMORY', 'PC + 4']),
            ('branch_code', 'Branch', ['NONE', 'EQ', 'NE', 'LT', 'GE', 'LTU', 'GEU'])]
    panel(draw, decoder, rows, 0, 70, 137, 'Sign extension, control selection, illegal rejection and recovery')
    draw.text((40, 922), 'Write intent for NOP is 1; the core separately blocks writes to x0. Memory size matters only for loads/stores.', font=font(23), fill='#444444')
    image.save(OUT/'goal-2-decoder-waveform.png')

    reset = read_vcd(OUT/'goal-3-reset.vcd', 'tb_core_reset')
    print('Reset transitions (ns):', reset['reset'])
    print('Accepted stores:', reset['accepted_stores'])
    image = Image.new('RGB', (2000, 1732), 'white')
    draw = ImageDraw.Draw(image)
    draw.text((40, 20), 'Goal 3   Reset at the memory request boundary', font=font(37, True), fill='black')
    draw.text((40, 78), 'Real core and RAM   |   10 ns clock   |   traces rendered from saved GHDL VCD', font=font(25), fill='#444444')
    rows = [('clk', 'Clock', 'bit'), ('reset', 'Reset', 'bit'),
            ('d_req', 'Data request', 'bit'), ('d_write', 'Store request', 'bit'),
            ('accepted_stores', 'Accepted stores', 'dec'), ('i_req', 'Fetch request', 'bit'),
            ('i_addr', 'Fetch address', 'hex'), ('retire_valid', 'Retire valid', 'bit'),
            ('retire_rd_we', 'Register write', 'bit')]
    assertions = [t for t,v in reset['reset'] if v == '1' and t > 0]
    a, b = assertions[:2]
    y = panel(draw, reset, rows, a-20, a+65, 140,
              'A   Reset before the store acceptance edge cancels the request',
              [(a, 'Reset asserted')])
    panel(draw, reset, rows, b-25, b+60, y+25,
          'B   Reset after acceptance preserves the committed store',
          [(b-5, 'Store accepted'), (b+5, 'Reset held')])
    draw.text((40, 1657), 'Accepted stores stays 0 in A and 1 in B. Fetch restarts at 00000000; writeback and retirement stay low during reset.', font=font(23), fill='#444444')
    image.save(OUT/'goal-3-reset-waveform.png')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    ghdl = os.environ.get('GHDL', 'ghdl')
    run_log([sys.executable, 'scripts/simulate.py'], 'report-4-regression.txt')
    for bench, stem in [('tb_decoder_focused', 'goal-2-decoder'), ('tb_core_reset', 'goal-3-reset')]:
        run_log([ghdl, '--elab-run', '--std=08', '--workdir=build/ghdl', bench,
                 '--assert-level=error', f'--wave={OUT/stem}.ghw',
                 f'--vcd={OUT/stem}.vcd'], stem+'-simulation.txt')
    run_log([sys.executable, 'scripts/test_jtag_console.py'], 'report-4-host-tests.txt')
    plots()


if __name__ == '__main__':
    plots() if '--plots-only' in sys.argv else main()
