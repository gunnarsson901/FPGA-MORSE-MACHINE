library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity morse_decoder is
  generic(
    CLK_HZ          : positive := 50_000_000;
    TU_MS           : positive := 120;   -- tidsenhet för Morse
    DB_MS           : positive := 10;    -- debounce
    BTN_ACTIVE_HIGH : boolean  := true
  );
  port(
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    btn_raw   : in  std_logic;
    lcd_busy  : in  std_logic;  -- tie '0' om du saknar busy
    ch_out    : out std_logic_vector(7 downto 0);
    ch_stb    : out std_logic
  );
end entity morse_decoder;

architecture rtl of morse_decoder is
  -- 1 ms tick
  constant MS_DIV : natural := CLK_HZ/1000;
  signal ms_cnt   : unsigned(31 downto 0) := (others=>'0');
  signal tick_1ms : std_logic := '0';

  -- sync + debounce
  signal s1, s2, btn_db, btn_db_d, btn_i : std_logic := '0';
  signal db_cnt : unsigned(15 downto 0) := (others=>'0');

  -- timing
  signal press_ms : unsigned(15 downto 0) := (others=>'0');
  signal gap_ms   : unsigned(15 downto 0) := (others=>'0');

  -- morse-träd
  signal node      : integer range 1 to 63 := 1;
  signal have_elem : std_logic := '0';

  -- output (FIXED - removed out_pend, using internal logic)
  signal out_data : std_logic_vector(7 downto 0) := (others=>'0');
  signal char_ready : std_logic := '0';
  signal space_ready : std_logic := '0';

  function to_ascii(c : character) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(character'pos(c), 8));
  end;

  function node_to_char(n : integer) return std_logic_vector is
  begin
    case n is
      when 2  => return to_ascii('E');
      when 3  => return to_ascii('T');
      when 4  => return to_ascii('I');
      when 5  => return to_ascii('A');
      when 6  => return to_ascii('N');
      when 7  => return to_ascii('M');
      when 8  => return to_ascii('S');
      when 9  => return to_ascii('U');
      when 10 => return to_ascii('R');
      when 11 => return to_ascii('W');
      when 12 => return to_ascii('D');
      when 13 => return to_ascii('K');
      when 14 => return to_ascii('G');
      when 15 => return to_ascii('O');
      when 16 => return to_ascii('H');
      when 17 => return to_ascii('V');
      when 18 => return to_ascii('F');
      when 20 => return to_ascii('L');
      when 22 => return to_ascii('P');
      when 23 => return to_ascii('J');
      when 24 => return to_ascii('B');
      when 25 => return to_ascii('X');
      when 26 => return to_ascii('C');
      when 27 => return to_ascii('Y');
      when 28 => return to_ascii('Z');
      when 29 => return to_ascii('Q');
      when others => return to_ascii('?');
    end case;
  end;

  function sat63(x : integer) return integer is
  begin
    if x < 1 then return 1; elsif x > 63 then return 63; else return x; end if;
  end;

  constant TU    : natural := TU_MS;
  constant GAP_C : natural := 3*TU_MS;  -- bokstavsgap
  constant GAP_W : natural := 7*TU_MS;  -- ordgap
begin
  -- 1 ms tick
  process(clk) begin
    if rising_edge(clk) then
      if rst_n='0' then
        ms_cnt   <= (others=>'0');
        tick_1ms <= '0';
      else
        if ms_cnt = to_unsigned(MS_DIV-1, ms_cnt'length) then
          ms_cnt   <= (others=>'0');
          tick_1ms <= '1';
        else
          ms_cnt   <= ms_cnt + 1;
          tick_1ms <= '0';
        end if;
      end if;
    end if;
  end process;

  -- sync + debounce
  process(clk) begin
    if rising_edge(clk) then
      if rst_n='0' then
        s1 <= '0'; s2 <= '0'; btn_db <= '0'; db_cnt <= (others=>'0');
      else
        s1 <= btn_raw;
        s2 <= s1;
        if tick_1ms='1' then
          if s2 = btn_db then
            db_cnt <= (others=>'0');
          else
            if db_cnt < to_unsigned(DB_MS, db_cnt'length) then
              db_cnt <= db_cnt + 1;
            else
              btn_db <= s2;
              db_cnt <= (others=>'0');
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- polaritet + kanter
  btn_i <= btn_db when BTN_ACTIVE_HIGH else not btn_db;

  process(clk) begin
    if rising_edge(clk) then
      if rst_n='0' then
        btn_db_d <= '0';
      else
        btn_db_d <= btn_i;
      end if;
    end if;
  end process;

  -- MAIN PROCESS - Combined timing, decoding and output (FIXED)
  process(clk) begin
    if rising_edge(clk) then
      if rst_n='0' then
        press_ms    <= (others=>'0');
        gap_ms      <= (others=>'0');
        node        <= 1;
        have_elem   <= '0';
        char_ready  <= '0';
        space_ready <= '0';
        out_data    <= (others=>'0');
        ch_out      <= (others=>'0');
        ch_stb      <= '0';
      else
        -- Default outputs
        ch_stb <= '0';
        
        -- Timing
        if tick_1ms='1' then
          if btn_i='1' then
            press_ms <= press_ms + 1;
            gap_ms   <= (others=>'0');
          else
            gap_ms   <= gap_ms + 1;
            press_ms <= (others=>'0');
          end if;
        end if;

        -- Release button → punkt/streck
        if (btn_i='0' and btn_db_d='1') then
          if to_integer(press_ms) > 0 then
            have_elem <= '1';
            if to_integer(press_ms) < (2*TU) then
              node <= sat63(2*node);        -- dot
            else
              node <= sat63(2*node + 1);    -- dash
            end if;
          end if;
        end if;

        -- Gap handling → character or space
        if tick_1ms='1' and btn_i='0' then
          if have_elem='1' and to_integer(gap_ms) >= GAP_C then
            char_ready <= '1';
            out_data <= node_to_char(node);
          elsif have_elem='0' and to_integer(gap_ms) >= GAP_W then
            space_ready <= '1';
            out_data <= to_ascii(' ');
          end if;
        end if;
        
        -- Output to LCD when ready and LCD not busy
        if lcd_busy='0' then
          if char_ready='1' then
            ch_out <= out_data;
            ch_stb <= '1';
            char_ready <= '0';
            node <= 1;
            have_elem <= '0';
            gap_ms <= (others=>'0');
          elsif space_ready='1' then
            ch_out <= out_data;
            ch_stb <= '1';
            space_ready <= '0';
            gap_ms <= (others=>'0');
          end if;
        end if;
        
      end if;
    end if;
  end process;

end architecture rtl;