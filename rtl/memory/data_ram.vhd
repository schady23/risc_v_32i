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
  signal valid_address, access_enable : std_logic;
  signal read_word : word_t;
  signal index : natural range 0 to MEMORY_WORDS - 1;
  signal fault : std_logic := '0';
begin
  valid_address <= '1' when unsigned(addr_i) >= unsigned(DATA_RAM_BASE) and
                            unsigned(addr_i) <= unsigned(DATA_RAM_LAST) else '0';
  access_enable <= req_i and valid_address;

  -- Four independent byte banks permit SB/SH writes without a word-wide
  -- read/modify/write. Keep fault selection outside the inference template.
  index <= to_integer(unsigned(addr_i(13 downto 2)));
  banks : for lane in 0 to 3 generate
    signal write_enable : std_logic;
  begin
    write_enable <= access_enable and write_i and be_i(lane);
    storage : entity work.ram_byte_bank
      port map (clk_i => clk_i, addr_i => index,
                data_i => wdata_i(lane * 8 + 7 downto lane * 8),
                write_i => write_enable,
                data_o => read_word(lane * 8 + 7 downto lane * 8));
  end generate;

  process (clk_i)
  begin
    if rising_edge(clk_i) then
      fault <= req_i and not valid_address;
    end if;
  end process;
  fault_o <= fault;
  rdata_o <= (others => '0') when fault = '1' else read_word;
end architecture;
