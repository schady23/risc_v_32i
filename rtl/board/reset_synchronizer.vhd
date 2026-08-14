library ieee;
use ieee.std_logic_1164.all;

entity reset_synchronizer is
  port (
    clk_i         : in  std_logic;
    async_reset_i : in  std_logic;
    reset_o       : out std_logic
  );
end entity;

architecture rtl of reset_synchronizer is
  signal sync_stages : std_logic_vector(1 downto 0) := (others => '1');

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of sync_stages : signal is "TRUE";
begin
  process (clk_i, async_reset_i)
  begin
    if async_reset_i = '1' then
      sync_stages <= (others => '1');
    elsif rising_edge(clk_i) then
      sync_stages <= sync_stages(0) & '0';
    end if;
  end process;

  reset_o <= sync_stages(1);
end architecture;
