-- Debug version - shows button press timing and morse decoding
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_top is
  port (
    clk      : in  std_logic;
    reset_n  : in  std_logic;
    btn      : in  std_logic;     -- Button input for morse
    btn_clear: in  std_logic;     -- Button input for clear
    btn_space: in  std_logic;     -- Button input for space
    btn_enter: in  std_logic;     -- Button input for new line
    buzzer   : out std_logic;     -- Passive buzzer output
    rs, rw, e: out std_logic;
    lcd_data : out std_logic_vector(7 downto 0);
    LEDR     : out std_logic_vector(9 downto 0)  -- Add LEDs for debug
  );
end lcd_top;

architecture rtl of lcd_top is
  -- Timing Constants for 50MHz Clock
  -- Dot vs Dash Threshold: 0.25 seconds (12.5M cycles)
  constant THRESHOLD_DOT_DASH : unsigned(31 downto 0) := to_unsigned(12_500_000, 32); 
  
  -- Character Gap Threshold: 0.6 seconds (30M cycles)
  constant THRESHOLD_CHAR_GAP : unsigned(31 downto 0) := to_unsigned(30_000_000, 32);

  -- Noise Threshold: 20ms (1M cycles) to ignore button bounce
  constant THRESHOLD_NOISE    : unsigned(31 downto 0) := to_unsigned(1_000_000, 32);

  -- Buzzer Divider (1kHz tone)
  constant TONE_DIVIDER : integer := 25000; -- 50MHz / 25000 / 2 = 1kHz

  signal lcd_busy    : std_logic;
  signal lcd_enable  : std_logic;
  signal lcd_bus     : std_logic_vector(9 downto 0);
  
  -- Button Sync
  signal btn_morse_r : std_logic_vector(2 downto 0) := (others => '0');
  signal btn_clear_r : std_logic_vector(2 downto 0) := (others => '0');
  signal btn_space_r : std_logic_vector(2 downto 0) := (others => '0');
  signal btn_enter_r : std_logic_vector(2 downto 0) := (others => '0');
  
  signal btn_morse_pressed  : std_logic;
  signal btn_morse_released : std_logic;
  signal btn_clear_pressed  : std_logic;
  signal btn_space_pressed  : std_logic;
  signal btn_enter_pressed  : std_logic;
  
  signal morse_key_state : std_logic;
  
  -- Timing counters
  signal press_counter   : unsigned(31 downto 0) := (others => '0');
  signal release_counter : unsigned(31 downto 0) := (others => '0');
  signal is_pressing     : std_logic := '0';
  
  -- Buzzer
  signal pwm_counter : unsigned(15 downto 0) := (others => '0');
  signal buzzer_tone : std_logic := '0';

  -- Morse state
  signal dots_dashes    : std_logic_vector(7 downto 0) := (others => '0');
  signal pattern_length : integer range 0 to 8 := 0;
  signal char_ready     : std_logic := '0';
  signal decoded_char   : std_logic_vector(7 downto 0) := (others => '0');
  
  -- State Machine
  type state_t is (WAIT_BOOT, WELCOME, WELCOME_WAIT, IDLE, SEND_CHAR, SEND_CLEAR, SEND_SPACE, SEND_ENTER);
  signal state : state_t := WAIT_BOOT;
  signal char_index : integer range 0 to 20 := 0;
  
  signal current_row : std_logic := '0'; -- 0=Line 1, 1=Line 2
  
  -- Welcome message: "MORSE RDY"
  type char_array_t is array (0 to 8) of std_logic_vector(7 downto 0);
  constant WELCOME_MSG : char_array_t := (
    x"4D", -- M
    x"4F", -- O
    x"52", -- R
    x"53", -- S
    x"45", -- E
    x"20", -- Space
    x"52", -- R
    x"44", -- D
    x"59"  -- Y
  );
  
  function morse_to_ascii(pattern : std_logic_vector(7 downto 0); len : integer) return std_logic_vector is
  begin
    case len is
      when 1 =>
        if pattern(0) = '0' then return x"45"; -- E (.)
        else return x"54"; -- T (-)
        end if;
      when 2 =>
        case pattern(1 downto 0) is
          when "00" => return x"49"; -- I (..)
          when "10" => return x"41"; -- A (.-)
          when "01" => return x"4E"; -- N (-.)
          when "11" => return x"4D"; -- M (--)
          when others => return x"3F";
        end case;
      when 3 =>
        case pattern(2 downto 0) is
          when "000" => return x"53"; -- S (...)
          when "100" => return x"55"; -- U (..-) 
          when "010" => return x"52"; -- R (.-.)
          when "110" => return x"57"; -- W (.--) 
          when "001" => return x"44"; -- D (-..)
          when "101" => return x"4B"; -- K (-.-) 
          when "011" => return x"47"; -- G (--..)
          when "111" => return x"4F"; -- O (---)
          when others => return x"3F";
        end case;
      when 4 =>
        case pattern(3 downto 0) is
          when "0000" => return x"48"; -- H (....)
          when "1000" => return x"56"; -- V (...-)
          when "0100" => return x"46"; -- F (..-.)
          when "0010" => return x"4C"; -- L (.-..)
          when "0110" => return x"50"; -- P (.--.)
          when "0111" => return x"4A"; -- J (.---)
          when "0001" => return x"42"; -- B (-...)
          when "1001" => return x"58"; -- X (-..-)
          when "0101" => return x"43"; -- C (-.-.)
          when "1101" => return x"59"; -- Y (-.--)
          when "1110" => return x"51"; -- Q (--.-)
          when "0011" => return x"5A"; -- Z (--..)
          when others => return x"3F";
        end case;
      when 5 =>
        case pattern(4 downto 0) is
          when "11110" => return x"31"; -- 1 .----
          when "11100" => return x"32"; -- 2 ..---
          when "11000" => return x"33"; -- 3 ...--
          when "10000" => return x"34"; -- 4 ....-
          when "00000" => return x"35"; -- 5 .....
          when "00001" => return x"36"; -- 6 -....
          when "00011" => return x"37"; -- 7 --...
          when "00111" => return x"38"; -- 8 ---..
          when "01111" => return x"39"; -- 9 ----.
          when "11111" => return x"30"; -- 0 -----
          when "10110" => return x"2F"; -- / -..-.
          when others => return x"3F";
        end case;
      when 6 =>
        case pattern(5 downto 0) is
          when "101010" => return x"2E"; -- . .-.-.-
          when "110011" => return x"2C"; -- , --..--
          when "001100" => return x"3F"; -- ? ..--..
          when "010110" => return x"40"; -- @ .--.-.
          when others => return x"3F";
        end case;
      when others =>
        return x"3F"; -- '?'
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

  buzzer <= buzzer_tone;

  -- Debug LEDs
  LEDR(0) <= morse_key_state;
  LEDR(1) <= btn_morse_pressed;
  LEDR(2) <= btn_morse_released;
  LEDR(3) <= btn_clear_pressed;
  LEDR(4) <= char_ready;
  LEDR(7 downto 5) <= std_logic_vector(to_unsigned(pattern_length, 3));
  LEDR(8) <= btn_space_pressed or btn_enter_pressed;
  LEDR(9) <= current_row;

  -- Button Sync
  process(clk)
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        btn_morse_r <= (others => '0');
        btn_clear_r <= (others => '0');
        btn_space_r <= (others => '0');
        btn_enter_r <= (others => '0');
        
        btn_morse_pressed <= '0';
        btn_morse_released <= '0';
        btn_clear_pressed <= '0';
        btn_space_pressed <= '0';
        btn_enter_pressed <= '0';
        morse_key_state <= '0';
      else
        -- Shift (Active Low inputs inverted)
        btn_morse_r <= btn_morse_r(1 downto 0) & (not btn);
        btn_clear_r <= btn_clear_r(1 downto 0) & (not btn_clear);
        btn_space_r <= btn_space_r(1 downto 0) & (not btn_space);
        btn_enter_r <= btn_enter_r(1 downto 0) & (not btn_enter);
        
        morse_key_state <= btn_morse_r(2);
        
        -- Edges (using r2 as stable state)
        -- Morse Button
        if btn_morse_r(2) = '0' and btn_morse_r(1) = '1' then
           btn_morse_pressed <= '1';
        else
           btn_morse_pressed <= '0';
        end if;
        
        if btn_morse_r(2) = '1' and btn_morse_r(1) = '0' then
           btn_morse_released <= '1';
        else
           btn_morse_released <= '0';
        end if;
        
        -- Control Buttons (Pressed Edge)
        if btn_clear_r(2) = '0' and btn_clear_r(1) = '1' then
           btn_clear_pressed <= '1';
        else
           btn_clear_pressed <= '0';
        end if;
        
        if btn_space_r(2) = '0' and btn_space_r(1) = '1' then
           btn_space_pressed <= '1';
        else
           btn_space_pressed <= '0';
        end if;

        if btn_enter_r(2) = '0' and btn_enter_r(1) = '1' then
           btn_enter_pressed <= '1';
        else
           btn_enter_pressed <= '0';
        end if;
        
      end if;
    end if;
  end process;

  -- Buzzer Process
  process(clk)
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        pwm_counter <= (others => '0');
        buzzer_tone <= '0';
      else
        if is_pressing = '1' then
          if pwm_counter < TONE_DIVIDER then
             pwm_counter <= pwm_counter + 1;
          else
             pwm_counter <= (others => '0');
             buzzer_tone <= not buzzer_tone;
          end if;
        else
          buzzer_tone <= '0';
          pwm_counter <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  -- Morse Logic
  process(clk)
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        press_counter <= (others => '0');
        release_counter <= (others => '0');
        is_pressing <= '0';
        pattern_length <= 0;
        dots_dashes <= (others => '0');
        char_ready <= '0';
        decoded_char <= (others => '0');
      else
        char_ready <= '0';
        
        if btn_morse_pressed = '1' then
           is_pressing <= '1';
           press_counter <= (others => '0');
           release_counter <= (others => '0');
        elsif btn_morse_released = '1' then
           is_pressing <= '0';
           
           -- Only register if press was longer than noise threshold
           if press_counter > THRESHOLD_NOISE then
             if pattern_length < 8 then
               if press_counter < THRESHOLD_DOT_DASH then
                  dots_dashes(pattern_length) <= '0'; -- Dot
               else
                  dots_dashes(pattern_length) <= '1'; -- Dash
               end if;
               pattern_length <= pattern_length + 1;
             end if;
           end if;
           
           press_counter <= (others => '0');
           release_counter <= (others => '0');
        end if;
        
        if is_pressing = '1' then
           press_counter <= press_counter + 1;
        else
           release_counter <= release_counter + 1;
           
           if release_counter = THRESHOLD_CHAR_GAP and pattern_length > 0 then
              decoded_char <= morse_to_ascii(dots_dashes, pattern_length);
              char_ready <= '1';
              pattern_length <= 0;
              dots_dashes <= (others => '0');
           end if;
        end if;
      end if;
    end if;
  end process;

  -- Display Control
  process(clk)
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        state <= WAIT_BOOT;
        lcd_enable <= '0';
        lcd_bus <= (others => '0');
        char_index <= 0;
        current_row <= '0';
      else
        lcd_enable <= '0';
        
        case state is
          when WAIT_BOOT =>
            if lcd_busy = '0' then
               state <= WELCOME;
               char_index <= 0;
            end if;
            
          when WELCOME =>
            if lcd_busy = '0' then
               if char_index <= 8 then
                  lcd_enable <= '1';
                  lcd_bus <= '1' & '0' & WELCOME_MSG(char_index); -- RS=1, RW=0
                  state <= WELCOME_WAIT;
               else
                  state <= IDLE;
               end if;
            end if;

          when WELCOME_WAIT =>
            if lcd_busy = '1' then
               char_index <= char_index + 1;
               state <= WELCOME;
            end if;
            
          when IDLE =>
            if btn_clear_pressed = '1' then
               current_row <= '0'; -- Reset to line 1
               state <= SEND_CLEAR;
            elsif btn_space_pressed = '1' then
               state <= SEND_SPACE;
            elsif btn_enter_pressed = '1' then
               current_row <= not current_row; -- Toggle Row
               state <= SEND_ENTER;
            elsif char_ready = '1' then
               state <= SEND_CHAR;
            end if;
            
          when SEND_CHAR =>
            if lcd_busy = '0' then
               lcd_enable <= '1';
               lcd_bus <= '1' & '0' & decoded_char;
               state <= IDLE;
            end if;
            
          when SEND_SPACE =>
            if lcd_busy = '0' then
               lcd_enable <= '1';
               lcd_bus <= '1' & '0' & x"20"; -- Data Space
               state <= IDLE;
            end if;

          when SEND_ENTER =>
            if lcd_busy = '0' then
               lcd_enable <= '1';
               -- Set DDRAM Address: Command 0x80
               -- Line 1: 0x00 -> 0x80
               -- Line 2: 0x40 -> 0xC0
               if current_row = '1' then -- Target is Line 2 (we just toggled)
                  lcd_bus <= '0' & '0' & x"C0";
               else
                  lcd_bus <= '0' & '0' & x"80";
               end if;
               state <= IDLE;
            end if;
            
          when SEND_CLEAR =>
            if lcd_busy = '0' then
               lcd_enable <= '1';
               lcd_bus <= '0' & '0' & x"01"; -- RS=0, RW=0, Clear
               state <= IDLE;
            end if;
            
          when others =>
            state <= IDLE;
        end case;
      end if;
    end if;
  end process;

end rtl;
