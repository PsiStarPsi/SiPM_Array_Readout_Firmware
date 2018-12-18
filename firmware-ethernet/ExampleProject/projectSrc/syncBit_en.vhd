----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    19:28:49 08/26/2018 
-- Design Name: 
-- Module Name:    syncBit_en - Behavioral 
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

entity syncBit_en is
	 Port ( 
			  clk 	  : in  STD_LOGIC;
           rst 	  : in  STD_LOGIC := '0';
           --CE       : in  STD_LOGIC := '1';
           async_in : in  STD_LOGIC;
           sync_out : out STD_LOGIC
			  );
end syncBit_en;

architecture Behavioral of syncBit_en is

signal read_sync1 : STD_LOGIC;
signal bit_pipe   : STD_LOGIC;

begin

	cdc_reg1 : FDRE
		port map (
			C  => clk,
			CE => '1',
			R  => rst,
			D  => async_in,
			Q  => read_sync1
		);

	cdc_reg2 : FDRE
		port map (
			C  => clk,
			CE => '1',
			R  => rst,
			D  => read_sync1,
			Q  => bit_pipe
		);

sync_out <= bit_pipe;

end Behavioral;

