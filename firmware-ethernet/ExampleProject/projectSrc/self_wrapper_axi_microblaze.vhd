library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
use work.Eth1000BaseXPkg.all;
use work.GigabitEthPkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity self_wrapper_axi_microblaze is

port(

      -- User data paths in and out, including clocks and reset
      userClk            : in  sl;
      userRstIn          : in  sl;
		--clk100				 : in  sl; for use with fifo_conv if running FSM faster than MB
		--Tx lines go out from here and are transfered to the S6 eth top module.
      userTxDataChannel  : out slv(7 downto 0);
      userTxDataValid    : out sl;
      userTxDataLast     : out sl;
      userTxDataReady    : in  sl;

      --Rx data comes in on clk125 domain
		--Rx Data leaves here and goes in to the S6Ethtop Module..
      userRxDataChannel  : in  slv(7 downto 0);
      userRxDataValid    : in  sl;
      userRxDataLast     : in  sl;
      userRxDataReady    : out sl;
		
		evtDataValid      : in  std_logic;
		evtData           : in  std_logic_vector(31 downto 0);
		evtDataLast       : in  std_logic;
		evtDataFifoReady  : out std_logic;
		evtDataKeep			: in  std_logic_vector(3 downto 0);
		
		--iomodule output ports at the top
      iomodule_0_IO_Addr_Strobe_pin  : out std_logic;
      iomodule_0_IO_Read_Strobe_pin  : out std_logic;
      iomodule_0_IO_Write_Strobe_pin : out std_logic;
      iomodule_0_IO_Address_pin      : out std_logic_vector(31 downto 0);
      iomodule_0_IO_Byte_Enable_pin  : out std_logic_vector(3 downto 0);
      iomodule_0_IO_Write_Data_pin   : out std_logic_vector(31 downto 0);
      iomodule_0_IO_Read_Data_pin    : in std_logic_vector (31 downto 0);
      iomodule_0_IO_Ready_pin 		 : in std_logic;
		
		--clk out from the clk gen local to the micoblaze, this runs the reg map frequency.
		proc_sys_reset_0_Interconnect_aresetn_pin : out std_logic;
		microblaze_clk_gen_out         				: out std_logic
);

end self_wrapper_axi_microblaze;

architecture Behavioral of self_wrapper_axi_microblaze is

		signal rst     : std_logic;
		signal rst_n   : std_logic;

		signal clk125  : std_logic;

		--all of the microblaze signals are internal to this loop..
		signal microblaze_0_S0_AXIS_TLAST_pins  : std_logic;
      signal microblaze_0_S0_AXIS_TDATA_pins  : std_logic_vector(31 downto 0);
      signal microblaze_0_S0_AXIS_TVALID_pins : std_logic;
      signal microblaze_0_S0_AXIS_TREADY_pins : std_logic;
      
		signal microblaze_0_M0_AXIS_TLAST_pins  : std_logic;
      signal microblaze_0_M0_AXIS_TDATA_pins  : std_logic_vector(31 downto 0);
      signal microblaze_0_M0_AXIS_TVALID_pins : std_logic;
      signal microblaze_0_M0_AXIS_TREADY_pins : std_logic;
		
		--75 MHz clk from the microblaze.. microblaze ports need to be read from this port..
		signal clock_generator_0_CLKOUT0_pins   : std_logic;

      signal userTxDataChannels : slv(7 downto 0);
      signal userTxDataValids   : sl;
      signal userTxDataLasts    : sl;
      signal userTxDataReadys   : sl;

      -- RX data comes in on clk125 domain
      signal userRxDataChannels : slv(7 downto 0);
      signal userRxDataValids   : sl;
      signal userRxDataLasts    : sl;
      signal userRxDataReadys   : sl;
		
		-- --for use with fifo_convert if running FSM faster than MB
		signal evtDataValid_s      : std_logic;
		signal evtData_s           : std_logic_vector(31 downto 0);
		signal evtDataLast_s       : std_logic;
		signal evtDataFifoReady_s  : std_logic;
		
		-- input and output fifo sigals..
		-- these signals are currently unused in the fifo instantion, both are 32 bit outputs from each fifo..
		signal S00_FIFO_DATA_COUNT_input_fifos  : slv (31 downto 0);
		signal S00_FIFO_DATA_COUNT_convert_fifos  : slv (31 downto 0);
		signal S00_FIFO_DATA_COUNT_output_fifos : slv (31 downto 0);
		signal S01_FIFO_DATA_COUNT_output_fifos : slv (31 downto 0);
		
		-- output and output fifo sigals..
		-- these signals are currently unused in the fifo instantion, both are 32 bit outputs from each fifo..
		signal M00_FIFO_DATA_COUNT_input_fifos  : slv (31 downto 0);
		signal M00_FIFO_DATA_COUNT_convert_fifos  : slv (31 downto 0);
		signal M00_FIFO_DATA_COUNT_output_fifos : slv (31 downto 0);
		
		--supress signals on the input fifo
		signal S00_ARB_REQ_SUPPRESS : sl;
		signal S01_ARB_REQ_SUPPRESS : sl;
		
		signal M00_AXIS_TKEEP : slv(0 downto 0);

begin

--remember to map the ports to the signals!

		-- note that the signal versions are followed by an s..
      -- User data paths in and out, including clocks and reset
      clk125     <= userClk;
      rst        <= userRstIn;
		rst_n      <= not rst;
      microblaze_clk_gen_out <= clock_generator_0_CLKOUT0_pins;
		--userRstOut <= rst_out;
		
		--write to the outputs.. --note that 's' endings are local signals..
      userTxDataChannel  <= userTxDataChannels;
      userTxDataValid    <= userTxDataValids;
      userTxDataLast     <= userTxDataLasts;
      userTxDataReadys   <= userTxDataReady;

      --read from the inputs..
      userRxDataChannels <= userRxDataChannel;
      userRxDataValids   <= userRxDataValid;
      userRxDataLasts    <= userRxDataLast;
      userRxDataReady    <= userRxDataReadys;
	
--note all clocks and rests are driven to the same place: clk and rst respectively..

--microblaze
microblaze_0 : entity work.microblaze_0_top
	port map (
 
		RESET              => rst_n, -- Because microblaze EDK is stupes and won't let us change reset polarity.#nish:10/9/2018
		CLK                => clk125,
			
		--microblaze "inputs" keep in mind that the ready is reverse direction..	
		microblaze_0_S0_AXIS_TLAST_pin  => microblaze_0_S0_AXIS_TLAST_pins,
		microblaze_0_S0_AXIS_TDATA_pin  => microblaze_0_S0_AXIS_TDATA_pins,
		microblaze_0_S0_AXIS_TVALID_pin => microblaze_0_S0_AXIS_TVALID_pins,
		microblaze_0_S0_AXIS_TREADY_pin => microblaze_0_S0_AXIS_TREADY_pins,
		--microblaze "outputs"
		microblaze_0_M0_AXIS_TLAST_pin  => microblaze_0_M0_AXIS_TLAST_pins,
		microblaze_0_M0_AXIS_TDATA_pin  => microblaze_0_M0_AXIS_TDATA_pins,
		microblaze_0_M0_AXIS_TVALID_pin => microblaze_0_M0_AXIS_TVALID_pins,
		microblaze_0_M0_AXIS_TREADY_pin => microblaze_0_M0_AXIS_TREADY_pins,

		clock_generator_0_CLKOUT0_pin   => clock_generator_0_CLKOUT0_pins,
			
		iomodule_0_IO_Addr_Strobe_pin   => iomodule_0_IO_Addr_Strobe_pin,
		iomodule_0_IO_Read_Strobe_pin   => iomodule_0_IO_Read_Strobe_pin,
		iomodule_0_IO_Write_Strobe_pin  => iomodule_0_IO_Write_Strobe_pin,
		iomodule_0_IO_Address_pin 		  => iomodule_0_IO_Address_pin,
		iomodule_0_IO_Byte_Enable_pin   => iomodule_0_IO_Byte_Enable_pin,
		iomodule_0_IO_Write_Data_pin    => iomodule_0_IO_Write_Data_pin,
		iomodule_0_IO_Read_Data_pin 	  => iomodule_0_IO_Read_Data_pin,
		iomodule_0_IO_Ready_pin         => iomodule_0_IO_Ready_pin
    );
 
													-----------------------------------------
													-------------FIFO INPUT ----------------- 
													-----------------------------------------

AXIS_fifo_input : entity work.AXIS_fifo_0
  PORT MAP (
    ACLK             => clk125,
    ARESETN          => rst_n,

	--input from user
    S00_AXIS_ACLK    => clk125,
    S00_AXIS_ARESETN => rst_n,
    S00_AXIS_TVALID  => userRxDataValids,
    S00_AXIS_TREADY  => userRxDataReadys,
    S00_AXIS_TDATA   => userRxDataChannels,
    S00_AXIS_TLAST   => userRxDataLasts,
	--output to microblaze, make sure that the microblaze ports still work on its clock!
    M00_AXIS_ACLK    => clock_generator_0_CLKOUT0_pins,
    M00_AXIS_ARESETN => rst_n,
	 M00_AXIS_TVALID  => microblaze_0_s0_AXIS_TVALID_pins,
    M00_AXIS_TREADY  => microblaze_0_s0_AXIS_TREADY_pins,
    M00_AXIS_TDATA   => microblaze_0_s0_AXIS_TDATA_pins,
    M00_AXIS_TLAST   => microblaze_0_s0_AXIS_TLAST_pins,
	  
	 S00_FIFO_DATA_COUNT => S00_FIFO_DATA_COUNT_input_fifos,
	 M00_FIFO_DATA_COUNT => M00_FIFO_DATA_COUNT_input_fifos
  );

													-----------------------------------------
													-------------FIFO OUTPUT----------------- 
													-----------------------------------------
													
AXIS_fifo_output : entity work.AXIS_fifo_1
  PORT MAP (
    ACLK             => clk125,
    ARESETN          => rst_n,

	--input from microblaze, make sure the microblaze ports run on its clock!
    S00_AXIS_ACLK    => clock_generator_0_CLKOUT0_pins,
    S00_AXIS_ARESETN => rst_n,
    S00_AXIS_TVALID  => microblaze_0_M0_AXIS_TVALID_pins,
    S00_AXIS_TREADY  => microblaze_0_M0_AXIS_TREADY_pins,
    S00_AXIS_TDATA   => microblaze_0_M0_AXIS_TDATA_pins,
    S00_AXIS_TLAST   => microblaze_0_M0_AXIS_TLAST_pins,
	 S00_AXIS_TKEEP   => x"F", 										--keep everything the microblaze sends
		--input from data processessing
    S01_AXIS_ACLK    => clock_generator_0_CLKOUT0_pins,
    S01_AXIS_ARESETN => rst_n,
	 S01_AXIS_TVALID  => evtDataValid,
    S01_AXIS_TREADY  => evtDataFifoReady,
    S01_AXIS_TDATA   => evtData,
    S01_AXIS_TLAST   => evtDataLast,	
	 S01_AXIS_TKEEP   => evtDataKeep,	
		--output to user
    M00_AXIS_ACLK    => clk125,
    M00_AXIS_ARESETN => rst_n,
    M00_AXIS_TVALID  => userTxDataValids,
    M00_AXIS_TREADY  => userTxDataReadys,
    M00_AXIS_TDATA   => userTxDataChannels,
    M00_AXIS_TLAST   => userTxDataLasts,
	 M00_AXIS_TKEEP	=> M00_AXIS_TKEEP, 												--Keep Everything this FIFO Sends

    S00_ARB_REQ_SUPPRESS => S00_ARB_REQ_SUPPRESS,
    S01_ARB_REQ_SUPPRESS => S01_ARB_REQ_SUPPRESS,
	 
    S00_FIFO_DATA_COUNT => S00_FIFO_DATA_COUNT_output_fifos,
	 S01_FIFO_DATA_COUNT => S01_FIFO_DATA_COUNT_output_fifos,
	 M00_FIFO_DATA_COUNT => M00_FIFO_DATA_COUNT_output_fifos
  );
 
 	--supress signals on the input fifo, signals are active high, but no need as of yet.
	S00_ARB_REQ_SUPPRESS <= '0';
	S01_ARB_REQ_SUPPRESS <= '0';


end Behavioral;

