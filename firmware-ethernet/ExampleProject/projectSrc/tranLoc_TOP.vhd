----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    01:33:18 08/22/2018 
-- Design Name: 
-- Module Name:    tranLoc_TOP - Behavioral 
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

entity tranLoc_TOP is

GENERIC (
		input_size : integer := 8;
		output_size: integer := 8		
		);
    
Port (
	CLOCK  			: in  STD_LOGIC;
	RESET 			: in  STD_LOGIC := '0';
	DATA_INPUT     : in  STD_LOGIC_VECTOR(input_size-1 downto 0);
   --READ_OUT 		: out STD_LOGIC_VECTOR(output_size-1 downto 0);
	NEW_MEASURE		: out STD_LOGIC := '0'
	);

end tranLoc_TOP;

architecture Behavioral of tranLoc_TOP is

--input and output values for the bit_sync module..
	signal trigger_d      : STD_LOGIC_VECTOR(input_size-1 downto 0); 
	signal read1          : STD_LOGIC_VECTOR(input_size-1 downto 0);
	--process and read the new trigger value
	--signal new_hit		    : STD_LOGIC;

begin

--make the port assignments to the signals..
	--READ_OUT    <= trigger_d;
	--NEW_MEASURE <= new_hit;

--place sync_bit modules
process_hit : entity work.process_trigger --running at ISERDES2 Clk Rate
					Generic map(
						input_size   => input_size,
						output_size  => output_size
					)
					port map (
					  clk           => CLOCK,
					  rst           => RESET,
					  async_bit_in  => DATA_INPUT,
					  --async_bit_out => read_out,
					  new_hit       => new_measure
					);

--generate_sync : for i in 0 to input_size-1 generate  --These need to run at FSM Clk Rate
--bit_sync : entity work.syncBit_en
--				port map (
--					  clk      => CLOCK,
--					  rst      => RESET,
--					  --CE       => '1',
--					  async_in => TRIGGER_INPUT(i),
--					  sync_out => read1(i)
--				);
--end generate;


end Behavioral;