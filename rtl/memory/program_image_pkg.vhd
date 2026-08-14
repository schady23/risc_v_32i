library ieee;
use ieee.std_logic_1164.all;

use work.rv32i_pkg.all;
use work.memory_map_pkg.all;

package program_image_pkg is
  type program_image_t is array (0 to MEMORY_WORDS - 1) of word_t;

  -- This package is replaced by scripts/elf_to_vhdl.py when software is built.
  constant PROGRAM_IMAGE : program_image_t := (others => (others => '0'));
end package;
