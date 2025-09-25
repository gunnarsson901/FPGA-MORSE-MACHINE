library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity morse_decoder is
  generic(
    CLK_HZ          : positive := 50_000_000;
    TU_MS           : positive := 120;
    DB_MS           : positive := 10;
    BTN_ACTIVE_HIGH : boolean  := false
  );
  port(
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    btn_raw   : in  std_logic;
    lcd_busy  : in  std_logic;
    ch_out    : out std_logic_vector(7 downto 0);
    ch_stb    : out std_logic
  );
end entity morse_decoder;

architecture rtl of morse_decoder is
  -- Very simple button debouncing - just 3 flip-flops
  signal btn1, btn2, btn3 : std_logic := '0';
  signal btn_clean, btn_prev : std_logic := '0';
  
  -- Super simple timing - just count clock cycles directly
  signal press_count : unsigned(31 downto 0) := (others => '0');
  signal gap_count : unsigned(31 downto 0) := (others => '0');
  signal pressing : std_logic := '0';
  
  -- Morse pattern - keep it really simple
  signal dots_dashes : std_logic_vector(7 downto 0) := (others => '0');
  signal num_elements : integer range 0 to 8 := 0;
  
  -- Very generous timing constants (clock cycles at 50MHz)
  constant SHORT_THRESHOLD : natural := 10_000_000;  -- 0.2 seconds - very short!
  constant CHAR_TIMEOUT    : natural := 50_000_000;  -- 1.0 seconds - quick timeout
  constant SPACE_TIMEOUT   : natural := 100_000_000; -- 2.0 seconds
  
  -- Output control
  signal output_char : std_logic_vector(7 downto 0) := (others => '0');
  signal send_char : std_logic := '0';
  
begin

  -- Ultra-simple button sync (no fancy debouncing)
  process(clk)
  begin
    if rising_edge(clk) then
      btn1 <= not btn_raw;  -- Invert for active-low
      btn2 <= btn1;
      btn3 <= btn2;
      btn_clean <= btn3;
    end if;
  end process;
  
  -- Main process - keep everything in one place
  process(clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        btn_prev <= '0';
        press_count <= (others => '0');
        gap_count <= (others => '0');
        pressing <= '0';
        dots_dashes <= (others => '0');
        num_elements <= 0;
        output_char <= (others => '0');
        send_char <= '0';
        ch_out <= (others => '0');
        ch_stb <= '0';
      else
        -- Default outputs
        send_char <= '0';
        ch_stb <= '0';
        btn_prev <= btn_clean;
        
        -- Button press detected
        if btn_clean = '1' and btn_prev = '0' then
          pressing <= '1';
          press_count <= (others => '0');
          gap_count <= (others => '0');
        end if;
        
        -- Button release detected
        if btn_clean = '0' and btn_prev = '1' then
          pressing <= '0';
          
          -- Add dot or dash based on press duration
          if num_elements < 8 then
            if press_count < SHORT_THRESHOLD then
              dots_dashes(num_elements) <= '0';  -- Dot
            else
              dots_dashes(num_elements) <= '1';  -- Dash
            end if;
            num_elements <= num_elements + 1;
          end if;
          
          press_count <= (others => '0');
          gap_count <= (others => '0');
        end if;
        
        -- Count time
        if pressing = '1' then
          press_count <= press_count + 1;
        else
          gap_count <= gap_count + 1;
        end if;
        
        -- Character timeout - decode pattern
        if pressing = '0' and num_elements > 0 and gap_count >= CHAR_TIMEOUT then
          send_char <= '1';
          gap_count <= (others => '0');
          
          -- Simple decode - just handle most common patterns
          case num_elements is
            when 1 =>
              if dots_dashes(0) = '0' then
                output_char <= x"45";  -- E
              else
                output_char <= x"54";  -- T
              end if;
            when 2 =>
              case dots_dashes(1 downto 0) is
                when "00" => output_char <= x"49";  -- I
                when "01" => output_char <= x"41";  -- A
                when "10" => output_char <= x"4E";  -- N
                when "11" => output_char <= x"4D";  -- M
                when others => output_char <= x"3F";  -- ?
              end case;
            when 3 =>
              case dots_dashes(2 downto 0) is
                when "000" => output_char <= x"53";  -- S
                when "001" => output_char <= x"55";  -- U
                when "010" => output_char <= x"52";  -- R
                when "011" => output_char <= x"57";  -- W
                when "100" => output_char <= x"44";  -- D
                when "101" => output_char <= x"4B";  -- K
                when "110" => output_char <= x"47";  -- G
                when "111" => output_char <= x"4F";  -- O
                when others => output_char <= x"3F";  -- ?
              end case;
            when others =>
              output_char <= x"3F";  -- ? for longer patterns
          end case;
          
          -- Reset pattern
          dots_dashes <= (others => '0');
          num_elements <= 0;
        end if;
        
        -- Send space for very long gaps
        if pressing = '0' and num_elements = 0 and gap_count >= SPACE_TIMEOUT then
          send_char <= '1';
          output_char <= x"20";  -- Space
          gap_count <= (others => '0');
        end if;
        
        -- Output to LCD when ready
        if send_char = '1' and lcd_busy = '0' then
          ch_out <= output_char;
          ch_stb <= '1';
        end if;
        
      end if;
    end if;
  end process;

end architecture rtl;

-- HARDWARE FIXES TO TRY:
-- 1. Remove 220Ω resistor completely (use internal pull-up)
-- 2. Or replace with 4.7kΩ resistor
-- 
-- NEW TIMING (Very Forgiving):
-- - Dot: < 0.2 seconds (very short press)
-- - Dash: ≥ 0.2 seconds (any longer press)
-- - Character end: 1.0 second pause
-- - Space: 2.0 second pause
--
-- TEST PATTERNS:
-- E: Very quick tap, wait 1+ seconds
-- T: Hold for 0.5+ seconds, wait 1+ seconds  
-- A: Quick tap, pause, long press, wait 1+ seconds