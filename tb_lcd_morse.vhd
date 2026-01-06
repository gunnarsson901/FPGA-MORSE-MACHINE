library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_lcd_morse is
end entity;

architecture sim of tb_lcd_morse is

  signal clk       : std_logic := '0';
  signal reset_n   : std_logic := '0';
  signal btn       : std_logic := '1';      -- Active LOW
  signal btn_clear : std_logic := '1';      -- Active LOW
  signal btn_space : std_logic := '1';      -- Active LOW
  signal btn_enter : std_logic := '1';      -- Active LOW
  signal buzzer    : std_logic;
  signal rs        : std_logic;
  signal rw        : std_logic;
  signal e         : std_logic;
  signal lcd_data  : std_logic_vector(7 downto 0);
  signal LEDR      : std_logic_vector(9 downto 0); 

  constant CLK_PERIOD : time := 20 ns;
  
  -- SIMULATION HELPER: Decoded Character for Waveform Viewer
  signal lcd_char_view : character := ' ';

begin

  -- Clock generation
  clk_process : process
  begin
    clk <= '0';
    wait for CLK_PERIOD / 2;
    clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  -- DUT instance
  uut : entity work.lcd_top
    port map (
      clk       => clk,
      reset_n   => reset_n,
      btn       => btn,
      btn_clear => btn_clear,
      btn_space => btn_space,
      btn_enter => btn_enter,
      buzzer    => buzzer,
      rs        => rs,
      rw        => rw,
      e         => e,
      lcd_data  => lcd_data,
      LEDR      => LEDR
    );
    
  -- Process to decode LCD data for ModelSim visibility
  process(e)
  begin
    -- LCD latches data on falling edge of E
    if falling_edge(e) then
       if rs = '1' and rw = '0' then
          -- Write Data
          if unsigned(lcd_data) >= 32 and unsigned(lcd_data) <= 126 then
             lcd_char_view <= character'val(to_integer(unsigned(lcd_data)));
             report "LCD WRITE: '" & character'val(to_integer(unsigned(lcd_data))) & "'";
          else
             lcd_char_view <= '?';
             report "LCD WRITE: Hex " & integer'image(to_integer(unsigned(lcd_data)));
          end if;
       elsif rs = '0' and rw = '0' then
          -- Write Command
          report "LCD COMMAND: Hex " & integer'image(to_integer(unsigned(lcd_data)));
          if lcd_data = x"01" then
             report "LCD CLEAR DISPLAY";
          end if;
       end if;
    end if;
  end process;

  -- Stimulus
  stim_proc : process
  begin
    -- Reset
    reset_n <= '0';
    wait for 100 ns;
    reset_n <= '1';
    wait for 1 ms; -- Wait a bit after reset

    -- 1. Test Dot
    btn <= '0'; 
    wait for 100 ms;  
    btn <= '1'; 
    wait for 200 ms;

    -- 2. Test Dash
    btn <= '0'; 
    wait for 300 ms; 
    btn <= '1'; 
    wait for 700 ms; 

    -- 3. Test Space Button
    wait for 50 ms;
    btn_space <= '0';
    wait for 50 ms;
    btn_space <= '1';

    -- 4. Test New Line (Enter)
    wait for 50 ms;
    btn_enter <= '0';
    wait for 50 ms;
    btn_enter <= '1';

    -- 5. Test another Dot on Line 2
    wait for 50 ms;
    btn <= '0';
    wait for 100 ms;
    btn <= '1';
    wait for 700 ms;

    -- 6. Test Clear
    wait for 50 ms;
    btn_clear <= '0';
    wait for 50 ms;
    btn_clear <= '1';
    
    wait for 100 ms;

    wait;
  end process;

end architecture;