library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv32i_pkg.all;

entity rv32i_alu is
  port (
    lhs_i    : in  word_t;
    rhs_i    : in  word_t;
    op_i     : in  alu_op_t;
    result_o : out word_t
  );
end entity;

architecture rtl of rv32i_alu is
begin
  process (all)
    variable shift_amount : natural range 0 to 31;
  begin
    shift_amount := to_integer(unsigned(rhs_i(4 downto 0)));

    case op_i is
      when ALU_ADD  => result_o <= std_logic_vector(unsigned(lhs_i) + unsigned(rhs_i));
      when ALU_SUB  => result_o <= std_logic_vector(unsigned(lhs_i) - unsigned(rhs_i));
      when ALU_SLL  => result_o <= std_logic_vector(shift_left(unsigned(lhs_i), shift_amount));
      when ALU_SLT  =>
        result_o <= (others => '0');
        if signed(lhs_i) < signed(rhs_i) then
          result_o(0) <= '1';
        end if;
      when ALU_SLTU =>
        result_o <= (others => '0');
        if unsigned(lhs_i) < unsigned(rhs_i) then
          result_o(0) <= '1';
        end if;
      when ALU_XOR  => result_o <= lhs_i xor rhs_i;
      when ALU_SRL  => result_o <= std_logic_vector(shift_right(unsigned(lhs_i), shift_amount));
      when ALU_SRA  => result_o <= std_logic_vector(shift_right(signed(lhs_i), shift_amount));
      when ALU_OR   => result_o <= lhs_i or rhs_i;
      when ALU_AND  => result_o <= lhs_i and rhs_i;
    end case;
  end process;
end architecture;
