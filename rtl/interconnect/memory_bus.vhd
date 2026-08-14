library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv32i_pkg.all;
use work.memory_map_pkg.all;

entity memory_bus is
  port (
    clk_i   : in std_logic;
    reset_i : in std_logic;

    i_req_i   : in  std_logic;
    i_addr_i  : in  word_t;
    i_rdata_o : out word_t;
    i_fault_o : out std_logic;

    d_req_i   : in  std_logic;
    d_write_i : in  std_logic;
    d_addr_i  : in  word_t;
    d_wdata_i : in  word_t;
    d_be_i    : in  byte_enable_t;
    d_rdata_o : out word_t;
    d_fault_o : out std_logic;

    switches_i : in  std_logic_vector(15 downto 0);
    status_i   : in  word_t;
    leds_o     : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of memory_bus is
  type target_t is (TARGET_NONE, TARGET_ROM, TARGET_RAM, TARGET_GPIO, TARGET_INVALID);
  signal d_target, d_target_q : target_t := TARGET_NONE;

  signal rom_d_req, ram_req, gpio_req : std_logic;
  signal rom_i_rdata, rom_d_rdata, ram_rdata, gpio_rdata : word_t;
  signal rom_i_fault, rom_d_fault, ram_fault, gpio_fault : std_logic;
begin
  program_rom : entity work.instruction_rom
    port map (
      clk_i     => clk_i,
      a_req_i   => i_req_i,
      a_addr_i  => i_addr_i,
      a_rdata_o => rom_i_rdata,
      a_fault_o => rom_i_fault,
      b_req_i   => rom_d_req,
      b_addr_i  => d_addr_i,
      b_rdata_o => rom_d_rdata,
      b_fault_o => rom_d_fault
    );

  data_memory : entity work.data_ram
    port map (
      clk_i   => clk_i,
      req_i   => ram_req,
      write_i => d_write_i,
      addr_i  => d_addr_i,
      wdata_i => d_wdata_i,
      be_i    => d_be_i,
      rdata_o => ram_rdata,
      fault_o => ram_fault
    );

  gpio_device : entity work.gpio
    port map (
      clk_i      => clk_i,
      reset_i    => reset_i,
      req_i      => gpio_req,
      write_i    => d_write_i,
      addr_i     => d_addr_i,
      wdata_i    => d_wdata_i,
      be_i       => d_be_i,
      rdata_o    => gpio_rdata,
      fault_o    => gpio_fault,
      switches_i => switches_i,
      status_i   => status_i,
      leds_o     => leds_o
    );

  process (all)
  begin
    d_target <= TARGET_NONE;
    if d_req_i = '1' then
      if unsigned(d_addr_i) <= unsigned(PROGRAM_ROM_LAST) then
        if d_write_i = '1' then
          d_target <= TARGET_INVALID;
        else
          d_target <= TARGET_ROM;
        end if;
      elsif unsigned(d_addr_i) >= unsigned(DATA_RAM_BASE) and
            unsigned(d_addr_i) <= unsigned(DATA_RAM_LAST) then
        d_target <= TARGET_RAM;
      elsif d_addr_i = LED_ADDR or d_addr_i = SWITCH_ADDR or d_addr_i = STATUS_ADDR then
        d_target <= TARGET_GPIO;
      else
        d_target <= TARGET_INVALID;
      end if;
    end if;
  end process;

  rom_d_req <= d_req_i when d_target = TARGET_ROM else '0';
  ram_req   <= d_req_i when d_target = TARGET_RAM else '0';
  gpio_req  <= d_req_i when d_target = TARGET_GPIO else '0';

  process (clk_i)
  begin
    if rising_edge(clk_i) then
      if reset_i = '1' then
        d_target_q <= TARGET_NONE;
      else
        d_target_q <= d_target;
      end if;
    end if;
  end process;

  i_rdata_o <= rom_i_rdata;
  i_fault_o <= rom_i_fault;

  process (all)
  begin
    d_rdata_o <= (others => '0');
    d_fault_o <= '0';

    case d_target_q is
      when TARGET_ROM =>
        d_rdata_o <= rom_d_rdata;
        d_fault_o <= rom_d_fault;
      when TARGET_RAM =>
        d_rdata_o <= ram_rdata;
        d_fault_o <= ram_fault;
      when TARGET_GPIO =>
        d_rdata_o <= gpio_rdata;
        d_fault_o <= gpio_fault;
      when TARGET_INVALID =>
        d_fault_o <= '1';
      when TARGET_NONE =>
        null;
    end case;
  end process;
end architecture;
