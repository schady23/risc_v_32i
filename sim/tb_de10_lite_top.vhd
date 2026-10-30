library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;
use std.env.all;
use work.rv32i_pkg.all;
use work.jtag_uart_sim_pkg.all;

entity tb_de10_lite_top is
  generic (
    IMAGE_FILE : string := "sim/images/hello.hex";
    APP_MESSAGE : string := "Hello from uploaded RV32I assembly!";
    APP_EXIT : string := "0000002A"
  );
end entity;
architecture test of tb_de10_lite_top is
  signal clk : std_logic := '0';
  signal keys : std_logic_vector(1 downto 0) := "10";
  constant CRLF : string := character'val(13) & character'val(10);
begin
  clk <= not clk after 10 ns;
  dut : entity work.de10_lite_top port map (MAX10_CLK1_50 => clk, KEY => keys);
  process
    type words_t is array (0 to 3071) of word_t;
    variable image : words_t;
    variable count : natural := 0;
    file file_image : text open read_mode is IMAGE_FILE;
    variable line_value : line;
    variable crc : unsigned(31 downto 0) := (others => '1');
    procedure send_byte(constant value : natural) is
    begin
      wait until falling_edge(clk);
      host_rx_data <= std_logic_vector(to_unsigned(value, 8)); host_rx_valid <= '1';
      loop wait until rising_edge(clk); exit when host_rx_ready = '1'; end loop;
      host_rx_valid <= '0';
    end procedure;
    procedure send_u32(constant value : unsigned(31 downto 0)) is
    begin
      for index in 0 to 3 loop send_byte(to_integer(value(index*8+7 downto index*8))); end loop;
    end procedure;
    procedure expect_text(constant expected : string) is
    begin
      for index in expected'range loop
        host_tx_ready <= '1';
        loop wait until rising_edge(clk); exit when host_tx_valid = '1'; end loop;
        assert to_integer(unsigned(host_tx_data)) = character'pos(expected(index))
          report "JTAG text mismatch at " & integer'image(index) & ": got " & to_hstring(host_tx_data) &
                 ", expected " & character'image(expected(index)) severity failure;
        host_tx_ready <= '0';
      end loop;
    end procedure;
    procedure load_image(constant corrupt : boolean := false) is
      variable checksum : unsigned(31 downto 0);
      variable byte_value : natural;
    begin
      send_byte(character'pos('L')); send_u32(to_unsigned(count*4, 32));
      checksum := crc;
      if corrupt then checksum(0) := not checksum(0); end if;
      send_u32(checksum); expect_text("SEND" & CRLF);
      for index in 0 to count*4-1 loop
        byte_value := to_integer(unsigned(image(index/4)((index mod 4)*8+7 downto (index mod 4)*8)));
        send_byte(byte_value);
        if index mod 32 = 31 or index = count*4-1 then expect_text("+"); end if;
      end loop;
      if corrupt then expect_text(CRLF & "ERR crc" & CRLF & "ready> ");
      else expect_text(CRLF & "LOADED" & CRLF & "ready> "); end if;
    end procedure;
  begin
    host_tx_ready <= '0';
    while not endfile(file_image) loop
      readline(file_image, line_value); hread(line_value, image(count)); count := count + 1;
    end loop;
    for index in 0 to count*4-1 loop
      crc := crc xor resize(unsigned(image(index/4)((index mod 4)*8+7 downto (index mod 4)*8)), 32);
      for bit_index in 0 to 7 loop
        if crc(0) = '1' then crc := shift_right(crc, 1) xor x"EDB88320";
        else crc := shift_right(crc, 1); end if;
      end loop;
    end loop;
    crc := not crc;
    wait for 100 ns; keys(0) <= '1';
    expect_text("RV32I JTAG loader v1" & CRLF & "ready> ");
    send_byte(character'pos('G')); expect_text("ERR no image" & CRLF & "ready> ");
    send_byte(character'pos('?')); expect_text("L: upload; G: run; ?: help" & CRLF & "ready> ");
    -- Invalid sizes must not enable execution or touch the reserved stacks.
    for bad_size in 0 to 2 loop
      send_byte(character'pos('L'));
      case bad_size is
        when 0 => send_u32(to_unsigned(0, 32));
        when 1 => send_u32(to_unsigned(12292, 32));
        when others => send_u32(to_unsigned(3, 32));
      end case;
      send_u32(to_unsigned(0, 32)); expect_text("ERR size" & CRLF & "ready> ");
    end loop;
    load_image;
    for run_index in 1 to 2 loop
      send_byte(character'pos('G'));
      expect_text("RUN" & CRLF & APP_MESSAGE & CRLF &
                  "EXIT " & APP_EXIT & CRLF & "ready> ");
    end loop;
    load_image(true);
    send_byte(character'pos('G')); expect_text("ERR no image" & CRLF & "ready> ");
    load_image;
    send_byte(character'pos('G'));
    expect_text("RUN" & CRLF & APP_MESSAGE & CRLF &
                "EXIT " & APP_EXIT & CRLF & "ready> ");
    -- Interrupt a new upload; reset clears loader authorization and IP FIFOs.
    send_byte(character'pos('L')); send_u32(to_unsigned(count*4, 32)); send_u32(crc);
    expect_text("SEND" & CRLF); send_byte(16#FF#);
    keys(0) <= '0'; wait for 100 ns; keys(0) <= '1';
    expect_text("RV32I JTAG loader v1" & CRLF & "ready> ");
    send_byte(character'pos('G')); expect_text("ERR no image" & CRLF & "ready> ");
    report "tb_de10_lite_top passed: " & IMAGE_FILE &
           ", upload/CRC, RAM execution, return/re-run, reset" severity note;
    stop; wait;
  end process;
  process begin wait for 30 ms; assert false report "JTAG loader timeout" severity failure; end process;
end architecture;
