-------------------------------------------------------------------------------
-- microblaze_0_tb.vhd
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

-- START USER CODE (Do not remove this line)

-- User: Put your libraries here. Code in this
--       section will not be overwritten.

-- END USER CODE (Do not remove this line)

entity microblaze_0_tb is
end microblaze_0_tb;

architecture STRUCTURE of microblaze_0_tb is

  constant CLK_PERIOD : time := 8000.000000 ps;
  constant RESET_LENGTH : time := 128000 ps;

  component microblaze_0 is
    port (
      RESET : in std_logic;
      CLK : in std_logic;
      microblaze_0_S0_AXIS_TLAST_pin : in std_logic;
      microblaze_0_S0_AXIS_TDATA_pin : in std_logic_vector(31 downto 0);
      microblaze_0_S0_AXIS_TVALID_pin : in std_logic;
      microblaze_0_S0_AXIS_TREADY_pin : out std_logic;
      microblaze_0_M0_AXIS_TLAST_pin : out std_logic;
      microblaze_0_M0_AXIS_TDATA_pin : out std_logic_vector(31 downto 0);
      microblaze_0_M0_AXIS_TVALID_pin : out std_logic;
      microblaze_0_M0_AXIS_TREADY_pin : in std_logic;
      clock_generator_0_CLKOUT0_pin : out std_logic;
      iomodule_0_IO_Addr_Strobe_pin : out std_logic;
      iomodule_0_IO_Read_Strobe_pin : out std_logic;
      iomodule_0_IO_Write_Strobe_pin : out std_logic;
      iomodule_0_IO_Address_pin : out std_logic_vector(31 downto 0);
      iomodule_0_IO_Byte_Enable_pin : out std_logic_vector(3 downto 0);
      iomodule_0_IO_Write_Data_pin : out std_logic_vector(31 downto 0);
      iomodule_0_IO_Read_Data_pin : in std_logic_vector(31 downto 0);
      iomodule_0_IO_Ready_pin : in std_logic
    );
  end component;

  -- Internal signals

  signal CLK : std_logic;
  signal RESET : std_logic;
  signal clock_generator_0_CLKOUT0_pin : std_logic;
  signal iomodule_0_IO_Addr_Strobe_pin : std_logic;
  signal iomodule_0_IO_Address_pin : std_logic_vector(31 downto 0);
  signal iomodule_0_IO_Byte_Enable_pin : std_logic_vector(3 downto 0);
  signal iomodule_0_IO_Read_Data_pin : std_logic_vector(31 downto 0);
  signal iomodule_0_IO_Read_Strobe_pin : std_logic;
  signal iomodule_0_IO_Ready_pin : std_logic;
  signal iomodule_0_IO_Write_Data_pin : std_logic_vector(31 downto 0);
  signal iomodule_0_IO_Write_Strobe_pin : std_logic;
  signal microblaze_0_M0_AXIS_TDATA_pin : std_logic_vector(31 downto 0);
  signal microblaze_0_M0_AXIS_TLAST_pin : std_logic;
  signal microblaze_0_M0_AXIS_TREADY_pin : std_logic;
  signal microblaze_0_M0_AXIS_TVALID_pin : std_logic;
  signal microblaze_0_S0_AXIS_TDATA_pin : std_logic_vector(31 downto 0);
  signal microblaze_0_S0_AXIS_TLAST_pin : std_logic;
  signal microblaze_0_S0_AXIS_TREADY_pin : std_logic;
  signal microblaze_0_S0_AXIS_TVALID_pin : std_logic;

  -- START USER CODE (Do not remove this line)

  -- User: Put your signals here. Code in this
  --       section will not be overwritten.

  -- END USER CODE (Do not remove this line)

begin

  dut : microblaze_0
    port map (
      RESET => RESET,
      CLK => CLK,
      microblaze_0_S0_AXIS_TLAST_pin => microblaze_0_S0_AXIS_TLAST_pin,
      microblaze_0_S0_AXIS_TDATA_pin => microblaze_0_S0_AXIS_TDATA_pin,
      microblaze_0_S0_AXIS_TVALID_pin => microblaze_0_S0_AXIS_TVALID_pin,
      microblaze_0_S0_AXIS_TREADY_pin => microblaze_0_S0_AXIS_TREADY_pin,
      microblaze_0_M0_AXIS_TLAST_pin => microblaze_0_M0_AXIS_TLAST_pin,
      microblaze_0_M0_AXIS_TDATA_pin => microblaze_0_M0_AXIS_TDATA_pin,
      microblaze_0_M0_AXIS_TVALID_pin => microblaze_0_M0_AXIS_TVALID_pin,
      microblaze_0_M0_AXIS_TREADY_pin => microblaze_0_M0_AXIS_TREADY_pin,
      clock_generator_0_CLKOUT0_pin => clock_generator_0_CLKOUT0_pin,
      iomodule_0_IO_Addr_Strobe_pin => iomodule_0_IO_Addr_Strobe_pin,
      iomodule_0_IO_Read_Strobe_pin => iomodule_0_IO_Read_Strobe_pin,
      iomodule_0_IO_Write_Strobe_pin => iomodule_0_IO_Write_Strobe_pin,
      iomodule_0_IO_Address_pin => iomodule_0_IO_Address_pin,
      iomodule_0_IO_Byte_Enable_pin => iomodule_0_IO_Byte_Enable_pin,
      iomodule_0_IO_Write_Data_pin => iomodule_0_IO_Write_Data_pin,
      iomodule_0_IO_Read_Data_pin => iomodule_0_IO_Read_Data_pin,
      iomodule_0_IO_Ready_pin => iomodule_0_IO_Ready_pin
    );

  -- Clock generator for CLK

  process
  begin
    CLK <= '0';
    loop
      wait for (CLK_PERIOD/2);
      CLK <= not CLK;
    end loop;
  end process;

  -- Reset Generator for RESET

  process
  begin
    RESET <= '0';
    wait for (RESET_LENGTH);
    RESET <= not RESET;
    wait;
  end process;

  -- START USER CODE (Do not remove this line)

  -- User: Put your stimulus here. Code in this
  --       section will not be overwritten.

  -- END USER CODE (Do not remove this line)

end architecture STRUCTURE;

