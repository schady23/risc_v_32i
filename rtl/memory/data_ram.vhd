library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv32i_pkg.all;
use work.memory_map_pkg.all;

entity data_ram is
  port (
    clk_i   : in  std_logic;
    req_i   : in  std_logic;
    write_i : in  std_logic;
    addr_i  : in  word_t;
    wdata_i : in  word_t;
    be_i    : in  byte_enable_t;
    rdata_o : out word_t;
    fault_o : out std_logic
  );
end entity;

architecture rtl of data_ram is
  type ram_t is array (0 to MEMORY_WORDS - 1) of word_t;
  signal ram : ram_t := (others => (others => '0'));
begin
  process (clk_i)
    variable index : natural range 0 to MEMORY_WORDS - 1;
  begin
    if rising_edge(clk_i) then
      fault_o <= '0';
      if req_i = '1' then
        if unsigned(addr_i) >= unsigned(DATA_RAM_BASE) and
           unsigned(addr_i) <= unsigned(DATA_RAM_LAST) then
          index := to_integer(unsigned(addr_i(13 downto 2)));
          rdata_o <= ram(index);

          if write_i = '1' then
            for lane in 0 to 3 loop
              if be_i(lane) = '1' then
                ram(index)(lane * 8 + 7 downto lane * 8) <=
                  wdata_i(lane * 8 + 7 downto lane * 8);
              end if;
            end loop;
          end if;
        else
          rdata_o <= (others => '0');
          fault_o <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture;
