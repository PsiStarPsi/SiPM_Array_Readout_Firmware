----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:52:01 10/19/2018 
-- Design Name: 
-- Module Name:    trigger_addr_sel - Behavioral 
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
--library UNISIM;
--use UNISIM.VComponents.all;

entity trigger_addr_sel is
    Port ( clk100        : in   STD_LOGIC;
			  ClkDataFSM	 : in   STD_LOGIC;
           --rstDATA       : in   STD_LOGIC;
			  rstFSM        : in   STD_LOGIC;
           trigger_input : in   STD_LOGIC_VECTOR(63 downto 0);
           addr_in       : in   STD_LOGIC_vector(7 downto 0);
           addr_out      : out  STD_LOGIC_VECTOR(7 downto 0);
           new_hit       : out  STD_LOGIC
			  );
end trigger_addr_sel;

architecture Behavioral of trigger_addr_sel is

	signal data_addr_write  : std_logic_vector(7 downto 0);
	signal new_trigger      : std_logic;

begin

	--trigger factor
	process(clk100) is 
		variable prev_trigger    : std_logic_vector(63 downto 0) := (others => '0');
	begin
		if(rising_edge(clk100)) then
			if(trigger_input /= prev_trigger) then --if the trigger value has changed at all, indicate that the FSM should start reading.
					new_trigger      <= '1';
					data_addr_write  <= addr_in;
					prev_trigger     := trigger_input;      --update the new trigger condition, currently prev_trigger is all '0's...
			elsif(trigger_input = prev_trigger) then 
					new_trigger <= '0';                    --this will cuase the new_trigger value to go low at the next clock cycle, with no change..
			end if;
		end if;
	end process;


generate_sync : for i in 0 to 7 generate  --These need to run at FSM Clk Rate
bit_sync : entity work.syncBit_en
				port map (
					  clk      => ClkDataFSM,   		  --75 Mhz
					  rst      => rstFSM,
					  --CE       => '1',
					  async_in => data_addr_write(i),  --100 MHz
					  sync_out => addr_out(i)			  --75 Mhz
				);
end generate;

bit_sync : entity work.syncBit_en
				port map (
					  clk      => ClkDataFSM,
					  rst      => rstFSM,
					  --CE       => '1',
					  async_in => new_trigger,
					  sync_out => new_hit
				);


end Behavioral;

