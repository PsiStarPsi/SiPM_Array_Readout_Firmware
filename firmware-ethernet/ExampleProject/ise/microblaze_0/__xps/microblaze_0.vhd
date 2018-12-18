LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY microblaze_0 IS
PORT (
	RESET : IN STD_LOGIC;
	CLK : IN STD_LOGIC;
	microblaze_0_S0_AXIS_TLAST_pin : IN STD_LOGIC;
	microblaze_0_S0_AXIS_TDATA_pin : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
	microblaze_0_S0_AXIS_TVALID_pin : IN STD_LOGIC;
	microblaze_0_S0_AXIS_TREADY_pin : OUT STD_LOGIC;
	microblaze_0_M0_AXIS_TLAST_pin : OUT STD_LOGIC;
	microblaze_0_M0_AXIS_TDATA_pin : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
	microblaze_0_M0_AXIS_TVALID_pin : OUT STD_LOGIC;
	microblaze_0_M0_AXIS_TREADY_pin : IN STD_LOGIC;
	clock_generator_0_CLKOUT0_pin : OUT STD_LOGIC;
	iomodule_0_IO_Addr_Strobe_pin : OUT STD_LOGIC;
	iomodule_0_IO_Read_Strobe_pin : OUT STD_LOGIC;
	iomodule_0_IO_Write_Strobe_pin : OUT STD_LOGIC;
	iomodule_0_IO_Address_pin : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
	iomodule_0_IO_Byte_Enable_pin : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
	iomodule_0_IO_Write_Data_pin : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
	iomodule_0_IO_Read_Data_pin : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
	iomodule_0_IO_Ready_pin : IN STD_LOGIC
	);
END microblaze_0;

ARCHITECTURE STRUCTURE OF microblaze_0 IS

BEGIN
END ARCHITECTURE STRUCTURE;
