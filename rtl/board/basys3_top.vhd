library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity basys3_top is
  port (
    clk  : in  std_logic;
    btnC : in  std_logic;
    sw   : in  std_logic_vector(15 downto 0);
    led  : out std_logic_vector(15 downto 0)
  );
end entity;

architecture smoke of basys3_top is
  signal reset   : std_logic;
  signal counter : unsigned(25 downto 0) := (others => '0');
begin
  reset_sync : entity work.reset_synchronizer
    port map (
      clk_i         => clk,
      async_reset_i => btnC,
      reset_o       => reset
    );

  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        counter <= (others => '0');
      else
        counter <= counter + 1;
      end if;
    end if;
  end process;

  led <= (others => '0') when reset = '1' else counter(25) & sw(14 downto 0);
end architecture;
