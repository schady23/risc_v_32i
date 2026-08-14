RISCV_PREFIX ?= riscv64-unknown-elf-
CC      := $(RISCV_PREFIX)gcc
OBJCOPY := $(RISCV_PREFIX)objcopy
OBJDUMP := $(RISCV_PREFIX)objdump

BUILD   := build
CFLAGS  := -march=rv32i -mabi=ilp32 -mcmodel=medany -nostdlib -nostartfiles \
           -ffreestanding -ffunction-sections -fdata-sections
LDFLAGS := -T linker.ld -Wl,--gc-sections,-Map,$(BUILD)/smoke.map

.PHONY: all clean

all: $(BUILD)/smoke.bin $(BUILD)/smoke.dump

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/startup.o: startup.S | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/smoke.o: smoke.S | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/smoke.elf: $(BUILD)/startup.o $(BUILD)/smoke.o linker.ld
	$(CC) $(CFLAGS) $(LDFLAGS) $(BUILD)/startup.o $(BUILD)/smoke.o -o $@

$(BUILD)/smoke.bin: $(BUILD)/smoke.elf
	$(OBJCOPY) -O binary $< $@

$(BUILD)/smoke.dump: $(BUILD)/smoke.elf
	$(OBJDUMP) -d -M no-aliases $< > $@

clean:
	rm -rf $(BUILD)
