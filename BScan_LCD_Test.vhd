----------------------------------------------------------------------------------
-- Engineer: Altynbek Isabekov
--
-- Create Date:    2022-01-09
-- Design Name:    JTAG to 2x16 LCD driver testing circuit (via BSCAN register)
-- Module Name:    BScan_LCD_Test - Behavioral
-- Project Name:   JTAG to 2x16 LCD driver
-- Target Devices: xc3s50a, vq100 package (Prometheus FPGA development board)
-- Description: The circuit receives 32 ASCII characters from the
--              TDI input of the built-in JTAG Test Access Point interface
--              and displays them on a 2x16 LCD.
--
-- Dependencies: LCDDriver4bit.vhdl by A. Greensted (modified)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
library UNISIM;
use UNISIM.VComponents.all;

entity BScan_LCD_Test is
  generic (N        : integer  := 8;  -- Number of bits in a byte
           N_Chars  : integer  := 32; -- Length of a buffer for storing characters
           CLK_FREQ : positive := 50*10**6
           );
  port(CLK     : in  std_logic;
       Trigger : in  std_logic;
       Reset   : in  std_logic;
       Nibble  : out std_logic_vector (3 downto 0);
       RS      : out std_logic;
       E       : out std_logic
       );
end BScan_LCD_Test;

architecture Behavioral of BScan_LCD_Test is
  component BSCAN_SPARTAN3
    port (CAPTURE : out std_logic;
          DRCK1   : out std_logic;
          DRCK2   : out std_logic;
          RESET   : out std_logic;
          SEL1    : out std_logic;
          SEL2    : out std_logic;
          SHIFT   : out std_logic;
          TDI     : out std_logic;
          UPDATE  : out std_logic;
          TDO1    : in  std_logic;
          TDO2    : in  std_logic
          );
  end component;

  signal user_CAPTURE   : std_logic;
  signal user_DRCK1     : std_logic;
  signal user_DRCK2     : std_logic;
  signal user_RESET     : std_logic;
  signal user_SEL1      : std_logic;
  signal user_SEL2      : std_logic;
  signal user_SHIFT     : std_logic;
  signal user_TDI       : std_logic;
  signal user_UPDATE    : std_logic;
  signal user_TDO1      : std_logic;
  signal user_TDO2      : std_logic;
  signal SHIFT_REGISTER : std_logic_vector(N_Chars*N-1 downto 0);

  component LCDDriver4Bit is
    generic (CLK_FREQ : positive);  -- Frequency of CLK input in Hz
    port (clk   : in std_logic;
          reset : in std_logic;

          -- Screen Buffer Interface
          dIn     : in std_logic_vector(7 downto 0);
          charNum : in integer range 0 to N_Chars - 1;
          wEn     : in std_logic;

          -- LCD Interface
          lcdData : out std_logic_vector(3 downto 0);
          lcdRS   : out std_logic;
          lcdE    : out std_logic);
  end component;
  signal Letter      : std_logic_vector (7 downto 0);
  signal Index       : integer range 0 to N_Chars - 1;
  signal WriteEnable : std_logic;

begin
  BS : BSCAN_SPARTAN3
    port map (
      CAPTURE => user_CAPTURE,
      DRCK1   => user_DRCK1,
      DRCK2   => user_DRCK2,
      RESET   => user_RESET,
      SEL1    => user_SEL1,
      SEL2    => user_SEL2,
      SHIFT   => user_SHIFT,
      TDI     => user_TDI,
      UPDATE  => user_UPDATE,
      TDO1    => user_TDO1,
      TDO2    => user_TDO2);

  LCD : LCDDriver4Bit generic map (CLK_FREQ => CLK_FREQ) port map (
                                  CLK       => CLK,
                                  reset     => Reset,
                                  dIn       => Letter,
                                  charNum   => Index,
                                  wEn       => WriteEnable,
                                  lcdData   => Nibble,
                                  lcdRS     => RS,
                                  lcdE      => E
                                  );

  process(user_DRCK1)
  begin
    if(user_RESET = '1') then
      SHIFT_REGISTER <= (others => '0');
    elsif (rising_edge(user_DRCK1)) then
      -- JTAG Chain: TDI => SHIFT_REGISTER(MSB -> LSB) => TDO
      SHIFT_REGISTER <= user_TDI & SHIFT_REGISTER(SHIFT_REGISTER'high downto 1);
      user_TDO1      <= SHIFT_REGISTER(0);
    end if;
  end process;

  Letter <= SHIFT_REGISTER((N_Chars - Index)*N - 1 downto (N_Chars - Index - 1)*N);

  process(CLK)
  begin
    if(rising_edge(CLK)) then
      if (Trigger = '1') then
        WriteEnable <= '1';
      end if;

      if (WriteEnable = '1') then
        Index <= Index + 1;
        if (Index = (N_Chars-1)) then
          Index       <= 0;
          WriteEnable <= '0';
        end if;
      end if;
    end if;
  end process;
end Behavioral;
