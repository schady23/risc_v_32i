#!/usr/bin/env python3
"""Build Report 7 from the retained Report 6 form, using python-docx and Pillow.

Run with the Codex document runtime. The final DOCX must also be rendered and
visually reviewed with the documents skill's render_docx.py before delivery.
"""
from copy import deepcopy
from datetime import date, datetime, timezone
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
import shutil
from zipfile import ZIP_DEFLATED, ZipFile

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'docs/progress_reports/evidence'
WORK = ROOT / 'build/report7'
REFERENCE = ROOT / 'docs/progress_reports/Progress Report 6 rschader.docx'
REFERENCE_SHA = 'ffe6792ab289fbaf0abd78e852b10105244599167ea3d08b6379b9a0990f5c25'
FINAL = ROOT / 'docs/progress_reports/Progress Report 7 rschader.docx'
MUTABLE = {'word/document.xml', 'word/_rels/document.xml.rels',
           '[Content_Types].xml', 'docProps/core.xml'}


def font(size, bold=False):
    liberation = Path('/usr/share/fonts/liberation') / ('LiberationSans-Bold.ttf' if bold else 'LiberationSans-Regular.ttf')
    if liberation.exists():
        return ImageFont.truetype(str(liberation), size)
    name = 'DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf'
    for directory in ['/usr/share/fonts/TTF', '/usr/share/fonts/truetype/dejavu']:
        path = Path(directory) / name
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.truetype(name, size)


def schedule():
    """Preserve the old chart and draw the dated actual/planned schedule."""
    shutil.copyfile(EVIDENCE / 'report-6-current-gantt.png',
                    EVIDENCE / 'report-7-previous-gantt.png')
    im = Image.new('RGB', (1840, 900), 'white')
    draw = ImageDraw.Draw(im)
    draw.text((22, 18), 'Updated project schedule  October 29 2026',
              font=font(35, True), fill='black')
    draw.text((22, 76), 'Green diamonds completed  |  Blue bars planned  |  Dates are planning targets',
              font=font(25), fill='#444444')
    start, finish = date(2026, 10, 8), date(2026, 12, 4)
    left, right, top, step = 590, 1780, 170, 68

    def x(value):
        return left + (value - start).days / (finish - start).days * (right - left)

    ticks = [(10, 8), (10, 15), (10, 23), (10, 29), (11, 6), (11, 12), (11, 19), (12, 4)]
    for month, day in ticks:
        current = date(2026, month, day)
        px = x(current)
        label = current.strftime('%b %d')
        draw.line((px, top - 20, px, top + 8 * step), fill='#c3d0dc', width=2)
        width = draw.textlength(label, font=font(24))
        draw.text((px - width / 2, 120), label, font=font(24), fill='black')
    rows = [
        ('CPU and reset verification', date(2026, 10, 23), None),
        ('Current JTAG build and timing', date(2026, 10, 29), None),
        ('Hello upload and board rerun', date(2026, 10, 29), None),
        ('Second uploaded assembly app', date(2026, 10, 29), None),
        ('G1 Hardware recovery checks', date(2026, 10, 30), date(2026, 11, 6)),
        ('G2 Tested illustrated user guide', date(2026, 10, 30), date(2026, 11, 6)),
        ('G3 Final report and demo draft', date(2026, 11, 2), date(2026, 11, 12)),
        ('Final report and demonstration', date(2026, 11, 24), date(2026, 12, 4)),
    ]
    for index, (label, actual_or_start, end) in enumerate(rows):
        y = top + index * step
        if index % 2 == 0:
            draw.rectangle((12, y - 9, 1792, y + 48), fill='#ecf3f8')
        draw.text((22, y + 1), label, font=font(28), fill='black')
        mid, px = y + 22, x(actual_or_start)
        if end is None:
            draw.polygon([(px, mid - 18), (px + 13, mid), (px, mid + 18), (px - 13, mid)],
                         fill='#258a72')
            draw.text((px + 22, y + 5), actual_or_start.strftime('%b %d'),
                      font=font(23), fill='#206f5e')
        else:
            draw.rectangle((px, mid - 15, x(end), mid + 15), fill='#458eb9')
    draw.text((22, 760), 'Build completed Oct 29 against Oct 26 target; hello and mixed app passed on the board Oct 29.',
              font=font(24), fill='#444444')
    draw.text((22, 805), 'Recovery evidence continues to Nov 6. Draft review is planned Nov 19; final window remains Nov 24 to Dec 4.',
              font=font(24), fill='#444444')
    im.save(EVIDENCE / 'report-7-current-gantt.png')


def replace_text(element, text):
    nodes = list(element.iter(qn('w:t')))
    assert nodes
    nodes[0].text = text
    for node in nodes[1:]:
        node.text = ''


def fill_box(element, text):
    boxes = list(element.iter(qn('w:txbxContent')))
    assert len(boxes) == 2, 'Preserve both DrawingML and VML answer boxes'
    for box in boxes:
        replace_text(box, text)


def fill_status(element, status):
    values = list(element.iter(qn('w:t')))
    boxes = [node for node in values if (node.text or '').strip() in {'☐', '☒'}]
    assert len(boxes) == 3
    for index, box in enumerate(boxes):
        box.text = '☒' if index == ['Complete', 'Partially Complete', 'No Progress'].index(status) else '☐'


def short_spacer(element):
    properties = element.find(qn('w:pPr'))
    spacing = properties.find(qn('w:spacing'))
    if spacing is None:
        spacing = OxmlElement('w:spacing')
        properties.append(spacing)
    for key, value in [('before', '0'), ('after', '0'), ('line', '20'), ('lineRule', 'exact')]:
        spacing.set(qn(f'w:{key}'), value)


def keep_next(element):
    properties = element.find(qn('w:pPr'))
    if properties is None:
        properties = OxmlElement('w:pPr')
        element.insert(0, properties)
    if properties.find(qn('w:keepNext')) is None:
        properties.append(OxmlElement('w:keepNext'))


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    assert sha256(REFERENCE.read_bytes()).hexdigest() == REFERENCE_SHA
    content = json.loads((EVIDENCE / 'report-7-content.json').read_text())
    with ZipFile(REFERENCE) as original:
        original_parts = {info.filename: original.read(info.filename) for info in original.infolist()}
        original_infos = original.infolist()
    (WORK / 'template-inventory.json').write_text(json.dumps({
        name: {'size': len(data), 'sha256': sha256(data).hexdigest(),
               'mutable': name in MUTABLE}
        for name, data in original_parts.items()
    }, indent=2) + '\n')

    sources = [
        (ROOT / 'output/pictures/IMG_6829.JPG', EVIDENCE / 'report-7-board-photo.jpg'),
        (ROOT / 'output/pictures/screenshot-2026-10-29_20-57-33.png', EVIDENCE / 'report-7-console.png'),
    ]
    for source, destination in sources:
        if source.exists():
            shutil.copyfile(source, destination)
        assert destination.exists(), f'Missing evidence: {destination}'
    schedule()

    working = WORK / 'report7-working.docx'
    shutil.copyfile(REFERENCE, working)
    document = Document(working)
    body = document._element.body
    elements = list(body)
    appendix_properties = deepcopy(elements[47].find(qn('w:pPr')))
    for node in elements[0].iter(qn('w:t')):
        if node.text == 'Progress Report 6':
            node.text = 'Progress Report 7'
    for (heading, answer, status), goal in zip([(10, 11, 12), (14, 15, 16), (19, 20, 21)],
                                              content['previous_goals']):
        replace_text(elements[heading], f'Goal #{content["previous_goals"].index(goal)+1}: {goal["title"]}')
        fill_box(elements[answer], goal['text'])
        fill_status(elements[status], goal['status'])
        keep_next(elements[heading])
        keep_next(elements[answer])
    for index, ((heading, answer), goal) in enumerate(zip([(30, 31), (33, 34), (36, 37)],
                                                         content['next_goals']), 1):
        replace_text(elements[heading], f'Goal #{index}: {goal["title"]}')
        fill_box(elements[answer], goal['text'])
        keep_next(elements[heading])
    # Recover the space that stranded Goal 2's status row in the retained form.
    for index in [7, 9]:
        short_spacer(elements[index])
    for element in elements[46:]:
        if element.tag != qn('w:sectPr'):
            body.remove(element)

    def paragraph(text='', size=11, bold=False, page=False, keep=False, mono=False):
        p = document.add_paragraph()
        p._p.insert(0, deepcopy(appendix_properties))
        p.paragraph_format.page_break_before = page
        p.paragraph_format.keep_with_next = keep
        p.paragraph_format.widow_control = True
        run = p.add_run(text)
        run.font.name = 'Courier New' if mono else 'Times New Roman'
        run.font.size, run.font.bold = Pt(size), bold
        run.font.color.rgb = RGBColor(0, 0, 0)
        return p

    def heading(text):
        return paragraph(text, size=14, bold=True, page=True, keep=True)

    def picture(path, caption, crop_width=None):
        p = document.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.keep_with_next = True
        im = Image.open(path)
        displayed_width = crop_width or im.width
        shape = p.add_run().add_picture(str(path), width=Inches(6.5),
                                       height=Inches(6.5 * im.height / displayed_width))
        shape._inline.docPr.set('descr', caption)
        if crop_width:
            fill = shape._inline.xpath('.//pic:blipFill')[0]
            crop = OxmlElement('a:srcRect')
            crop.set('r', str(round(100000 * (im.width - crop_width) / im.width)))
            fill.insert(1, crop)
        paragraph(caption, size=10)

    def table(headers, rows, widths):
        t = document.add_table(rows=1, cols=len(headers))
        t.alignment, t.autofit = WD_TABLE_ALIGNMENT.CENTER, False
        for col, width in zip(t.columns, widths):
            col.width = Inches(width)
        borders = OxmlElement('w:tblBorders')
        for edge in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']:
            item = OxmlElement('w:' + edge)
            for name, value in [('val', 'single'), ('sz', '4'), ('color', 'D9D9D9')]:
                item.set(qn('w:' + name), value)
            borders.append(item)
        t._tbl.tblPr.append(borders)
        for row_index, values in enumerate([headers, *rows]):
            row = t.rows[0] if row_index == 0 else t.add_row()
            if row_index == 0:
                row._tr.get_or_add_trPr().append(OxmlElement('w:tblHeader'))
            for cell, value, width in zip(row.cells, values, widths):
                cell.width = Inches(width)
                cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
                properties = cell._tc.get_or_add_tcPr()
                margins = OxmlElement('w:tcMar')
                for side, amount in [('top', '50'), ('bottom', '50'), ('left', '90'), ('right', '90')]:
                    margin = OxmlElement('w:' + side)
                    margin.set(qn('w:w'), amount)
                    margin.set(qn('w:type'), 'dxa')
                    margins.append(margin)
                properties.append(margins)
                if row_index == 0:
                    shading = OxmlElement('w:shd')
                    shading.set(qn('w:fill'), 'E7EDF1')
                    properties.append(shading)
                p = cell.paragraphs[0]
                p.paragraph_format.space_after = Pt(0)
                p.paragraph_format.line_spacing = 1.0
                r = p.add_run(value)
                r.font.name, r.font.size = 'Times New Roman', Pt(10)
                r.font.bold = row_index == 0
                r.font.color.rgb = RGBColor(0, 0, 0)
        paragraph('', size=2)

    heading('Progress Report 7 schedule and results')
    paragraph('Reporting period October 23 through October 29 2026. The current JTAG build and both '
              'uploaded applications passed on October 29. Hardware recovery evidence remains a follow-up, '
              'while the final report and demonstration retain the December 4 planning target.')
    picture(EVIDENCE / 'report-7-previous-gantt.png',
            'Figure 1. Previous schedule from Report 6, preserved without changes. Build, board and '
            'second-application targets were October 26, October 30 and November 6.')
    picture(EVIDENCE / 'report-7-current-gantt.png',
            'Figure 2. Updated schedule with October 29 completion dates, recovery and guide targets '
            'on November 6, and a report/demo draft target on November 12.')
    paragraph('The build finished three days after its target; the successful application board tests '
              'finished ahead of their targets. The November 19 draft-review checkpoint supports the '
              'existing November 24 through December 4 final report and demonstration window.', size=10)

    heading('DE10-Lite board and current FPGA build')
    paragraph('I programmed the current design and connected to its ROM loader through the board\'s '
              'USB-Blaster. The photo shows the powered DE10-Lite beside the computer displaying the '
              'hello and mixed RAM application results.')
    picture(EVIDENCE / 'report-7-board-photo.jpg',
            'Figure 3. Board photo taken October 29 at 20:57. The DE10-Lite is powered and connected '
            'while the computer displays both uploaded application tests.')
    table(['Build or timing check', 'October 29 result'], [
        ('Quartus / target', 'Lite 25.1std.0 build 1129 / MAX 10 10M50DAF484C7G'),
        ('CPU clock / JTAG timing target', '50 MHz / 10 MHz'),
        ('Worst setup / hold slack', '+2.339 ns / +0.096 ns'),
        ('Worst recovery / removal slack', '+16.793 ns / +0.403 ns'),
        ('Unconstrained clocks, ports and paths', '0 for setup and hold'),
        ('Logic / registers / memory', '3,336 logic elements; 1,504 registers; 394,240 memory bits (24%)'),
    ], [2.4, 4.1])
    paragraph('Archived build SOF SHA256', size=10, bold=True, keep=True)
    paragraph('9d47f4ddc5c03f823a16a764951a4dad\nb9ad7cc92df3df66133d5b12743686fd',
              size=9, mono=True)
    heading('Uploaded application results on the board')
    paragraph('The console screenshot records loader startup, CRC-verified uploads at 0x10000, '
              'and two runs of each application. Each execution returns to ready> without another '
              'FPGA compilation.')
    picture(EVIDENCE / 'report-7-console.png',
            'Figure 4. Original October 29 console screenshot. Empty black space at the right is '
            'cropped in Word for readability; the archived PNG is unchanged.', crop_width=1260)
    table(['Application', 'Upload size', 'Observed result'], [
        ('hello.bin', '328 bytes', 'Hello message; EXIT 0000002A; ready>; successful rerun'),
        ('mixed_ram.bin', '428 padded bytes', 'Sums 1 3 6 10 15 pass; EXIT 0000000F; ready>; successful rerun'),
    ], [1.15, 1.1, 4.25])
    paragraph('The mixed RAM program computes running sums, stores and reloads each word, then '
              'compares all five final words against fixed expected values. Its printed success '
              'message is reached only after those checks pass. The same image also passes the '
              'loader integration simulation, including CRC rejection, rerun and reset during upload.')
    paragraph('The screenshot shows repeated loader banners before the uploads. A recorded '
              'reset-after-upload, fresh-upload recovery, interrupted-transfer recovery and bad-CRC '
              'board sequence remain in next week\'s hardware goal. The five-word RAM check covers '
              'this application workload rather than every RAM location.', size=10)
    paragraph('Evidence: report-7-board-photo.jpg, report-7-console.png, report-7-regression.txt '
              'and report-7-timing-check.txt in docs/progress_reports/evidence. Build reports and '
              'SOF identity remain in the dated validation records. JTAG timing uses documented '
              '3 ns external I/O assumptions. The console capture does not independently identify '
              'the programmed SOF hash.', size=9)

    document.core_properties.title = 'Progress Report 7'
    document.core_properties.author = 'Ryan Schader'
    document.core_properties.subject = 'RISC-V RV32I CPU on an FPGA October 23 through October 29 2026'
    document.core_properties.modified = datetime.now(timezone.utc)
    generated = BytesIO()
    document.save(generated)
    with ZipFile(BytesIO(generated.getvalue())) as new:
        new_parts = {name: new.read(name) for name in new.namelist()}
    # Preserve opaque template parts byte for byte, including original styles,
    # web extensions, custom XML, numbering, icons and unused old appendix media.
    with ZipFile(FINAL, 'w', compression=ZIP_DEFLATED) as out:
        for info in original_infos:
            out.writestr(info, new_parts[info.filename] if info.filename in MUTABLE
                         else original_parts[info.filename])
        for name, data in new_parts.items():
            if name not in original_parts:
                out.writestr(name, data)
    with ZipFile(FINAL) as final_zip:
        for name, data in original_parts.items():
            if name not in MUTABLE:
                assert final_zip.read(name) == data, f'Changed preserve-only part: {name}'
    assert sha256(REFERENCE.read_bytes()).hexdigest() == REFERENCE_SHA
    print(f'Created {FINAL}; original template and preserve-only parts verified.')


if __name__ == '__main__':
    main()
