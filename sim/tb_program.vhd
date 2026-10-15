library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;
use std.env.all;
use work.rv32i_pkg.all;

-- Image/trace inputs are separate from the RTL decoder and ALU. Each retirement
-- must match the next reference row; a halt, missing row, or extra event fails.
entity tb_program is
  generic (IMAGE_FILE : string; TRACE_FILE : string;
           EXPECT_CAUSE : natural; EXPECT_PC : natural; EXPECT_TVAL : natural;
           EXPECT_REQUESTS : natural; MAX_CYCLES : natural := 5000);
end;
architecture test of tb_program is
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
    file reference : text open read_mode is TRACE_FILE;
    variable l : line;
    variable ep, ei, ev : word_t;
    variable ew, er : integer;
    variable requests, retired : natural := 0;
  begin
    wait until rising_edge(clk); wait for 1 ns; reset <= '0';
    for cycle in 1 to MAX_CYCLES loop
      wait until rising_edge(clk);
      if dq='1' then requests := requests+1; end if;
      if rv='1' then
        assert not endfile(reference) report "unexpected retirement" severity failure;
        readline(reference,l); hread(l,ep); hread(l,ei); read(l,ew); read(l,er); hread(l,ev);
        assert rp=ep and ri=ei report "retirement PC/instruction mismatch" severity failure;
        assert (rw='1')=(ew=1) report "retirement write flag mismatch" severity failure;
        if ew=1 then
          assert to_integer(unsigned(rd))=er and rddata=ev
            report "retirement register/result mismatch at PC " & to_hstring(rp) severity failure;
        end if;
        retired := retired+1;
      end if;
      wait for 1 ns;
      if tv='1' then
        assert endfile(reference) report "trap before expected retirements" severity failure;
        assert halted='1' and to_integer(unsigned(cause))=EXPECT_CAUSE and
          unsigned(tp)=EXPECT_PC and unsigned(tt)=EXPECT_TVAL
          report "trap cause/PC/tval mismatch" severity failure;
        assert requests=EXPECT_REQUESTS report "wrong number of data requests" severity failure;
        for hold_cycle in 1 to 5 loop
          assert rv='0' and iq='0' and dq='0' and tv='1' and halted='1'
            report "halt did not suppress effects" severity failure;
          wait until rising_edge(clk); wait for 1 ns;
        end loop;
        reset <= '1'; wait until rising_edge(clk); wait for 1 ns;
        assert tv='0' and halted='0' report "reset failed to recover from HALT" severity failure;
        report "tb_program passed: " & IMAGE_FILE & ", retirements=" & integer'image(retired) severity note;
        stop; wait;
      end if;
    end loop;
    assert false report "program timeout" severity failure;
    wait;
  end process;
end;
