-- lcd_controller.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_controller is
  generic (
    G_CLK_MHZ : integer := 50  -- systemklocka i MHz
  );
  port (
    clk        : in  std_logic;
    reset_n    : in  std_logic;                         -- aktiv låg reset
    lcd_enable : in  std_logic;                         -- latcha nytt kommando
    lcd_bus    : in  std_logic_vector(9 downto 0);      -- [9]=RS, [8]=RW, [7:0]=DATA

    busy       : out std_logic := '1';                  -- hög när upptagen
    rw         : out std_logic;
    rs         : out std_logic;
    e          : out std_logic;
    lcd_data   : out std_logic_vector(7 downto 0);
    lcd_on     : out std_logic;
    lcd_blon   : out std_logic
  );
end lcd_controller;

architecture rtl of lcd_controller is
  type state_t is (POWER_UP, INIT, READY, SEND);
  signal state     : state_t := POWER_UP;
  signal clk_count : integer := 0;

  -- tidskonstanter i µs*MHz = klockcykler
  constant C_50MS   : integer := 50000 * G_CLK_MHZ;
  constant C_50US   : integer := 50     * G_CLK_MHZ;
  constant C_60US   : integer := 60     * G_CLK_MHZ;
  constant C_2MS    : integer := 2000   * G_CLK_MHZ;
begin
  lcd_on   <= '1';
  lcd_blon <= '1';

  process(clk)
  begin
    if rising_edge(clk) then
      -- default
      busy <= '1';

      case state is
        when POWER_UP =>
          if clk_count < C_50MS then
            clk_count <= clk_count + 1;
          else
            clk_count <= 0;
            rs       <= '0';
            rw       <= '0';
            lcd_data <= "00110000";       -- Function Set, 8-bit, 1-line (exempel)
            state    <= INIT;
          end if;

        when INIT =>
          clk_count <= clk_count + 1;

          if clk_count < (10 * G_CLK_MHZ) then          -- Function Set
            lcd_data <= "00110100";                     -- 8-bit, 1-line, display on
            e        <= '1';
          elsif clk_count < (60 * G_CLK_MHZ) then       -- 50 µs
            lcd_data <= (others => '0');
            e        <= '0';
          elsif clk_count < (70 * G_CLK_MHZ) then       -- Display ON/OFF control
            lcd_data <= "00001101";                     -- display on, cursor off, blink on
            e        <= '1';
          elsif clk_count < (120 * G_CLK_MHZ) then
            lcd_data <= (others => '0');
            e        <= '0';
          elsif clk_count < (130 * G_CLK_MHZ) then      -- Clear display
            lcd_data <= "00000001";
            e        <= '1';
          elsif clk_count < (C_2MS + 130 * G_CLK_MHZ) then
            lcd_data <= (others => '0');
            e        <= '0';
          elsif clk_count < (C_2MS + 140 * G_CLK_MHZ) then -- Entry mode set
            lcd_data <= "00000110";                     -- increment, no shift
            e        <= '1';
          elsif clk_count < (C_2MS + 200 * G_CLK_MHZ) then
            lcd_data <= (others => '0');
            e        <= '0';
          else
            clk_count <= 0;
            busy      <= '0';
            state     <= READY;
          end if;

        when READY =>
          if lcd_enable = '1' then
            busy      <= '1';
            rs        <= lcd_bus(9);
            rw        <= lcd_bus(8);
            lcd_data  <= lcd_bus(7 downto 0);
            clk_count <= 0;
            state     <= SEND;
          else
            busy      <= '0';
            rs        <= '0';
            rw        <= '0';
            lcd_data  <= (others => '0');
            e         <= '0';
          end if;

        when SEND =>
          -- total ~50 µs med E-puls high mitt i
          if clk_count < (50 * G_CLK_MHZ) then
            if clk_count < (1 * G_CLK_MHZ) then
              e <= '0';
            elsif clk_count < (14 * G_CLK_MHZ) then
              e <= '1';
            elsif clk_count < (27 * G_CLK_MHZ) then
              e <= '0';
            end if;
            clk_count <= clk_count + 1;
          else
            clk_count <= 0;
            state     <= READY;
            e         <= '0';
          end if;
      end case;

      if reset_n = '0' then
        state     <= POWER_UP;
        clk_count <= 0;
        e         <= '0';
        rs        <= '0';
        rw        <= '0';
        lcd_data  <= (others => '0');
      end if;
    end if;
  end process;
end rtl;
