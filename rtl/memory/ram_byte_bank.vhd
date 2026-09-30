library ieee;
use ieee.std_logic_1164.all;

-- Quartus Standard's single-port RAM template, one byte wide. Separate design
-- units let synthesis recognize each bank before wrapper fault/lane logic.
entity ram_byte_bank is
  port (
    clk_i : in std_logic;
    addr_i : in natural range 0 to 4095;
    data_i : in std_logic_vector(7 downto 0);
    write_i : in std_logic;
    data_o : out std_logic_vector(7 downto 0)
  );
end entity;
architecture rtl of ram_byte_bank is
  type bank_t is array (4095 downto 0) of std_logic_vector(7 downto 0);
  signal bank : bank_t := (others => (others => '0'));
  signal read_index : natural range 0 to 4095;
  attribute ramstyle : string;
  attribute ramstyle of bank : signal is "M9K";
begin
  process (clk_i)
  begin
    if rising_edge(clk_i) then
      if write_i = '1' then
        bank(addr_i) <= data_i;
      end if;
      read_index <= addr_i;
    end if;
  end process;
  data_o <= bank(read_index);
end architecture;
