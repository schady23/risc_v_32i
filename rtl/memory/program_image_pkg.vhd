library ieee;
use ieee.std_logic_1164.all;

use work.rv32i_pkg.all;
use work.memory_map_pkg.all;

package program_image_pkg is
  type program_image_t is array (0 to MEMORY_WORDS - 1) of word_t;

  -- Built-in board demo: LUI x5,0x40000; ADDI x6,x0,0x155;
  -- SW x6,0(x5); JAL x0,0. The image generator can replace this package.
  constant PROGRAM_IMAGE : program_image_t := (
    0 => x"400002B7",
    1 => x"15500313",
    2 => x"0062A023",
    3 => x"0000006F",
    others => (others => '0')
  );
end package;
