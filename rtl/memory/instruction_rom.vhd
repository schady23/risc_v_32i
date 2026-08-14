library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv32i_pkg.all;
use work.memory_map_pkg.all;
use work.program_image_pkg.all;

entity instruction_rom is
  port (
    clk_i : in std_logic;

    a_req_i   : in  std_logic;
    a_addr_i  : in  word_t;
    a_rdata_o : out word_t;
    a_fault_o : out std_logic;

    b_req_i   : in  std_logic;
    b_addr_i  : in  word_t;
    b_rdata_o : out word_t;
    b_fault_o : out std_logic
  );
end entity;

architecture rtl of instruction_rom is
begin
  process (clk_i)
  begin
    if rising_edge(clk_i) then
      a_fault_o <= '0';
      if a_req_i = '1' then
        if unsigned(a_addr_i) <= unsigned(PROGRAM_ROM_LAST) then
          a_rdata_o <= PROGRAM_IMAGE(to_integer(unsigned(a_addr_i(13 downto 2))));
        else
          a_rdata_o <= (others => '0');
          a_fault_o <= '1';
        end if;
      end if;

      b_fault_o <= '0';
      if b_req_i = '1' then
        if unsigned(b_addr_i) <= unsigned(PROGRAM_ROM_LAST) then
          b_rdata_o <= PROGRAM_IMAGE(to_integer(unsigned(b_addr_i(13 downto 2))));
        else
          b_rdata_o <= (others => '0');
          b_fault_o <= '1';
        end if;
      end if;
    end if;
  end process;
end architecture;
