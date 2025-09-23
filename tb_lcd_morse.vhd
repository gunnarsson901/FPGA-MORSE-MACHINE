library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_lcd_morse is
end entity;

architecture sim of tb_lcd_morse is
  -- Klocka 1 MHz
  constant CLK_HZ     : integer := 1_000_000;
  constant CLK_PERIOD : time    := 1 us;

  -- Morse-enhet 10 ms
  constant UNIT_MS    : integer := 10;

  -- DUT-signaler
  signal clk       : std_logic := '0';
  signal reset_n   : std_logic := '0';
  signal btn       : std_logic := '0';
  signal rs, rw, e : std_logic;
  signal lcd_data  : std_logic_vector(7 downto 0);
  signal lcd_busy  : std_logic;
  signal lcd_en    : std_logic;
  signal lcd_bus   : std_logic_vector(9 downto 0);

  signal e_prev : std_logic := '0';

  -- === Procedurer MÅSTE ligga här (deklarativ del), före 'begin' ===
  procedure press_units(constant n_units : integer) is
  begin
    btn <= '1';
    wait for n_units * UNIT_MS * 1 ms;
    btn <= '0';
  end procedure;

  procedure gap_units(constant n_units : integer) is
  begin
    btn <= '0';
    wait for n_units * UNIT_MS * 1 ms;
  end procedure;

  procedure morse_A is  -- .-
  begin
    press_units(1); gap_units(1);
    press_units(3); gap_units(3);
  end procedure;

  procedure morse_B is  -- -...
  begin
    press_units(3); gap_units(1);
    press_units(1); gap_units(1);
    press_units(1); gap_units(1);
    press_units(1); gap_units(3);
  end procedure;
  -- ==================================================================
begin
  -- Klocka
  clk <= not clk after CLK_PERIOD/2;

  -- LCD-kontroller
  u_ctrl: entity work.lcd_controller
    generic map ( G_CLK_MHZ => 1 )                  -- snabb init i sim
    port map (
      clk        => clk,
      reset_n    => reset_n,
      lcd_enable => lcd_en,
      lcd_bus    => lcd_bus,
      busy       => lcd_busy,
      rw         => rw,
      rs         => rs,
      e          => e,
      lcd_data   => lcd_data,
      lcd_on     => open,
      lcd_blon   => open
    );

  -- Morse-decoder
  u_morse: entity work.morse_decoder
    generic map (
      G_CLK_HZ  => CLK_HZ,
      G_UNIT_MS => UNIT_MS
    )
    port map (
      clk        => clk,
      reset_n    => reset_n,
      btn        => btn,
      busy       => lcd_busy,
      lcd_enable => lcd_en,
      lcd_bus    => lcd_bus
    );

  -- Reset
  proc_reset: process
  begin
    reset_n <= '0';
    wait for 100 us;
    reset_n <= '1';
    wait;
  end process;

  -- Stimuli
  stim: process
  begin
    -- vänta tills init är klar
    wait for 100 ms;

    morse_A;      -- skickar 'A'
    gap_units(5);
    morse_B;      -- skickar 'B'

    wait for 200 ms;
    assert false report "SIM DONE" severity failure;
  end process;

  -- Monitorera E-flank
  monitor: process(clk)
    variable ascii_i : integer;
    variable ch      : character;
  begin
    if rising_edge(clk) then
      e_prev <= e;

      if (e_prev = '0' and e = '1') then
        if rs = '1' then
          ascii_i := to_integer(unsigned(lcd_data));
          ch      := character'val(ascii_i);
          report "LCD DATA write: ASCII=" & integer'image(ascii_i) &
                 " char='" & ch & "'";
        else
          report "LCD CMD  write: dec=" &
                 integer'image(to_integer(unsigned(lcd_data)));
        end if;
      end if;
    end if;
  end process;

end architecture;
