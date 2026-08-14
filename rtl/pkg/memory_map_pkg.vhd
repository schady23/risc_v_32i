library ieee;
use ieee.std_logic_1164.all;

package memory_map_pkg is
  constant PROGRAM_ROM_BASE : std_logic_vector(31 downto 0) := x"00000000";
  constant PROGRAM_ROM_LAST : std_logic_vector(31 downto 0) := x"00003FFF";
  constant DATA_RAM_BASE    : std_logic_vector(31 downto 0) := x"00010000";
  constant DATA_RAM_LAST    : std_logic_vector(31 downto 0) := x"00013FFF";

  constant LED_ADDR    : std_logic_vector(31 downto 0) := x"40000000";
  constant SWITCH_ADDR : std_logic_vector(31 downto 0) := x"40000004";
  constant STATUS_ADDR : std_logic_vector(31 downto 0) := x"40000008";

  constant MEMORY_WORDS : positive := 4096;
end package;
