library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use work.UtilityPkg.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity data_processing_top is
    Port ( 
			 --inputs from the ASIC / FPGA to take the DATA in..
			  clk100            : in  STD_LOGIC_vector(2 downto 0);
           clk400_slv        : in  std_logic_vector(2 downto 0);
			  ClkDataFSM		  : in  std_logic;
			  ioce_slv			  : in  std_logic_vector(2 downto 0);
			  rstFSM            : in  STD_LOGIC;
			  rstDATA           : in  STD_LOGIC;
           input_pins        : in  STD_LOGIC_VECTOR(63 downto 0);
			  data_addr_bef	  : in  STD_LOGIC_VECTOR(3 downto 0);
			  data_addr_aft     : in  STD_LOGiC_VECTOR(3 downto 0);
			  evtNumber         : out std_logic_vector(31 downto 0);
			  dataReady         : out std_logic;
          --outputs to send to the AXIS stream
			  evtData           : out STD_LOGIC_VECTOR(31 downto 0);
			  evtDataFifoReady  : in  std_logic;
			  evtDataLast       : out std_logic;
			  evtDataValid      : out std_logic;
			  evtDataKeep		  : out std_logic_vector(3 downto 0);
			 --new conversion of signals to top levle 'ports' to send to data_processing_top
			  prt_LAPPD_srcMac  : in std_logic_vector(63 downto 0);
			  prt_LAPPD_srcIP   : in std_logic_vector(31 downto 0);
			  prt_NBIC_destMac  : in std_logic_vector(63 downto 0);
			  prt_NBIC_destIP   : in std_logic_vector(31 downto 0);
			  prt_NBIC_ports	  : in std_logic_vector(31 downto 0);
			  soft_trigger      : in std_logic
			);

end data_processing_top;

architecture Behavioral of data_processing_top is

	--signals to speak between data ports and FSM
	signal data_inputs     : std_logic_vector(63 downto 0);
	signal data_addr_wr    : std_logic_vector(7 downto 0); --where the current writing is happening
	signal data_addr_hit   : std_logic_vector(7 downto 0); --address of a hit occuring
	signal data_addr_rd    : std_logic_vector(7 downto 0); --address the FSM is currently reading from
	signal phase_sel       : std_logic_vector(1 downto 0);
	signal trigger_outputs : std_logic_vector(63 downto 0);
	signal data_outputs    : std_logic_vector(63 downto 0);
  
  --new_hit
   signal new_hit         : std_logic;
	signal data_addr_befs  : std_logic_vector(3 downto 0);
	signal data_addr_afts  : std_logic_vector(3 downto 0);
  
  --clks and rsts 
	signal rst_nDATA       : std_logic;

	signal dataReadys      : std_logic;

begin


data_addr_befs <= data_addr_bef;
data_addr_afts <= data_addr_aft;

data_inputs <= input_pins;
dataReady   <= dataReadys;
rst_nDATA   <= not rstDATA;

------------------------------------------------------------------------------------------------------
------------------------------------------DATA IN-----------------------------------------------------
------------------------------------------------------------------------------------------------------
data_ports1 : entity work.data_ports 
	PORT MAP(
		CLK100         => clk100, --make clk100 a slv in this design to each of the clk100 bufGs to go where they need to go?
		CLK400         => clk400_slv,
		ClkDataFSM		=> ClkDataFSM,
		ioce           => ioce_slv,
		RST            => rstDATA,
		DATA_INPUT     => data_inputs,
		data_address   => data_addr_rd, --current reading address
		phase_sel      => phase_sel,
		data_addr_out  => data_addr_wr, --current writing address
		TRIGGER_OUTPUT => trigger_outputs,
		DATA_OUTPUT    => data_outputs
	);
------------------------------------------------------------------------------------------------------
------------------------------------------FSM / EthPackets--------------------------------------------
------------------------------------------------------------------------------------------------------
read_out_data1 : entity work.read_out_data 
	PORT MAP(
		clk100            => ClkDataFSM,
		rst               => rstFSM,
		new_trigger       => new_hit,
		--addr_wr is where the BRAM is currently writting..
		data_read_in      => data_outputs, 
		data_addr_hit     => data_addr_hit,
		data_phase_out    => phase_sel,
		--this is the address that the read_out_data is reading from to send to the AXIS stream..
		data_read_out     => data_addr_rd, 
		data_addr_bef     => data_addr_befs,
		data_addr_aft     => data_addr_afts,		
		--inputs from the reg map to read the IP and MAC address
		prt_LAPPD_srcMac  => prt_LAPPD_srcMac,
		prt_LAPPD_srcIP   => prt_LAPPD_srcIP,	
		prt_NBIC_destMac  => prt_NBIC_destMac,
		prt_NBIC_destIP   => prt_NBIC_destIP,
		prt_NBIC_ports 	=> prt_NBIC_ports,
		soft_trigger      => soft_trigger,
		--outputs to fifo
		evtDataValid      => evtDataValid,
		evtData           => evtData,
		evtDataLast       => evtDataLast,
		evtDataFifoReady  => evtDataFifoReady,
		evtDataKeep			=> evtDataKeep,
		evtNumber         => evtNumber,
		--data is ready to ready
		dataReady         => dataReadys
	);

------------------------------------------------------------------------------------------------------
------------------------------------TRIGGER / ADDRESS SELECT------------------------------------------
------------------------------------------------------------------------------------------------------

trigger_addr_sel1 : entity work.trigger_addr_sel 
	PORT MAP(
		clk100        => clk100(0),
		ClkDataFSM	  => ClkDataFSM,
		--rstDATA       => rstDATA,
		rstFSM        => rstFSM,
		trigger_input => trigger_outputs,
		addr_in       => data_addr_wr,
		addr_out      => data_addr_hit,
		new_hit       => new_hit 
	);



end Behavioral;

