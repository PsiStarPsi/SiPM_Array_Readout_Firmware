-------------------------------------------------------------------------------
-- microblaze_0_stub.vhd
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity microblaze_0_stub is
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
end microblaze_0_stub;

architecture STRUCTURE of microblaze_0_stub is

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

 attribute BOX_TYPE : STRING;
 attribute BOX_TYPE of microblaze_0 : component is "user_black_box";

begin

  microblaze_0_i : microblaze_0
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

end architecture STRUCTURE;

