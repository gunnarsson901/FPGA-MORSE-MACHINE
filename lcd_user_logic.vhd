-- lcd_user_logic.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_user_logic is
  port (
    clk         : in  std_logic;
    lcd_busy    : in  std_logic;
    lcd_enable  : out std_logic;
    lcd_bus     : out std_logic_vector(9 downto 0);
    reset_n     : out std_logic;
    lcd_clk     : out std_logic
  );
end lcd_user_logic;

architecture rtl of lcd_user_logic is
  signal s_enable : std_logic := '0';
  signal idx      : integer range 0 to 12 := 0;
begin
  lcd_clk    <= clk;
  reset_n    <= '1';
  lcd_enable <= s_enable;

  process(clk)
  begin
    if rising_edge(clk) then
      -- default
      s_enable <= '0';

      if (lcd_busy = '0') then
        if idx < 12 then
          idx      <= idx + 1;
          s_enable <= '1';

          case idx is
            when 1  => lcd_bus <= '1' & '0' & x"31"; -- '1'
            when 2  => lcd_bus <= '1' & '0' & x"32"; -- '2'
            when 3  => lcd_bus <= '1' & '0' & x"33"; -- '3'
            when 4  => lcd_bus <= '1' & '0' & x"34"; -- '4'
            when 5  => lcd_bus <= '1' & '0' & x"35"; -- '5'
            when 6  => lcd_bus <= '1' & '0' & x"36"; -- '6'
            when 7  => lcd_bus <= '1' & '0' & x"37"; -- '7'
            when 8  => lcd_bus <= '1' & '0' & x"38"; -- '8'
            when 9  => lcd_bus <= '1' & '0' & x"39"; -- '9'
            when 10 => lcd_bus <= '1' & '0' & x"41"; -- 'A'
            when 11 => lcd_bus <= '1' & '0' & x"42"; -- 'B'
            when others =>
              s_enable <= '0';
          end case;
        end if;
      end if;
    end if;
  end process;
end rtl;
