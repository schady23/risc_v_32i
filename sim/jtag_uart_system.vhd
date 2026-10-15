library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.jtag_uart_sim_pkg.all;

-- Avalon/FIFO behavioral stand-in, NOT an implementation of Intel's JTAG IP.
-- It binds to the board wrapper component only in GHDL, never in Quartus.
entity jtag_uart_system is
  port (
    clk_clk, reset_reset_n : in std_logic;
    av_address, av_chipselect, av_read_n, av_write_n : in std_logic;
    av_writedata : in std_logic_vector(31 downto 0);
    av_readdata : out std_logic_vector(31 downto 0);
    av_waitrequest : out std_logic
  );
end entity;
architecture model of jtag_uart_system is
  type fifo_t is array (0 to 63) of std_logic_vector(7 downto 0);
  signal rx_fifo, tx_fifo : fifo_t;
  signal rx_count, tx_count : natural range 0 to 64 := 0;
  signal rx_rd, rx_wr, tx_rd, tx_wr : natural range 0 to 63 := 0;
  signal phase : natural range 0 to 3 := 0;
begin
  av_waitrequest <= '1' when reset_reset_n = '0' or host_stall = '1' or phase = 0 else '0';
  host_rx_ready <= '1' when rx_count < 64 and reset_reset_n = '1' else '0';
  host_tx_valid <= '1' when tx_count > 0 and reset_reset_n = '1' else '0';
  host_tx_data <= tx_fifo(tx_rd);
  process (all)
  begin
    av_readdata <= (others => '0');
    if av_address = '1' then
      av_readdata(31 downto 16) <= std_logic_vector(to_unsigned(64 - tx_count, 16));
    elsif rx_count > 0 then
      av_readdata(15) <= '1';
      av_readdata(7 downto 0) <= rx_fifo(rx_rd);
      av_readdata(31 downto 16) <= std_logic_vector(to_unsigned(rx_count - 1, 16));
    end if;
  end process;
  process (clk_clk)
    variable rn, tn : natural range 0 to 64;
  begin
    if rising_edge(clk_clk) then
      if reset_reset_n = '0' then
        rx_count <= 0; tx_count <= 0;
        rx_rd <= 0; rx_wr <= 0; tx_rd <= 0; tx_wr <= 0; phase <= 0;
      else
        phase <= (phase + 1) mod 4;
        rn := rx_count; tn := tx_count;
        if host_tx_valid = '1' and host_tx_ready = '1' then
          tx_rd <= (tx_rd + 1) mod 64; tn := tn - 1;
        end if;
        if av_chipselect = '1' and av_waitrequest = '0' then
          if av_read_n = '0' and av_address = '0' and rx_count > 0 then
            rx_rd <= (rx_rd + 1) mod 64; rn := rn - 1;
          end if;
          if av_write_n = '0' then
            assert av_address = '0' and tx_count < 64 report "bad JTAG UART write" severity failure;
            tx_fifo(tx_wr) <= av_writedata(7 downto 0);
            tx_wr <= (tx_wr + 1) mod 64; tn := tn + 1;
          end if;
        end if;
        if host_rx_valid = '1' and host_rx_ready = '1' then
          rx_fifo(rx_wr) <= host_rx_data; rx_wr <= (rx_wr + 1) mod 64; rn := rn + 1;
        end if;
        rx_count <= rn; tx_count <= tn;
      end if;
    end if;
  end process;
end architecture;
