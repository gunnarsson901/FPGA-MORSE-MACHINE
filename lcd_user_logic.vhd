-- morse_decoder.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity morse_decoder is
  generic (
    G_CLK_HZ     : integer := 50_000_000;  -- system clock
    G_UNIT_MS    : integer := 120          -- Morse tidsenhet (justera: 80–150 ms)
  );
  port (
    clk         : in  std_logic;
    reset_n     : in  std_logic;
    btn         : in  std_logic;                     -- aktiv hög knapp
    busy        : in  std_logic;                     -- från lcd_controller
    lcd_enable  : out std_logic;                     -- till lcd_controller
    lcd_bus     : out std_logic_vector(9 downto 0)   -- [9]=RS, [8]=RW, [7:0]=DATA
  );
end entity;

architecture rtl of morse_decoder is
  -- Tidskonstanter i klockcykler
  constant C_UNIT      : integer := (G_CLK_HZ / 1000) * G_UNIT_MS;      -- 1 enhet
  constant C_DOT_MAX   : integer := C_UNIT * 1;                          -- punkt <= 1U
  constant C_DASH_MIN  : integer := C_UNIT * 2;                          -- streck >= 2U
  constant C_CHAR_GAP  : integer := C_UNIT * 3;                          -- teckenpaus
  constant C_WORD_GAP  : integer := C_UNIT * 7;                          -- ordpaus

  -- Debounce
  signal btn_sync  : std_logic_vector(2 downto 0) := (others => '0');
  signal btn_stable: std_logic := '0';
  signal btn_prev  : std_logic := '0';

  -- Mätare
  signal press_cnt : integer := 0;
  signal gap_cnt   : integer := 0;

  -- Morse ackumulator
  signal sym_bits  : std_logic_vector(5 downto 0) := (others => '0'); -- upp till 6 symboler
  signal sym_len   : integer range 0 to 6 := 0;

  -- Sändning
  signal pend_char : std_logic_vector(7 downto 0) := (others => '0');
  signal have_char : std_logic := '0';
  signal en_pulse  : std_logic := '0';

  function decode_morse(len : integer; bits : std_logic_vector(5 downto 0))
    return std_logic_vector is
    -- bit 0 är första symbolen: '0'=dot, '1'=dash
    -- Exempel: A = .-  => len=2, bits="10" (LSB först: bit0='0', bit1='1')
    variable ch : std_logic_vector(7 downto 0) := x"3F"; -- '?'
  begin
    case len is
      when 1 =>
        case bits(0) is
          when '0' => ch := x"45"; -- E
          when '1' => ch := x"54"; -- T
          when others => null;
        end case;

      when 2 =>
        case bits(1 downto 0) is
          when "01" => ch := x"41"; -- A .-
          when "00" => ch := x"49"; -- I ..
          when "10" => ch := x"4D"; -- M --
          when "11" => ch := x"4E"; -- N -.
          when others => null;
        end case;

      when 3 =>
        case bits(2 downto 0) is
          when "001" => ch := x"55"; -- U ..-
          when "000" => ch := x"53"; -- S ...
          when "011" => ch := x"52"; -- R .-.
          when "010" => ch := x"57"; -- W .--
          when "110" => ch := x"44"; -- D -..
          when "100" => ch := x"47"; -- G --.
          when "111" => ch := x"4B"; -- K -.-
          when "101" => ch := x"4F"; -- O ---
          when others => null;
        end case;

      when 4 =>
        case bits(3 downto 0) is
          when "0001" => ch := x"48"; -- H ....
          when "0000" => ch := x"53"; -- S already, but keep for completeness
          when "0010" => ch := x"56"; -- V ...-
          when "0011" => ch := x"46"; -- F ..-.
          when "0100" => ch := x"4C"; -- L .-..
          when "0101" => ch := x"50"; -- P .--.
          when "0110" => ch := x"4A"; -- J .---
          when "1000" => ch := x"42"; -- B -...
          when "1001" => ch := x"58"; -- X -..-
          when "1010" => ch := x"43"; -- C -.-.
          when "1011" => ch := x"59"; -- Y -.--
          when "1100" => ch := x"5A"; -- Z --..
          when "1101" => ch := x"51"; -- Q --.-
          when others => null;
        end case;

      when 5 =>
        case bits(4 downto 0) is
          when "01111" => ch := x"31"; -- 1 .----
          when "00111" => ch := x"32"; -- 2 ..---
          when "00011" => ch := x"33"; -- 3 ...--
          when "00001" => ch := x"34"; -- 4 ....-
          when "00000" => ch := x"35"; -- 5 .....
          when "10000" => ch := x"36"; -- 6 -....
          when "11000" => ch := x"37"; -- 7 --...
          when "11100" => ch := x"38"; -- 8 ---..
          when "11110" => ch := x"39"; -- 9 ----.
          when "11111" => ch := x"30"; -- 0 -----
          when others => null;
        end case;

      when others => null;
    end case;
    return ch;
  end function;

begin
  -- outputs
  lcd_bus    <= '1' & '0' & pend_char; -- RS=1 (data), RW=0, DATA=ASCII
  lcd_enable <= en_pulse;

  -- synk och debounce
  process(clk)
    variable cnt : integer := 0;
    constant DBN : integer := G_CLK_HZ / 2000; -- ~0.5 ms
  begin
    if rising_edge(clk) then
      btn_sync <= btn_sync(1 downto 0) & btn;

      if btn_sync(2) = btn_stable then
        cnt := 0;
      else
        cnt := cnt + 1;
        if cnt > DBN then
          btn_stable <= btn_sync(2);
          cnt := 0;
        end if;
      end if;
    end if;
  end process;

  -- huvudlogik
  process(clk)
  begin
    if rising_edge(clk) then
      en_pulse <= '0';

      if reset_n = '0' then
        press_cnt  <= 0;
        gap_cnt    <= 0;
        sym_bits   <= (others => '0');
        sym_len    <= 0;
        pend_char  <= (others => '0');
        have_char  <= '0';
        btn_prev   <= '0';

      else
        -- mät press/gap
        if btn_stable = '1' then
          press_cnt <= press_cnt + 1;
          gap_cnt   <= 0;
        else
          gap_cnt   <= gap_cnt + 1;
          if btn_prev = '1' then
            -- släpphändelse: klassificera punkt/streck
            if sym_len < 6 then
              if press_cnt <= C_DOT_MAX then
                sym_bits(sym_len) <= '0';      -- dot
              else
                sym_bits(sym_len) <= '1';      -- dash
              end if;
              sym_len <= sym_len + 1;
            end if;
            press_cnt <= 0;
          end if;
        end if;

        -- teckenpaus tolkning
        if (btn_stable = '0') and (sym_len > 0) then
          if gap_cnt >= C_CHAR_GAP then
            pend_char <= decode_morse(sym_len, sym_bits);
            have_char <= '1';
            sym_bits  <= (others => '0');
            sym_len   <= 0;
          end if;
        end if;

        -- skicka när LCD är ledig
        if (have_char = '1') and (busy = '0') then
          en_pulse  <= '1';     -- en cykel hög
          have_char <= '0';
        end if;

        btn_prev <= btn_stable;
      end if;
    end if;
  end process;
end architecture;
