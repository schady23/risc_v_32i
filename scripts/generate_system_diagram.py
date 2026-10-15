"""Generate the HDL-derived RV32I system diagram as a vector PDF.

Run with the Codex bundled Python (reportlab required).
"""
from pathlib import Path
import math
import re
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, white
from reportlab.lib.utils import simpleSplit

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output/pdf/rv32i_system_diagram.pdf"
W, H = 1440, 1150
DOCUMENT_DATE = "October 15, 2026"
INK = "#172D43"
BLUE = "#176BA0"
TEAL = "#087F8C"
RED = "#B54C45"
GRAY = "#667788"
LIGHT = "#EDF3F8"
ORANGE = "#AA691C"
c = None

# Conceptual CPU blocks share the core file; discrete entities name their own RTL.
# The Intel wrapper is produced by Platform Designer rather than checked in.
BLOCK_SOURCES = {
    "reset_synchronizer": ("reset_synchronizer.vhd",),
    "rv32i_core": ("rv32i_core.vhd", "rv32i_decoder.vhd",
                   "rv32i_regfile.vhd", "rv32i_alu.vhd"),
    "memory_bus": ("memory_bus.vhd",),
    "instruction_rom": ("instruction_rom.vhd", "program_image_pkg.vhd"),
    "data_ram (executable)": ("data_ram.vhd", "ram_byte_bank.vhd"),
    "jtag_uart_adapter": ("jtag_uart_adapter.vhd",),
    "Intel JTAG UART IP": ("jtag_uart_system.vhd (generated)",),
    "PC [31:0]": ("rv32i_core.vhd",),
    "Instruction memory": ("instruction_rom.vhd", "data_ram.vhd", "memory_bus.vhd"),
    "instr [31:0]": ("rv32i_core.vhd",),
    "rv32i_decoder": ("rv32i_decoder.vhd",),
    "Control / traps": ("rv32i_core.vhd", "rv32i_pkg.vhd"),
    "Register file": ("rv32i_regfile.vhd",),
    "rs1_value [31:0]": ("rv32i_core.vhd",),
    "rs2_value [31:0]": ("rv32i_core.vhd",),
    "LHS select": ("rv32i_core.vhd",),
    "RHS select": ("rv32i_core.vhd",),
    "ALU": ("rv32i_alu.vhd",),
    "Next-PC / link logic": ("rv32i_core.vhd",),
    "Branch comparator": ("rv32i_core.vhd",),
    "Memory request registers": ("rv32i_core.vhd",),
    "Data memory interface": ("rv32i_core.vhd", "memory_bus.vhd"),
    "Load lane + extension": ("rv32i_core.vhd",),
    "result [31:0]": ("rv32i_core.vhd",),
    "Instruction interface": ("rv32i_core.vhd", "memory_bus.vhd"),
    "CPU data interface": ("rv32i_core.vhd", "memory_bus.vhd"),
    "Program ROM - 16 KiB": ("instruction_rom.vhd", "program_image_pkg.vhd"),
    "Executable RAM - 16 KiB": ("data_ram.vhd", "ram_byte_bank.vhd"),
    "jtag_uart_adapter: CPU-facing MMIO": ("jtag_uart_adapter.vhd",),
}


def text(x, y, s, size=12, color=INK, bold=False, align="left"):
    c.setFillColor(HexColor("#000000"))
    c.setFont("Helvetica-Bold" if bold else "Helvetica", size)
    fn = {"left": c.drawString, "center": c.drawCentredString, "right": c.drawRightString}[align]
    fn(x, H-y, s)


def lines(x, y, ss, size=12, leading=18, color=INK, bold=False):
    for i, s in enumerate(ss):
        text(x, y+i*leading, s, size, color, bold)


def rect(x, y, w, h, fill="white", stroke="#000000", dash=False, radius=0):
    c.setFillColor(white)
    c.setStrokeColor(HexColor("#000000"))
    c.setLineWidth(1)
    c.setDash([5, 4] if dash else [])
    c.rect(x, H-y-h, w, h, stroke=1, fill=1)
    c.setDash([])


def box(x, y, w, h, title, body=(), fill=LIGHT, size=12):
    rect(x, y, w, h, fill)
    title_size = 14
    while c.stringWidth(title, "Helvetica-Bold", title_size) > w-28:
        title_size -= 0.5
    text(x+14, y+23, title, title_size, bold=True)
    source_rows = simpleSplit(" / ".join(BLOCK_SOURCES.get(title, ())),
                              "Helvetica", 9, w-28)
    source_top = h-10-(len(source_rows)-1)*11
    body_limit = source_top-14 if source_rows else h-6
    body_size = size
    while True:
        rows = [row for paragraph in body
                for row in simpleSplit(paragraph, "Helvetica", body_size, w-28)]
        leading = body_size+2
        if not rows or 40+(len(rows)-1)*leading <= body_limit:
            break
        body_size -= 0.5
        if body_size < 9.5:
            raise ValueError(f"Block explanation and filenames do not fit: {title}")
    lines(x+14, y+40, rows, body_size, leading)
    lines(x+14, y+source_top, source_rows, 9, 11)


def arrowhead(start, end):
    (x0,y0),(x1,y1)=start,end
    a=math.atan2(y1-y0,x1-x0)
    p=c.beginPath()
    p.moveTo(x1,H-y1)
    for ang in [a+2.65,a-2.65]:
        p.lineTo(x1+8*math.cos(ang),H-(y1+8*math.sin(ang)))
    p.close()
    c.drawPath(p,fill=1,stroke=0)


def path(pts, color=BLUE, width=1.1, dash=False, arrow=True, bidirectional=False):
    c.setStrokeColor(HexColor("#000000"))
    c.setFillColor(HexColor("#000000"))
    c.setLineWidth(width)
    c.setDash([5, 4] if dash else [])
    p = c.beginPath()
    p.moveTo(pts[0][0], H-pts[0][1])
    for x, y in pts[1:]:
        p.lineTo(x, H-y)
    c.drawPath(p)
    c.setDash([])
    if arrow:
        arrowhead(pts[-2], pts[-1])
        if bidirectional:
            arrowhead(pts[1], pts[0])


def label(x,y,s,size=11,color=BLUE,align="center"):
    s = re.sub(r" \[(?:32|16|4|1)\]", "", s)
    width=c.stringWidth(s,"Helvetica",size)
    xx=x-width/2 if align=="center" else x
    c.setFillColor(white)
    c.rect(xx-3,H-y-3,width+6,size+5,fill=1,stroke=0)
    text(x,y,s,size,color,align=align)


def dot(x,y,color=BLUE):
    c.setFillColor(HexColor("#000000"))
    c.circle(x,H-y,3,stroke=0,fill=1)


def header(n,title,subtitle):
    text(36,58,"RV32I System Diagram - " + title,21,bold=False)


def footer(n,refs):
    text(36,H-25,"Ryan Schader | " + DOCUMENT_DATE,11)
    text(1404,H-25,str(n),10,align="right")


def signal_key(columns, flow=False):
    """Give a compact plain-language key for the arrows on this page."""
    x, y, w, h = 36, 885, 1368, 210
    rect(x, y, w, h)
    text(x+14, y+24, "ARROW KEY", 13, bold=True)
    note = ("Arrows show the order of the upload/run process and the bytes exchanged."
            if flow else
            "I = instruction; D = data; request = command to a block; reply = result. Numbers in parentheses are bits; widths add the separate signals.")
    text(x+14, y+43, note, 11)
    column_width = w / len(columns)
    for index, sections in enumerate(columns):
        left = x + index * column_width
        if index:
            path([(left,y+55),(left,y+h-14)], arrow=False)
        cursor = y+65
        for title, body in sections:
            text(left+14, cursor, title, 11.5, bold=True)
            cursor += 16
            for item in body:
                for row in simpleSplit(item, "Helvetica", 11, column_width-28):
                    if cursor > y+h-14:
                        raise ValueError(f"Signal key overflow: {title}")
                    text(left+14, cursor, row, 11)
                    cursor += 14
            cursor += 9


def bus_mark(x,y,bits,vertical=False):
    """Conventional slash across a multi-bit wire, with its width beside it."""
    path([(x-4,y+5),(x+4,y-5)],width=1,arrow=False)
    text(x+8,y+13,str(bits),9)


def page1():
    header(1,"Top Level Diagram","")
    rect(250,145,1154,690,dash=True)
    text(270,170,"MAX 10 FPGA / de10_lite_top",15,bold=True)
    text(270,188,"de10_lite_top.vhd / rv32i_system.vhd",10)
    box(36,195,170,65,"50 MHz clock",['Provides the system clock.'],size=11)
    box(36,300,170,80,"Reset button",['Resets the system when KEY(0) is pressed.'],size=11)
    box(275,300,180,80,"reset_synchronizer",['Asserts reset immediately and releases it on a clock edge.'],size=11)
    path([(206,340),(275,340)])
    label(238,327,"NOT",10)
    path([(206,225),(1390,225)],dash=True,arrow=False)
    label(950,215,"50 MHz to CPU, bus, ROM, RAM, adapter and Intel IP",11)
    for x in [610,950,1250]:
        path([(x,225),(x,300)],dash=True); dot(x,225)
    path([(1390,225),(1390,705),(1370,705)],dash=True)
    path([(1390,460),(1370,460)],dash=True); dot(1390,460)
    path([(1095,225),(1095,705),(1070,705)],dash=True); dot(1095,225)
    path([(455,340),(475,340),(475,265),(1110,265),(1110,670)],dash=True,arrow=False)
    label(790,257,"reset: CPU, bus, adapter and Intel IP",11)
    for x in [510,840]:
        path([(x,265),(x,300)],dash=True); dot(x,265)
    path([(1110,670),(950,670),(950,690)],dash=True)
    path([(1110,670),(1160,670),(1160,690)],dash=True); dot(1110,670)
    box(500,300,250,320,"rv32i_core",['Executes 32-bit RISC-V instructions over several clock cycles. It starts in ROM and can run uploaded programs from RAM.'],size=12)
    box(820,300,250,320,"memory_bus",['Routes CPU accesses to ROM, RAM, or the JTAG UART adapter. It returns the selected data and any access fault.'],size=12)
    for y,direction,name,bits in [(345,1,"I_request",33),(405,-1,"I_reply",33),
                                  (505,1,"D_request",70),(565,-1,"D_reply",33)]:
        x1,x2=(750,820) if direction==1 else (820,750)
        path([(x1,y),(x2,y)]); label(785,y-13,name,9); bus_mark(775,y,bits)
    box(1140,300,230,105,"instruction_rom",['Stores the loader and constants in 16 KiB. Two ports serve instruction fetches and data reads.'],size=11)
    box(1140,450,230,130,"data_ram (executable)",['Stores uploaded programs and working data in 16 KiB. The CPU can read, write, and execute this memory.'],size=11)
    for y1,y2,title,reqbits,resbits in [(330,380,"ROM",66,66),(475,550,"RAM",70,33)]:
        path([(1070,y1),(1140,y1)]); label(1105,y1-13,title+"_request",8); bus_mark(1090,y1,reqbits)
        path([(1140,y2),(1070,y2)]); label(1105,y2-13,title+"_reply",8); bus_mark(1090,y2,resbits)
    box(820,690,250,100,"jtag_uart_adapter",['Buffers one byte in each direction. It connects CPU register accesses to the waiting Avalon interface.'],size=11)
    path([(880,620),(880,690)]); bus_mark(880,648,70)
    label(847,651,"MMIO_request",8)
    path([(1010,690),(1010,620)]); bus_mark(1010,648,33)
    label(1044,651,"MMIO_reply",8)
    box(1140,690,230,100,"Intel JTAG UART IP",["Transfers bytes through the FPGA's JTAG connection. Separate 64-byte FIFOs buffer incoming and outgoing data."],size=11)
    path([(1070,715),(1140,715)]); label(1105,702,"AV_request",9); bus_mark(1090,715,36)
    path([(1140,765),(1070,765)]); label(1105,752,"AV_reply",9); bus_mark(1090,765,33)
    box(36,635,170,75,"Computer",['Builds programs and exchanges bytes with the FPGA.'],size=11)
    box(36,745,170,75,"USB-Blaster",["Connects the computer's USB port to the FPGA's JTAG port."],size=10)
    path([(120,710),(120,745)],bidirectional=True); label(140,730,"USB",10,align="left")
    path([(206,775),(230,775),(230,850),(1385,850),(1385,755),(1370,755)],bidirectional=True)
    label(785,845,"Bidirectional JTAG link via dedicated device pins; no external UART TX/RX pins",11)
    signal_key([[('CPU arrows',
       ['I_request (33): address (32) + request (1).',
        'I_reply (33): instruction (32) + fault (1).',
        'D_request (70): address (32) + write data (32)',
        '+ byte enables (4) + request (1) + write (1).',
        'D_reply (33): read data (32) + fault (1).'])],
     [('Memory and MMIO arrows',
       ['ROM_request (66): two addresses (32 each) + two requests (1 each).',
        'ROM_reply (66): two words (32 each) + two faults (1 each).',
        'RAM_request / MMIO_request (70): same fields as D_request.',
        'RAM_reply / MMIO_reply (33): read data (32) + fault (1).',
        'Byte enables select which of the four bytes to write.'])],
     [('Avalon and external connections',
       ['AV_request (36): write data (32) + register select (1)',
        '+ chip select (1) + read (1) + write (1).',
        'AV_reply (33): read data (32) + wait (1).',
        'Clock and reset: one bit each; dashed arrows.',
        'USB / JTAG: byte traffic carried by the external protocols.'])]])
    footer(1,""); c.showPage()


def page2():
    header(2,"CPU Datapath and Control","rv32i_core: architectural registers, operand selection, next PC, load/store formatting, and fault capture")
    # Main flow deliberately uses separate horizontal lanes.
    box(40,170,165,78,"PC [31:0]",['Holds the current instruction address.'],size=11)
    box(275,170,180,90,"Instruction memory",['Returns an instruction from ROM or RAM.'],size=11)
    box(520,170,165,78,"instr [31:0]",['Holds the instruction being executed.'],size=11)
    box(750,170,235,78,"rv32i_decoder",['Extracts register numbers, the immediate, and instruction control.'],size=11)
    box(1050,160,350,105,"Control / traps",['Sequences instruction execution and register updates. A fault records its cause and halts the CPU until reset.'],size=11)
    path([(205,194),(275,194)])
    label(240,183,"i_addr [32]",10)
    path([(455,209),(520,209)])
    label(488,198,"i_rdata [32]",10)
    path([(685,209),(750,209)])
    label(717,198,"instr [32]",10)
    path([(985,194),(1050,194)],GRAY,dash=True)
    label(1025,182,"control",9,GRAY)
    path([(455,232),(500,232),(500,325),(1030,325),(1030,250),(1050,250)],RED,dash=True)
    label(810,338,"i_fault",10)
    # Register file to operands to ALU.
    box(40,360,220,160,"Register file",['Stores 32 registers and supplies two source values. Register x0 always reads as zero.'],size=12)
    box(335,345,195,70,"rs1_value [31:0]",['Holds the first source operand.'],size=11)
    box(335,465,195,70,"rs2_value [31:0]",['Holds the second source operand.'],size=11)
    box(610,345,175,70,"LHS select",['Selects rs1, PC, or zero.'],size=11)
    box(610,465,175,70,"RHS select",['Selects rs2 or the immediate.'],size=11)
    box(865,380,215,140,"ALU",['Performs arithmetic, logic, shifts, and comparisons.'],size=12)
    path([(260,380),(335,380)])
    label(297,369,"reg_rs1 [32]",10)
    path([(260,495),(335,495)])
    label(298,484,"reg_rs2 [32]",10)
    path([(530,380),(610,380)])
    path([(530,500),(610,500)])
    path([(785,380),(823,380),(823,410),(865,410)])
    label(819,370,"alu_lhs [32]",10)
    path([(785,500),(823,500),(823,485),(865,485)])
    label(810,519,"rhs [32]",9)
    # Decoder register fields and immediate distribution.
    path([(790,248),(790,292),(150,292),(150,360)])
    label(445,283,"rs1 / rs2 read addresses [5 each]; rd write address [5]",11)
    path([(900,248),(900,315),(580,315),(580,485),(610,485)])
    label(695,307,"immediate [32]",11)
    path([(120,248),(120,273),(565,273),(565,365),(610,365)])
    label(353,264,"PC [32]",11)
    # Computed PC path: ALU target and separate PC+4.
    box(1150,325,250,115,"Next-PC / link logic",['Chooses PC + 4 or a branch/jump target. It also provides the return address for JAL and JALR.'],size=11)
    path([(1080,410),(1110,410),(1110,355),(1150,355)])
    label(1116,344,"target [32]",10)
    path([(120,170),(120,140),(1425,140),(1425,355),(1400,355)])
    label(630,135,"PC [32] -> separate PC + 4 addition",11)
    box(335,585,260,90,"Branch comparator",['Compares the source operands to decide whether a branch is taken.'],size=11)
    path([(450,415),(450,440),(305,440),(305,610),(335,610)])
    path([(450,535),(450,585)])
    path([(595,625),(620,625),(620,575),(1135,575),(1135,420),(1150,420)])
    label(1030,589,"branch taken",10)
    # Memory path.
    box(650,585,290,115,"Memory request registers",['Hold the memory address, store data, and byte enables while an access completes.'],size=11)
    path([(1000,520),(1000,555),(810,555),(810,585)])
    label(884,548,"effective address [32]",11)
    path([(530,520),(555,520),(555,545),(680,545),(680,585)])
    label(619,537,"rs2 [32]",10)
    box(1010,710,390,100,"Data memory interface",['Sends CPU load/store requests to the memory bus. It receives the read data and any access fault.'],size=12)
    path([(940,665),(970,665),(970,740),(1010,740)],TEAL)
    label(970,703,"D_request",10,TEAL)
    box(650,735,290,82,"Load lane + extension",['Selects the requested byte or halfword and extends it to 32 bits.'],size=10)
    path([(1010,780),(940,780)],TEAL)
    label(975,769,"read [32]",10,TEAL)
    path([(1325,710),(1325,680),(1420,680),(1420,290),(1370,290),(1370,265)],RED,dash=True)
    label(1370,672,"d_fault",10)
    # Result selection, writeback and feedback.
    box(335,735,240,82,"result [31:0]",['Holds the ALU, load, or link value to write into the destination register.'],size=11)
    path([(650,780),(575,780)])
    path([(1080,450),(1095,450),(1095,710),(600,710),(600,750),(575,750)])
    label(785,707,"ALU result [32]",11)
    path([(1400,385),(1415,385),(1415,835),(455,835),(455,817)])
    label(1190,849,"PC + 4 [32] (JAL / JALR link)",11)
    path([(335,780),(150,780),(150,520)])
    label(150,724,"rd_data [32]",11)
    # A dedicated top lane distinguishes feedback from the PC+4 input/link.
    # Use the same straight crossings and line weight as all other data paths.
    path([(1250,325),(1250,280),(1005,280),(1005,105),(80,105),(80,170)])
    label(560,94,"next_pc (32 bits) - updates PC in WRITEBACK",11)
    for x,y,n in [(237,194,32),(484,209,32),(714,209,32),(296,380,32),(296,495,32),
                  (568,380,32),(568,500,32),(830,410,32),(830,485,32),(565,342,32),
                  (580,450,32),(400,292,15),(120,260,32),(1118,355,32),(710,140,32),
                  (305,570,32),(450,561,32),(890,555,32),(600,545,32),(970,725,70),
                  (973,780,32),(612,780,32),(790,710,32),(1095,635,32),
                  (1000,835,32),(150,660,32),(300,105,32)]:
        bus_mark(x,y,n)
    signal_key([[('Instruction, register, and address arrows',
       ['PC / i_addr / next_pc / PC + 4: one 32-bit address each.',
        'i_rdata / instr: one 32-bit instruction each.',
        'rs1 / rs2 / rd: three 5-bit register numbers (15 total).',
        'reg_rs1 / reg_rs2 / rs1_value / rs2_value:',
        'one 32-bit register value on each arrow.'])],
     [('ALU and writeback arrows',
       ['immediate: one 32-bit instruction constant.',
        'alu_lhs / rhs: one 32-bit ALU input each.',
        'target / effective address / ALU result: 32 bits each.',
        'rs2 / read / rd_data: one 32-bit data value each.',
        'branch taken / i_fault / d_fault: one decision bit each.'])],
     [('Memory and control arrows',
       ['D_request (70): address (32) + write data (32)',
        '+ byte enables (4) + request (1) + write (1).',
        'control: instruction kind, ALU operation, operand choices,',
        'writeback choice, branch condition, and load/store options.',
        'The control fields are a VHDL record, not a fixed-width bus.'])]])
    footer(2,"")
    c.showPage()


def page3():
    header(3,"Memory and JTAG UART Routing","")
    box(36,170,260,105,"Instruction interface",['Requests the next instruction and returns its value or an access fault.'],size=11)
    box(36,350,260,130,"CPU data interface",['Carries load/store requests, byte enables, and the returned data or fault.'],size=11)
    box(380,170,480,310,"memory_bus",['Routes CPU accesses to ROM, RAM, or the JTAG UART adapter. It returns the selected data and any access fault.'],size=12)
    for y,direction,bits,title in [(195,1,33,"I_request"),(245,-1,33,"I_reply"),(375,1,70,"D_request"),(445,-1,33,"D_reply")]:
        x1,x2=(296,380) if direction==1 else (380,296)
        path([(x1,y),(x2,y)]); label(338,y-12,title,10); bus_mark(326,y,bits)
    box(1000,150,400,125,"Program ROM - 16 KiB",['Stores the resident loader and constants at 0x00000000-0x00003FFF. Port A fetches instructions; port B reads data.'],size=12)
    path([(860,195),(1000,195)]); label(930,184,"ROM_request",10); bus_mark(916,195,66)
    path([(1000,245),(860,245)]); label(930,234,"ROM_reply",10); bus_mark(916,245,66)
    box(1000,330,400,155,"Executable RAM - 16 KiB",['Stores programs, data, and stacks at 0x00010000-0x00013FFF. Four byte banks allow individual bytes to be written.'],size=12)
    path([(860,365),(1000,365)]); label(930,354,"RAM_request",10); bus_mark(916,365,70)
    path([(1000,445),(860,445)]); label(930,434,"RAM_reply",10); bus_mark(916,445,33)
    box(380,610,480,155,"jtag_uart_adapter: CPU-facing MMIO",['Exposes TX, RX, and status registers at 0x40000000, 0x40000004, and 0x40000008. One-byte buffers separate CPU accesses from Avalon waits.'],size=11)
    path([(470,480),(470,610)]); label(470,540,"MMIO_request",11); bus_mark(470,568,70)
    path([(790,610),(790,480)]); label(790,540,"MMIO_reply",11); bus_mark(790,568,33)
    box(1000,610,400,155,"Intel JTAG UART IP",["Transfers bytes through the FPGA's JTAG connection. Separate 64-byte FIFOs buffer incoming and outgoing data."],size=11)
    path([(860,650),(1000,650)]); label(930,637,"AV_request",10); bus_mark(916,650,36)
    path([(1000,725),(860,725)]); label(930,712,"AV_reply",10); bus_mark(916,725,33)
    box(36,610,260,155,"Host PC / USB-Blaster",['Uploads programs and exchanges console bytes through the existing USB-Blaster connection.'],size=11)
    path([(296,700),(325,700),(325,815),(1380,815),(1380,765)],bidirectional=True)
    label(785,807,"Bidirectional JTAG through dedicated FPGA pins",11)
    signal_key([[('CPU and ROM arrows',
       ['I_request (33): address (32) + request (1).',
        'I_reply / D_reply (33): word (32) + fault (1).',
        'ROM_request (66): two addresses (32 each) + two requests (1 each).',
        'ROM_reply (66): two words (32 each) + two faults (1 each).'])],
     [('Data, RAM, and MMIO arrows',
       ['D_request / RAM_request / MMIO_request (70):',
        'address (32) + write data (32) + byte enables (4)',
        '+ request (1) + write (1).',
        'RAM_reply / MMIO_reply (33): read data (32) + fault (1).',
        'Each byte-enable bit selects one of the four word bytes.'])],
     [('Avalon and JTAG arrows',
       ['AV_request (36): write data (32) + register select (1)',
        '+ chip select (1) + read (1) + write (1).',
        'AV_reply (33): read data (32) + wait (1).',
        'Data register: byte [7:0], valid [15]; control: TX space [31:16].',
        'JTAG link: incoming and outgoing bytes through USB-Blaster.'])]])
    footer(3,""); c.showPage()


def page4():
    header(4,"Program Upload and Execution","")
    box(36,160,300,145,"1. Build on the computer",['Assembles or compiles a program into a binary linked to run at 0x00010000. This does not rebuild the FPGA.'],size=12)
    box(405,160,300,145,"2. Upload through USB-Blaster",['Sends the length, checksum, and program bytes over JTAG UART. The loader acknowledges each chunk of up to 32 bytes.'],size=12)
    box(775,160,300,145,"3. ROM loader validates",['Checks the upload size and CRC32 while storing the program in RAM. A valid image is allowed to run.'],size=12)
    path([(336,225),(405,225)]); label(370,211,"Program bytes",10)
    path([(705,225),(775,225)]); label(740,211,"JTAG",10)
    box(1140,160,260,145,"4. Start application",['Calls the program when G is received. On return, the loader prints its exit value.'],size=11)
    path([(1075,225),(1140,225)]); label(1108,211,"verified",9)
    path([(1270,305),(1270,355),(555,355),(555,305)])
    label(910,347,"Return and upload another program using the same FPGA configuration",11)
    box(36,425,650,320,"RAM layout and ownership",['Divides RAM into space for the application, its stack, and the loader. These regions are a software convention.', 'Application image / data: 0x00010000-0x00012FFF (12 KiB)', 'Application stack: 0x00013000-0x00013BFF (3 KiB)', 'Loader workspace / stack: 0x00013C00-0x00013FFF (1 KiB)'],size=12)
    box(750,425,650,320,"Protocol and example session",['Uses L to upload, G to run, and ? for help. A successful upload reports LOADED before G can start the program.', 'Example: upload -> LOADED -> G -> RUN', 'Program output -> EXIT 0000002A -> ready>'],size=12)
    signal_key([[('Program bytes / JTAG arrows',
       ['Program bytes: the compiled instructions and initial data.',
        'Upload header: L (1 byte) + length (4 bytes) + CRC32 (4 bytes).',
        'The image follows in chunks of up to 32 bytes.',
        'Multi-byte header values send their lowest byte first.'])],
     [('Verified / return arrows',
       ['Verified: size and checksum passed; G may start the program.',
        'Return path: program output, exit value, and the next prompt.',
        'Each + reply permits the next upload chunk.',
        'These are software-flow arrows, not parallel hardware buses.'])],
     [('Values carried in the byte stream',
       ['Each transmitted byte is 8 bits.',
        'Length and CRC32 are 32-bit values, sent as four bytes each.',
        'The exit value is 32 bits, printed as eight hex characters.',
        'CRC32 checks the received bytes for transfer corruption.'])]], flow=True)
    footer(4,""); c.showPage()


def main():
    global c
    rtl_names = {path.name for path in (ROOT / "rtl").rglob("*.vhd")}
    for sources in BLOCK_SOURCES.values():
        for name in sources:
            if not name.endswith(" (generated)") and name not in rtl_names:
                raise ValueError(f"Missing diagram RTL source: {name}")
    OUT.parent.mkdir(parents=True,exist_ok=True)
    c=canvas.Canvas(str(OUT),pagesize=(W,H),pageCompression=1)
    c.setTitle("RV32I System Diagram")
    c.setAuthor("Ryan Schader")
    c.setSubject("HDL-derived complete system, CPU data paths, memory bus, executable RAM, JTAG UART and ROM loader")
    page1(); page2(); page3(); page4()
    c.save()
    print(OUT)


if __name__ == "__main__":
    main()
