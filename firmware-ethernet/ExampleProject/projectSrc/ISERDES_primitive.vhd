----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:11:58 10/14/2018 
-- Design Name: 
-- Module Name:    ISERDES_primitive - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity ISERDES_primitive is
    Port ( 
			  ce0       : in  STD_LOGIC := '0';        --clk enable input 
           clkdiv    : in  STD_LOGIC;        --1 bit global clock network input. use for fabric domain..
           clk0      : in  STD_LOGIC;        --clock network input.
			  d         : in  STD_LOGIC;        --serial input 
			  ISERDES2_output : out STD_LOGIC_VECTOR(3 downto 0);	
           rst       : in  STD_LOGIC;			--async reset only
			  ioce      : in std_logic
			 );
end ISERDES_primitive;

architecture Behavioral of ISERDES_primitive is

	--ISERDES2 bit outputs..
	signal Q1, Q2, Q3, Q4 : std_logic;	
begin

ISERDES2_inst1 : ISERDES2
	Generic Map (
		BITSLIP_ENABLE => FALSE,
		DATA_RATE 		=> "SDR",		
		DATA_WIDTH 		=> 4,
		INTERFACE_TYPE => "RETIMED",
		SERDES_MODE 	=> "NONE"
	)
	port map (
		ce0     => ce0,
		clkdiv  => clkdiv,
		clk0    => clk0,
		clk1    => '0',
		d 		  => d,
		Q1        => Q1,
		Q2        => Q2,
		Q3        => Q3,
		Q4        => Q4,
		rst       => rst,
		shiftin   => '0',
		bitslip   => '0',
		ioce      => ioce
	);

--assign values of the ports to describe the ISERDES2 setup below..
ISERDES2_output(3) <= Q4;
ISERDES2_output(2) <= Q3;
ISERDES2_output(1) <= Q2;
ISERDES2_output(0) <= Q1;


end Behavioral;

