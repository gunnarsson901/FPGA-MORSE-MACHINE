-- Debug version - shows button press timing and morse decoding
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_top is
  port (
    clk      : in  std_logic;
    reset_n  : in  std_logic;
    btn      : in  std_logic;     -- Button input for morse
    rs, rw, e: out std_logic;
    lcd_data : out std_logic_vector(7 downto 0);
    LEDR     : out std_logic_vector(9 downto 0)  -- Add LEDs for debug
  );
end lcd_top;

architecture rtl of lcd_top is
  signal lcd_busy    : std_logic;
  signal lcd_enable  : std_logic;
  signal lcd_bus     : std_logic_vector(9 downto 0);
  
  -- Simple morse decoder (debug version)
  signal btn_sync1, btn_sync2, btn_clean : std_logic := '0';
  signal btn_pressed, btn_released : std_logic := '0';
  signal btn_prev : std_logic := '0';
  
  -- Timing counters
  signal press_counter : unsigned(25 downto 0) := (others => '0');
  signal release_counter : unsigned(25 downto 0) := (others => '0');
  signal is_pressing : std_logic := '0';
  
  -- Morse state
  signal dots_dashes : std_logic_vector(7 downto 0) := (others => '0');
  signal pattern_length : integer range 0 to 8 := 0;
  signal char_ready : std_logic := '0';
  signal decoded_char : std_logic_vector(7 downto 0) := (others => '0');
  
  -- Welcome state
  type state_t is (WELCOME, MORSE_DEBUG, MORSE_MODE);
  signal state : state_t := WELCOME;
  signal char_index : integer range 0 to 20 := 0;
  signal delay_counter : unsigned(19 downto 0) := (others => '0');
  
  -- Welcome message: "PRESS BTN:"
  type char_array_t is array (0 to 9) of std_logic_vector(7 downto 0);
  constant WELCOME_MSG : char_array_t := (
    x"50", -- 'P'
    x"52", -- 'R'
    x"45", -- 'E'
    x"53", -- 'S'
    x"53", -- 'S'
    x"20", -- ' '
    x"42", -- 'B'
    x"54", -- 'T'
    x"4E", -- 'N'
    x"3A"  -- ':'
  );
  
  -- Simple morse lookup (just a few letters for testing)
  function morse_to_ascii(pattern : std_logic_vector(7 downto 0); len : integer) return std_logic_vector is
  begin
    case len is
      when 1 =>
        if pattern(0) = '0' then return x"45"; -- E (.)
        else return x"54"; -- T (-)
        end if;
      when 2 =>
        if pattern(1 downto 0) = "00" then return x"49"; -- I (..)
        elsif pattern(1 downto 0) = "10" then return x"41"; -- A (.-)
        elsif pattern(1 downto 0) = "01" then return x"4E"; -- N (-.)
        else return x"4D"; -- M (--)
        end if;
      when 3 =>
        if pattern(2 downto 0) = "000" then return x"53"; -- S (...)
        elsif pattern(2 downto 0) = "100" then return x"55"; -- U (..-) 
        elsif pattern(2 downto 0) = "010" then return x"52"; -- R (.-.)
        elsif pattern(2 downto 0) = "110" then return x"57"; -- W (.--) 
        elsif pattern(2 downto 0) = "001" then return x"44"; -- D (-..)
        elsif pattern(2 downto 0) = "101" then return x"4B"; -- K (-.-) 
        elsif pattern(2 downto 0) = "011" then return x"47"; -- G (--..)
        else return x"4F"; -- O (---)
        end if;
      when others =>
        return x"3F"; -- '?' for unknown
    end case;
  end function;
  
begin
  -- LCD Controller
  u1: entity work.lcd_controller
    port map (
      clk        => clk,
      reset_n    => reset_n,
      lcd_enable => lcd_enable,
      lcd_bus    => lcd_bus,
      busy       => lcd_busy,
      rw         => rw,
      rs         => rs,
      e          => e,
      lcd_data   => lcd_data,
      lcd_on     => open,
      lcd_blon   => open
    );

  -- Debug LEDs
  LEDR(0) <= btn_clean;           -- Current button state
  LEDR(1) <= btn_pressed;         -- Button press edge
  LEDR(2) <= btn_released;        -- Button release edge  
  LEDR(3) <= is_pressing;         -- Currently pressing
  LEDR(4) <= char_ready;          -- Character decoded
  LEDR(7 downto 5) <= std_logic_vector(to_unsigned(pattern_length, 3)); -- Pattern length
  LEDR(9 downto 8) <= (others => '0');

  -- Button synchronizer and edge detection
  process(clk)
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        btn_sync1 <= '0';
        btn_sync2 <= '0';
        btn_clean <= '0';
        btn_prev <= '0';
        btn_pressed <= '0';
        btn_released <= '0';
      else
        -- Synchronize button (DE0-CV buttons are active LOW)
        btn_sync1 <= not btn;  -- Invert for active-low button
        btn_sync2 <= btn_sync1;
        btn_clean <= btn_sync2;
        
        -- Edge detection
        btn_prev <= btn_clean;
        btn_pressed <= btn_clean and not btn_prev;    -- Rising edge
        btn_released <= not btn_clean and btn_prev;   -- Falling edge
      end if;
    end if;
  end process;

  -- Simple morse decoder with timing
  process(clk)
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        press_counter <= (others => '0');
        release_counter <= (others => '0');
        is_pressing <= '0';
        dots_dashes <= (others => '0');
        pattern_length <= 0;
        char_ready <= '0';
        decoded_char <= (others => '0');
      else
        char_ready <= '0';  -- Default
        
        -- Button press timing
        if btn_pressed = '1' then
          is_pressing <= '1';
          press_counter <= (others => '0');
          release_counter <= (others => '0');
        elsif btn_released = '1' then
          is_pressing <= '0';
          
          -- Decode dot or dash based on press duration
          -- Short press < 25M cycles (~0.5s), long press >= 25M cycles
          if pattern_length < 8 then
            if press_counter < x"1800000" then -- ~0.5s at 50MHz
              dots_dashes(pattern_length) <= '0'; -- Dot
            else
              dots_dashes(pattern_length) <= '1'; -- Dash  
            end if;
            pattern_length <= pattern_length + 1;
          end if;
          
          press_counter <= (others => '0');
          release_counter <= (others => '0');
        end if;
        
        -- Count press/release time
        if is_pressing = '1' then
          press_counter <= press_counter + 1;
        else
          release_counter <= release_counter + 1;
          
          -- End character after ~1 second of no press
          if release_counter = x"3000000" and pattern_length > 0 then -- ~1s
            decoded_char <= morse_to_ascii(dots_dashes, pattern_length);
            char_ready <= '1';
            pattern_length <= 0;
            dots_dashes <= (others => '0');
            release_counter <= (others => '0');
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Main display control
  process(clk)
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        state <= WELCOME;
        char_index <= 0;
        delay_counter <= (others => '0');
        lcd_enable <= '0';
        lcd_bus <= (others => '0');
      else
        lcd_enable <= '0';  -- Default
        delay_counter <= delay_counter + 1;
        
        case state is
          when WELCOME =>
            -- Send welcome message
            if lcd_busy = '0' and delay_counter = 0 then
              if char_index <= 9 then
                lcd_enable <= '1';
                lcd_bus(9) <= '1';  -- RS = 1 (data)
                lcd_bus(8) <= '0';  -- RW = 0 (write)
                lcd_bus(7 downto 0) <= WELCOME_MSG(char_index);
                char_index <= char_index + 1;
              else
                state <= MORSE_MODE;
              end if;
            end if;
            
          when MORSE_MODE =>
            -- Display decoded characters
            if char_ready = '1' and lcd_busy = '0' then
              lcd_enable <= '1';
              lcd_bus(9) <= '1';              -- RS = 1 (data)
              lcd_bus(8) <= '0';              -- RW = 0 (write)
              lcd_bus(7 downto 0) <= decoded_char;
            end if;
            
          when others =>
            state <= WELCOME;
        end case;
      end if;
    end if;
  end process;

end rtl;

-- TESTING GUIDE:
-- 1. Should see "PRESS BTN:" message
-- 2. Watch LEDs while pressing button:
--    - LEDR[0] = button state (should follow your presses)
--    - LEDR[1] = press edge (flash on press)  
--    - LEDR[2] = release edge (flash on release)
--    - LEDR[3] = currently pressing
--    - LEDR[7:5] = pattern length (how many dots/dashes stored)
-- 3. Try simple patterns:
--    - Single short press, wait 1 second → should show 'E'
--    - Single long press, wait 1 second → should show 'T'
--    - Short-long, wait 1 second → should show 'A'