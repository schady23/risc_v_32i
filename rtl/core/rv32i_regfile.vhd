library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv32i_pkg.all;

entity rv32i_regfile is
  port (
    clk_i     : in  std_logic;
    reset_i   : in  std_logic;
    rs1_addr_i : in reg_index_t;
    rs2_addr_i : in reg_index_t;
    rs1_data_o : out word_t;
    rs2_data_o : out word_t;
    rd_we_i    : in std_logic;
    rd_addr_i  : in reg_index_t;
    rd_data_i  : in word_t
  );
end entity;

architecture rtl of rv32i_regfile is
  type register_array_t is array (0 to 31) of word_t;
  signal registers : register_array_t := (others => (others => '0'));
begin
  process (clk_i)
  begin
    if rising_edge(clk_i) then
      if reset_i = '1' then
        registers <= (others => (others => '0'));
      elsif rd_we_i = '1' and rd_addr_i /= "00000" then
        registers(to_integer(unsigned(rd_addr_i))) <= rd_data_i;
      end if;
    end if;
  end process;

  rs1_data_o <= (others => '0') when rs1_addr_i = "00000" else
                registers(to_integer(unsigned(rs1_addr_i)));
  rs2_data_o <= (others => '0') when rs2_addr_i = "00000" else
                registers(to_integer(unsigned(rs2_addr_i)));
end architecture;
