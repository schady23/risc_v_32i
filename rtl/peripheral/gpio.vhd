library ieee;
use ieee.std_logic_1164.all;

use work.rv32i_pkg.all;
use work.memory_map_pkg.all;

entity gpio is
  port (
    clk_i      : in  std_logic;
    reset_i    : in  std_logic;
    req_i      : in  std_logic;
    write_i    : in  std_logic;
    addr_i     : in  word_t;
    wdata_i    : in  word_t;
    be_i       : in  byte_enable_t;
    rdata_o    : out word_t;
    fault_o    : out std_logic;
    switches_i : in  std_logic_vector(15 downto 0);
    status_i   : in  word_t;
    leds_o     : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of gpio is
  signal switch_meta : std_logic_vector(15 downto 0) := (others => '0');
  signal switch_sync : std_logic_vector(15 downto 0) := (others => '0');
  signal led_register : std_logic_vector(15 downto 0) := (others => '0');
begin
  process (clk_i)
  begin
    if rising_edge(clk_i) then
      switch_meta <= switches_i;
      switch_sync <= switch_meta;
      fault_o <= '0';

      if reset_i = '1' then
        led_register <= (others => '0');
        rdata_o <= (others => '0');
      elsif req_i = '1' then
        rdata_o <= (others => '0');

        if be_i /= "1111" then
          fault_o <= '1';
        elsif addr_i = LED_ADDR then
          rdata_o(15 downto 0) <= led_register;
          if write_i = '1' then
            led_register <= wdata_i(15 downto 0);
          end if;
        elsif addr_i = SWITCH_ADDR and write_i = '0' then
          rdata_o(15 downto 0) <= switch_sync;
        elsif addr_i = STATUS_ADDR and write_i = '0' then
          rdata_o <= status_i;
        else
          fault_o <= '1';
        end if;
      end if;
    end if;
  end process;

  leds_o <= led_register;
end architecture;
