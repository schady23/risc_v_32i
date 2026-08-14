library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

use work.rv32i_pkg.all;

entity tb_alu is
end entity;

architecture test of tb_alu is
  signal lhs, rhs, result : word_t := (others => '0');
  signal operation : alu_op_t := ALU_ADD;
begin
  dut : entity work.rv32i_alu
    port map (
      lhs_i    => lhs,
      rhs_i    => rhs,
      op_i     => operation,
      result_o => result
    );

  process
  begin
    lhs <= x"00000002";
    rhs <= x"00000003";
    operation <= ALU_ADD;
    wait for 1 ns;
    assert result = x"00000005" report "ADD failed" severity failure;

    lhs <= x"00000000";
    rhs <= x"00000001";
    operation <= ALU_SUB;
    wait for 1 ns;
    assert result = x"FFFFFFFF" report "SUB wraparound failed" severity failure;

    lhs <= x"FFFFFFFF";
    rhs <= x"00000001";
    operation <= ALU_SLT;
    wait for 1 ns;
    assert result = x"00000001" report "signed SLT failed" severity failure;

    operation <= ALU_SLTU;
    wait for 1 ns;
    assert result = x"00000000" report "unsigned SLTU failed" severity failure;

    lhs <= x"80000000";
    operation <= ALU_SRA;
    wait for 1 ns;
    assert result = x"C0000000" report "SRA failed" severity failure;

    report "tb_alu passed" severity note;
    stop;
    wait;
  end process;
end architecture;
