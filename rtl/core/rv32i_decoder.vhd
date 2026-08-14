library ieee;
use ieee.std_logic_1164.all;

use work.rv32i_pkg.all;

entity rv32i_decoder is
  port (
    instr_i  : in  word_t;
    legal_o  : out std_logic;
    rs1_o    : out reg_index_t;
    rs2_o    : out reg_index_t;
    rd_o     : out reg_index_t;
    imm_o    : out word_t
  );
end entity;

architecture scaffold of rv32i_decoder is
begin
  -- Field extraction is available now; legality and immediate decoding are the
  -- next implementation milestone.
  legal_o <= '0';
  rs1_o   <= instr_i(19 downto 15);
  rs2_o   <= instr_i(24 downto 20);
  rd_o    <= instr_i(11 downto 7);
  imm_o   <= (others => '0');
end architecture;
