-- This module controls multiple ASICs in the architecture
-- where SCLK and SIN are shared, and PCLK is point-to-point.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;

entity MultiIrsRegControl is
	generic (
		NUM_IRS_G    : integer range 1 to 16 := 16;
		GATE_DELAY_G : time := 1 ns
	);
	port (
		-- Core CLK
		clk           : in sl;
		-- ASIC pins
		AsicIn_PCLK   : out slv(NUM_IRS_G-1 downto 0);
		AsicIn_SCLK   : out sl;
		AsicIn_SIN    : out sl;
		-- Interfaces to RegMap
		irsNumber     : in  slv( 3 downto 0);
		irsAddr       : in  slv( 7 downto 0);
		irsWrData     : in  slv(11 downto 0);
		irsRdData     : out slv(31 downto 0);
		irsReq        : in  sl;
		irsOp         : in  sl;
		irsAck        : out sl
	);
end MultiIrsRegControl;

architecture Behavioral of MultiIrsRegControl is

	constant REG_LOAD_PERIOD_C  : slv(15 downto 0) := x"0000";
	constant REG_LATCH_PERIOD_C : slv(15 downto 0) := x"0004";
	constant ZERO_C             : sl := '0';

	signal iPclk    : sl := '0';
	signal iUpdate  : sl := '0';
	signal iRegData : slv(19 downto 0) := (others => '0');

begin

	-- IRS is basically write only... create the update strobe 
	-- out of op = '1' and req = '1';
	iUpdate <= irsOp and irsReq;
	-- The address is in the high bytes?
	iRegData <= irsAddr & irsWrData;
	-- Multiplex to select the chosen ASIC
	process(irsNumber, iPclk) begin
		for i in NUM_IRS_G-1 downto 0 loop
			if i = to_integer(unsigned(irsNumber)) then
				AsicIn_PCLK(i) <= iPclk;
			else
				AsicIn_PCLK(i) <= '0';
			end if;
		end loop;
	end process;
	-- We can't read this one, unfortunately...
	irsRdData <= (others => '0');

	U_IRS3D_DAC_CONTROL : entity work.IRS3D_DAC_CONTROL
		generic map (
			REGISTER_WIDTH => 20
		 )
		 port map ( 
			CLK          => clk,                --: in  STD_LOGIC;
			LOAD_PERIOD  => REG_LOAD_PERIOD_C,  --: in  STD_LOGIC_VECTOR(15 downto 0);
			LATCH_PERIOD => REG_LATCH_PERIOD_C, --: in  STD_LOGIC_VECTOR(15 downto 0);
			UPDATE       => iUpdate, 				--: in  STD_LOGIC;
			REG_DATA     => iRegData, 				--: in  STD_LOGIC_VECTOR(REGISTER_WIDTH-1 downto 0);
			SHOUT_DATA   => open,               --: out STD_LOGIC_VECTOR(REGISTER_WIDTH-1 downto 0);
			SIN          => AsicIn_SIN,         --: out STD_LOGIC;
			SHOUT        => ZERO_C,             --: in  STD_LOGIC;
			SCLK         => AsicIn_SCLK,        --: out STD_LOGIC;
			PCLK         => iPclk,              --: out STD_LOGIC;
			DONE         => irsAck              --: out STD_LOGIC
		);


end Behavioral;

