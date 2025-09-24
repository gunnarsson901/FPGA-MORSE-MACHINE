library ieee;
use ieee.std_logic_1164.all;

entity lcd_top is
  port (
    clk      : in  std_logic;
    reset_n  : in  std_logic;
    rs, rw, e: out std_logic;
    lcd_data : out std_logic_vector(7 downto 0)
  );
end lcd_top;

architecture rtl of lcd_top is
  signal lcd_busy    : std_logic;
  signal lcd_enable  : std_logic;
  signal lcd_bus     : std_logic_vector(9 downto 0);
begin
  -- LCD Controller instance
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

  -- User logic instance
  u2: entity work.lcd_user_logic
    port map (
      clk        => clk,
      lcd_busy   => lcd_busy,
      lcd_enable => lcd_enable,
      lcd_bus    => lcd_bus,
      reset_n    => open,
      lcd_clk    => open
    );

end rtl;
