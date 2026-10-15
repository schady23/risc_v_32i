library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.rv32i_pkg.all;
use work.memory_map_pkg.all;
use work.jtag_uart_sim_pkg.all;

entity tb_jtag_uart is end entity;
architecture test of tb_jtag_uart is
  signal clk : std_logic := '0';
  signal reset, req, wr : std_logic := '0';
  signal address, wd, data, av_wd, av_data : word_t := (others => '0');
  signal be : byte_enable_t := "1111";
  signal fault, av_addr, av_rd, av_wr, av_wait : std_logic;
  type bytes_t is array (0 to 127) of std_logic_vector(7 downto 0);
  signal sent : bytes_t;
  signal sent_count : natural := 0;
begin
  clk <= not clk after 5 ns;
  dut : entity work.jtag_uart_adapter port map (
    clk, reset, req, wr, address, wd, be, data, fault,
    av_addr, av_rd, av_wr, av_wd, av_data, av_wait);
  ip_model : entity work.jtag_uart_system port map (
    clk, not reset, av_addr, av_rd or av_wr, not av_rd, not av_wr, av_wd, av_data, av_wait);
  process(clk)
    variable hold : boolean := false;
    variable old_signals : std_logic_vector(34 downto 0);
  begin
    if rising_edge(clk) then
      if reset = '0' and hold then
        assert (av_addr & av_rd & av_wr & av_wd) = old_signals
          report "Avalon request changed while stalled" severity failure;
      end if;
      hold := reset = '0' and av_wait = '1' and (av_rd = '1' or av_wr = '1');
      old_signals := av_addr & av_rd & av_wr & av_wd;
      if host_tx_valid = '1' and host_tx_ready = '1' then
        sent(sent_count) <= host_tx_data; sent_count <= sent_count + 1;
      end if;
    end if;
  end process;
  process
    procedure access_mmio(constant a : word_t; constant w : std_logic;
                          constant value : word_t := x"00000000";
                          constant expected_fault : std_logic := '0';
                          constant lanes : byte_enable_t := "1111") is
    begin
      wait until falling_edge(clk);
      req <= '1'; address <= a; wr <= w; wd <= value; be <= lanes;
      wait until rising_edge(clk); req <= '0'; wait for 1 ns;
      assert fault = expected_fault report "JTAG MMIO fault mismatch" severity failure;
    end procedure;
    procedure await_status(constant expected : word_t) is
    begin
      for index in 1 to 100 loop
        access_mmio(UART_STATUS_ADDR, '0');
        if data = expected then return; end if;
      end loop;
      assert false report "JTAG status timeout" severity failure;
    end procedure;
    procedure incoming(constant value : natural) is
    begin
      wait until falling_edge(clk);
      host_rx_data <= std_logic_vector(to_unsigned(value, 8)); host_rx_valid <= '1';
      loop wait until rising_edge(clk); exit when host_rx_ready = '1'; end loop;
      host_rx_valid <= '0';
    end procedure;
  begin
    host_stall <= '1'; reset <= '1';
    wait until rising_edge(clk); wait for 1 ns; reset <= '0';
    await_status(x"00000001");
    access_mmio(UART_RX_ADDR, '0', x"00000000", '1');
    access_mmio(UART_TX_ADDR, '0', x"00000000", '1');
    access_mmio(UART_RX_ADDR, '1', x"00000000", '1');
    access_mmio(UART_STATUS_ADDR, '1', x"00000000", '1');
    access_mmio(UART_TX_ADDR, '1', x"00000055", '1', "0001");
    access_mmio(UART_STATUS_ADDR, '0', x"00000000", '1', "0011");
    access_mmio(x"4000000C", '0', x"00000000", '1');
    access_mmio(UART_TX_ADDR, '1', x"000000A5");
    await_status(x"00000004");
    access_mmio(UART_TX_ADDR, '1', x"000000FF", '1');
    incoming(16#5A#); incoming(16#FF#);
    host_stall <= '0';
    await_status(x"00000003");
    access_mmio(UART_RX_ADDR, '0', x"00000000", '1', "0001");
    access_mmio(UART_RX_ADDR, '0');
    assert data = x"0000005A" report "RX staging lost first byte" severity failure;
    await_status(x"00000003"); access_mmio(UART_RX_ADDR, '0');
    assert data = x"000000FF" report "RX staging lost second byte" severity failure;
    await_status(x"00000001");
    assert sent_count = 1 and sent(0) = x"A5" report "TX staging duplicated/lost byte" severity failure;

    -- Full Intel TX FIFO must back-pressure TX without starving incoming data.
    host_tx_ready <= '0';
    for index in 0 to 63 loop
      await_status(x"00000001");
      access_mmio(UART_TX_ADDR, '1', std_logic_vector(to_unsigned(index, 32)));
    end loop;
    await_status(x"00000001"); access_mmio(UART_TX_ADDR, '1', x"000000EE");
    await_status(x"00000004");
    incoming(16#80#); await_status(x"00000006");
    access_mmio(UART_RX_ADDR, '0');
    assert data = x"00000080" report "TX backpressure starved RX" severity failure;
    host_tx_ready <= '1'; await_status(x"00000001");
    wait for 1 us;
    assert sent_count = 66 and sent(65) = x"EE" report "TX FIFO drain mismatch" severity failure;
    for index in 0 to 63 loop
      assert sent(index + 1) = std_logic_vector(to_unsigned(index, 8))
        report "JTAG TX byte ordering mismatch" severity failure;
    end loop;
    host_stall <= '1'; access_mmio(UART_TX_ADDR, '1', x"00000011");
    reset <= '1'; wait until rising_edge(clk); wait for 1 ns; reset <= '0';
    await_status(x"00000001");
    assert av_wr = '0' report "reset did not abort pending write" severity failure;
    report "tb_jtag_uart passed: MMIO, waitrequest, FIFO backpressure, duplex, reset" severity note;
    stop; wait;
  end process;
  process begin wait for 100 us; assert false report "JTAG adapter timeout" severity failure; end process;
end architecture;
