library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.rv32i_pkg.all;
use work.memory_map_pkg.all;

-- One-byte staging in each direction decouples fixed-latency CPU MMIO from
-- the Intel JTAG UART's Avalon waitrequest. Only full-word CPU accesses work.
entity jtag_uart_adapter is
  port (
    clk_i, reset_i, req_i, write_i : in std_logic;
    addr_i, wdata_i : in word_t;
    be_i : in byte_enable_t;
    rdata_o : out word_t;
    fault_o : out std_logic;
    av_address_o, av_read_o, av_write_o : out std_logic;
    av_writedata_o : out word_t;
    av_readdata_i : in word_t;
    av_waitrequest_i : in std_logic
  );
end entity;

architecture rtl of jtag_uart_adapter is
  type state_t is (IDLE, READ_RX, READ_CONTROL, WRITE_TX);
  signal state : state_t := IDLE;
  signal tx_pending, rx_valid : std_logic := '0';
  signal tx_byte, rx_byte : std_logic_vector(7 downto 0) := (others => '0');
begin
  av_address_o <= '1' when state = READ_CONTROL else '0';
  av_read_o <= '1' when reset_i = '0' and (state = READ_RX or state = READ_CONTROL) else '0';
  av_write_o <= '1' when reset_i = '0' and state = WRITE_TX else '0';
  av_writedata_o <= x"000000" & tx_byte when state = WRITE_TX else (others => '0');

  process (clk_i)
  begin
    if rising_edge(clk_i) then
      fault_o <= '0';
      if reset_i = '1' then
        state <= IDLE; tx_pending <= '0'; rx_valid <= '0';
        tx_byte <= (others => '0'); rx_byte <= (others => '0');
        rdata_o <= (others => '0');
      else
        case state is
          when IDLE =>
            if tx_pending = '1' then state <= READ_CONTROL;
            elsif rx_valid = '0' then state <= READ_RX; end if;
          when READ_RX =>
            if av_waitrequest_i = '0' then
              if av_readdata_i(15) = '1' then
                rx_byte <= av_readdata_i(7 downto 0); rx_valid <= '1';
              end if;
              state <= IDLE;
            end if;
          when READ_CONTROL =>
            if av_waitrequest_i = '0' then
              if unsigned(av_readdata_i(31 downto 16)) /= 0 then state <= WRITE_TX;
              elsif rx_valid = '0' then state <= READ_RX;
              else state <= IDLE; end if;
            end if;
          when WRITE_TX =>
            if av_waitrequest_i = '0' then
              tx_pending <= '0';
              -- Service receive between outgoing bytes, even with TX queued.
              if rx_valid = '0' then state <= READ_RX; else state <= IDLE; end if;
            end if;
        end case;

        if req_i = '1' then
          rdata_o <= (others => '0');
          if be_i /= "1111" then fault_o <= '1';
          elsif addr_i = UART_TX_ADDR and write_i = '1' then
            if tx_pending = '0' then
              tx_byte <= wdata_i(7 downto 0); tx_pending <= '1';
            else fault_o <= '1'; end if;
          elsif addr_i = UART_RX_ADDR and write_i = '0' then
            if rx_valid = '1' then
              rdata_o(7 downto 0) <= rx_byte; rx_valid <= '0';
            else fault_o <= '1'; end if;
          elsif addr_i = UART_STATUS_ADDR and write_i = '0' then
            rdata_o(0) <= not tx_pending;
            rdata_o(1) <= rx_valid;
            rdata_o(2) <= tx_pending;
          else fault_o <= '1'; end if;
        end if;
      end if;
    end if;
  end process;
end architecture;
