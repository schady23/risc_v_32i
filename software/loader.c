/* ROM-resident RV32I loader. No libc, interrupts, CSRs, or ISA extensions. */
typedef unsigned int u32;
typedef unsigned char u8;
#define REG(offset) (*(volatile u32 *)(0x40000000u + (offset)))
#define APP_BASE 0x00010000u
#define APP_LIMIT 0x3000u

static int get_byte(void) {
    while (!(REG(8) & 2u)) {}
    return (int)REG(4);
}
static void put_byte(int value) {
    while (!(REG(8) & 1u)) {}
    REG(0) = (u32)value;
}
static void puts_uart(const char *text) {
    while (*text) put_byte(*text++);
}
static u32 get_u32(void) {
    u32 value = 0;
    for (u32 shift = 0; shift < 32; shift += 8) value |= (u32)get_byte() << shift;
    return value;
}
static void put_hex(u32 value) {
    for (int shift = 28; shift >= 0; shift -= 4) {
        u32 digit = (value >> shift) & 15u;
        put_byte((int)(digit < 10 ? digit + '0' : digit - 10 + 'A'));
    }
}

int main(void) {
    int image_valid = 0;
    puts_uart("RV32I JTAG loader v1\r\n");
    for (;;) {
        puts_uart("ready> ");
        int command;
        do { command = get_byte(); } while (command == '\r' || command == '\n');
        if (command == '?') {
            puts_uart("L: upload; G: run; ?: help\r\n");
        } else if (command == 'L') {
            u32 length = get_u32();
            u32 expected_crc = get_u32();
            /* Invalidate before validation: a rejected replacement cannot run. */
            image_valid = 0;
            if (!length || length > APP_LIMIT || (length & 3u)) {
                puts_uart("ERR size\r\n");
                continue;
            }
            puts_uart("SEND\r\n");
            u32 crc = 0xffffffffu;
            for (u32 index = 0; index < length; ++index) {
                u32 byte = (u32)get_byte();
                *(volatile u8 *)(APP_BASE + index) = (u8)byte;
                crc ^= byte;
                for (u32 bit = 0; bit < 8; ++bit)
                    crc = (crc >> 1) ^ ((0u - (crc & 1u)) & 0xedb88320u);
                /* Stop-and-wait credit, no dependence on host transfer speed. */
                if ((index & 31u) == 31u || index + 1 == length) put_byte('+');
            }
            if ((crc ^ 0xffffffffu) != expected_crc) puts_uart("\r\nERR crc\r\n");
            else { image_valid = 1; puts_uart("\r\nLOADED\r\n"); }
        } else if (command == 'G') {
            if (!image_valid) puts_uart("ERR no image\r\n");
            else {
                puts_uart("RUN\r\n");
                int result = ((int (*)(void))APP_BASE)();
                puts_uart("EXIT "); put_hex((u32)result); puts_uart("\r\n");
            }
        } else puts_uart("ERR command\r\n");
    }
}
