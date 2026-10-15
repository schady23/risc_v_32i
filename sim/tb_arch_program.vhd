library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;
use std.env.all;
use work.rv32i_pkg.all;

-- Local adapter for self-checking binaries. A simulator-observed RAM store
-- reports completion; no peripheral or CPU ISA behavior is changed.
entity tb_arch_program is
  generic (IMAGE_FILE : string; MAX_CYCLES : natural := 100000);
end;
architecture test of tb_arch_program is
  type image_t is array (0 to 4095) of word_t;
  impure function read_image return image_t is
    file f : text open read_mode is IMAGE_FILE;
    variable l : line;
    variable image : image_t := (others => x"00000000");
    variable n : natural := 0;
  begin
    while not endfile(f) loop
      readline(f,l); hread(l,image(n)); n := n+1;
    end loop;
    return image;
  end;
  constant image : image_t := read_image;
  signal clk : std_logic := '0';
  signal reset : std_logic := '1';
  signal iq, ifault, dq, dw, dfault, halted, tv, rv, rw : std_logic;
  signal ia, idata, da, wd, data, tp, tt, rp, ri, rddata : word_t := (others=>'0');
  signal be : byte_enable_t;
  signal cause : trap_cause_t;
  signal rd : reg_index_t;
begin
  clk <= not clk after 5 ns;
  cpu : entity work.rv32i_core port map (
    clk, reset, iq, ia, idata, ifault, dq, dw, da, wd, be, data, dfault,
    halted, tv, cause, tp, tt, rv, rp, ri, rw, rd, rddata);
  memory : entity work.memory_bus port map (
    clk_i=>clk, reset_i=>reset, i_req_i=>'0', i_addr_i=>x"00000000",
    i_rdata_o=>open, i_fault_o=>open, d_req_i=>dq, d_write_i=>dw,
    d_addr_i=>da, d_wdata_i=>wd, d_be_i=>be, d_rdata_o=>data,
    d_fault_o=>dfault, av_address_o=>open, av_read_o=>open, av_write_o=>open,
    av_writedata_o=>open, av_readdata_i=>x"00400000", av_waitrequest_i=>'0');
  process(clk)
  begin
    if rising_edge(clk) then
      ifault <= '0';
      if iq='1' then
        if unsigned(ia)<16384 and ia(1 downto 0)="00" then
          idata <= image(to_integer(unsigned(ia(13 downto 2))));
        else
          ifault <= '1'; idata <= (others=>'0');
        end if;
      end if;
    end if;
  end process;
  process
    variable completion : boolean := false;
    variable completion_value : word_t;
  begin
    wait until rising_edge(clk); wait for 1 ns; reset <= '0';
    for cycle in 1 to MAX_CYCLES loop
      wait until rising_edge(clk);
      if dq='1' and dw='1' and da=x"00013FFC" then
        assert be="1111" report "completion must be a word store" severity failure;
        completion := true; completion_value := wd;
      end if;
      wait for 1 ns;
      if completion then
        assert dfault='0' report "completion store faulted" severity failure;
        assert completion_value=x"00000001" report "program reported failure" severity failure;
        report "tb_arch_program passed: " & IMAGE_FILE severity note;
        stop; wait;
      end if;
      assert tv='0' report "unexpected architectural trap" severity failure;
    end loop;
    assert false report "architectural program timeout" severity failure;
    wait;
  end process;
end;
