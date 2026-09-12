library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Board smoke design. CPU integration follows completion of rv32i_core.
entity de10_lite_top is
  generic (
    -- Bit 24 gives a 0.671 s full period at 50 MHz. Reduce only in simulation.
    HEARTBEAT_BIT : natural range 0 to 31 := 24
  );
  port (
    MAX10_CLK1_50 : in  std_logic;
    KEY          : in  std_logic_vector(1 downto 0);
    SW           : in  std_logic_vector(9 downto 0);
    LEDR         : out std_logic_vector(9 downto 0)
  );
end entity;

architecture smoke of de10_lite_top is
  signal reset : std_logic;
  signal counter : unsigned(HEARTBEAT_BIT downto 0) := (others => '0');
  signal switch_meta, switch_sync : std_logic_vector(8 downto 0) := (others => '0');

  attribute preserve : boolean;
  attribute preserve of switch_meta, switch_sync : signal is true;
  attribute altera_attribute : string;
  attribute altera_attribute of switch_meta, switch_sync : signal is
    "-name SYNCHRONIZER_IDENTIFICATION ""FORCED IF ASYNCHRONOUS""";
begin
  reset_sync : entity work.reset_synchronizer
    port map (
      clk_i         => MAX10_CLK1_50,
      async_reset_i => not KEY(0),
      reset_o       => reset
    );

  process (MAX10_CLK1_50)
  begin
    if rising_edge(MAX10_CLK1_50) then
      if reset = '1' then
        counter <= (others => '0');
      else
        counter <= counter + 1;
      end if;
      -- No combinational logic or fan-out between these two stages.
      switch_meta <= SW(8 downto 0);
      switch_sync <= switch_meta;
    end if;
  end process;

  -- KEY(1) and SW(9) are unused in this initial smoke design.
  LEDR <= (others => '0') when reset = '1' else
          counter(HEARTBEAT_BIT) & switch_sync;
end architecture;
