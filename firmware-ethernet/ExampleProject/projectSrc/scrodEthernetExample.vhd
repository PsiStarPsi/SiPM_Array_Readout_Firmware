library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
use work.Eth1000BaseXPkg.all;
use work.GigabitEthPkg.all;

library UNISIM;
use UNISIM.VComponents.all;

entity scrodEthernetExample is
   generic (
      NUM_IP_G        : integer := 2;
      GATE_DELAY_G    : time := 1 ns
   );
   port ( 
      --ASIC Scrod ports --Side "A"
		AsicOut_TRIG_OUTPUT_R0_C0_CH : in slv(7 downto 0);
		AsicOut_TRIG_OUTPUT_R0_C1_CH : in slv(7 downto 0);
		AsicOut_TRIG_OUTPUT_R0_C2_CH : in slv(7 downto 0);
		AsicOut_TRIG_OUTPUT_R0_C3_CH : in slv(7 downto 0);
		
		AsicOut_TRIG_OUTPUT_R1_C0_CH : in slv(7 downto 0);
		AsicOut_TRIG_OUTPUT_R1_C1_CH : in slv(7 downto 0);
		AsicOut_TRIG_OUTPUT_R1_C2_CH : in slv(7 downto 0);
		AsicOut_TRIG_OUTPUT_R1_C3_CH : in slv(7 downto 0);
		
--		--ASIC Scrod ports --Side "B"
--		AsicOut_TRIG_OUTPUT_R2_C0_CH : in slv(7 downto 0);
--		AsicOut_TRIG_OUTPUT_R2_C1_CH : in slv(7 downto 0);
--		AsicOut_TRIG_OUTPUT_R2_C2_CH : in slv(7 downto 0);
--		AsicOut_TRIG_OUTPUT_R2_C3_CH : in slv(7 downto 0);
--		
--		AsicOut_TRIG_OUTPUT_R3_C0_CH : in slv(7 downto 0);
--		AsicOut_TRIG_OUTPUT_R3_C1_CH : in slv(7 downto 0);
--		AsicOut_TRIG_OUTPUT_R3_C2_CH : in slv(7 downto 0);
--		AsicOut_TRIG_OUTPUT_R3_C3_CH : in slv(7 downto 0);
		
		-- Serial interfaces to IRS3D
		AsicIn_REG_CLEAR : out sl;
		AsicIn_PCLK      : out slv(7 downto 0);
		AsicIn_SCLK      : out sl;
		AsicIn_SIN       : out sl;
		
		-- Direct GT connections
      gtTxP        : out sl;
      gtTxN        : out sl;
      gtRxP        :  in sl;
      gtRxN        :  in sl;
      gtClkP       :  in sl;
      gtClkN       :  in sl;

      -- Alternative clock input
      fabClkP      :  in sl;
      fabClkN      :  in sl;
      -- SFP transceiver disable pin
      txDisable    : out sl;
      -- Status and diagnostics out
      ethSync      : out  sl;
      ethReady     : out  sl;

      --must declare led..    
		led          : out  slv(15 downto 0)

      );
end scrodEthernetExample;

architecture Behavioral of scrodEthernetExample is

	--connecting ports for the data_processing_top module for the ASIC pins
  signal input_pins_A   : slv(63 downto 0);
  --signal input_pins_B   : slv(63 downto 0);
  signal data_addr_befs : slv(3 downto 0);
  signal data_addr_afts : slv(3 downto 0);
  signal dataReadys		: sl;

  signal fabClk       		: sl;
  signal ethClk62     		: sl;
  signal ethClk125         : sl;
  --signal ethClk125_gen		: sl;
  signal clk100    		   : slv(2 downto 0);
  signal clk400_PLL			: slv(2 downto 0);
  signal clk400_slv        : slv(2 downto 0);
  signal ioce_slv				: slv(2 downto 0);
  
  signal clkfb_in			   : slv(2 downto 0);
  
  signal locked				: slv(2 downto 0);
  
  --microblaze clk to control the reg map
  signal microblaze_clk_gen_out : sl;

  signal userRst75     : sl;
  signal userRst125	  : sl;
  --signal userRst_O   : sl;

  signal ethRxLinkSync  : sl;
  signal ethAutoNegDone : sl;

  -- User Data interfaces
  signal userTxDataChannels      : slv(7 downto 0);
  signal userTxDataValids        : sl;
  signal userTxDataLasts         : sl;
  signal userTxDataReadys        : sl;

  signal userRxDataChannels      : slv(7 downto 0);
  signal userRxDataValids        : sl;
  signal userRxDataLasts         : sl;
  signal userRxDataReadys        : sl;

	--IO signals
  signal iomodule_0_IO_Addr_Strobe_pin  : std_logic;
  signal iomodule_0_IO_Read_Strobe_pin  : std_logic;
  signal iomodule_0_IO_Write_Strobe_pin : std_logic;
  signal iomodule_0_IO_Address_pin 	    : std_logic_vector(31 downto 0);
  signal iomodule_0_IO_Byte_Enable_pin  : std_logic_vector(3 downto 0);
  signal iomodule_0_IO_Write_Data_pin   : std_logic_vector(31 downto 0);
  signal iomodule_0_IO_Read_Data_pin    : std_logic_vector(31 downto 0);
  signal iomodule_0_IO_Ready_pin 		 : std_logic;

	signal evtData 			: slv(31 downto 0);
	signal evtDataFifoReady : sl;
	signal evtDataLast      : sl;
	signal evtDataValid 		: sl;
	signal evtDataKeep		: slv(3 downto 0);
	
	signal prt_LAPPD_srcMac : slv(63 downto 0);
	signal prt_LAPPD_srcIp  : slv(31 downto 0);
	
	signal prt_NBIC_destMac : slv(63 downto 0);
	signal prt_NBIC_destIp  : slv(31 downto 0);
	signal prt_NBIC_ports   : slv(31 downto 0);
	
	signal soft_trigger		: sl;
	signal evtNumber		   : slv(31 downto 0);
	
  -- Vivado attributes to keep signals for debugging
  attribute dont_touch : string;
  attribute dont_touch of led : signal is "true";  
   
begin
	
   ethSync           <= ethRxLinkSync;
   ethReady          <= ethAutoNegDone;
	
	--used in broken design
	--fabClk <= clk100(0);
	
   --leave FabClk alone..
	--fabClk is undeclared before here..
   U_IBUFGDS : IBUFGDS port map ( I => fabClkP, IB => fabClkN, O => fabClk);
   
									--------------------------------
									-- Gigabit Ethernet Interface --
									--------------------------------
   U_S6EthTop : entity work.S6EthTop
      generic map (
        NUM_IP_G     => 2,
        --included from A7
        GATE_DELAY_G => GATE_DELAY_G
      )
      port map (
         -- Direct GT connections
         gtTxP           => gtTxP, --used input signals
         gtTxN           => gtTxN,
         gtRxP           => gtRxP,
         gtRxN           => gtRxN,
         gtClkP          => gtClkP, --used in U_IBUFDS
         gtClkN          => gtClkN, --used in U_IBUFDS
         -- --not included in A7
         -- -- Alternative clock input from fabric
         fabClkIn        => fabClk,
         -- SFP transceiver disable pin
         txDisable       => txDisable,
         -- Clocks out from Ethernet core
         ethUsrClk62     => ethClk62,
         ethUsrClk125    => ethClk125,
         -- Status and diagnostics out
         ethSync         => ethRxLinkSync,
         ethReady        => ethAutoNegDone,
         led             => led,
         -- User clock inputs
         userClk         => ethClk125,
         userRstIn       => '0',
         userRstOut      => userRst125,

         -- all data below has lost index: (1)
         userTxData      => userTxDataChannels,
         userTxDataValid => userTxDataValids,
         userTxDataLast  => userTxDataLasts,
         userTxDataReady => userTxDataReadys,

         --received data
         userRxData      => userRxDataChannels,
         userRxDataValid => userRxDataValids,
         userRxDataLast  => userRxDataLasts,
         userRxDataReady => userRxDataReadys
      );

								--------------------------------------
								-- MicroBlaze ISE Spartan 6 Wrapper --
								--------------------------------------

microblaze_0 : entity work.self_wrapper_axi_microblaze
	port map (
 
			userRstIn          => '0',
			userClk				 => ethClk125,
			--clk100 				 => microblaze_clk_gen_out, --added this signal
				
			--transmitted data
			userTxDataChannel => userTxDataChannels,
         userTxDataValid   => userTxDataValids,
         userTxDataLast    => userTxDataLasts,
         userTxDataReady   => userTxDataReadys,
         
			--received data
         userRxDataChannel => userRxDataChannels,
         userRxDataValid   => userRxDataValids,
         userRxDataLast    => userRxDataLasts,
         userRxDataReady   => userRxDataReadys,
			
			--signals added from broken
			evtDataValid      => evtDataValid,
			evtData      		=> evtData,
			evtDataLast       => evtDataLast,
			evtDataFifoReady  => evtDataFifoReady,
			evtDataKeep			=> evtDataKeep,
						
			iomodule_0_IO_Addr_Strobe_pin   => iomodule_0_IO_Addr_Strobe_pin,
			iomodule_0_IO_Read_Strobe_pin   => iomodule_0_IO_Read_Strobe_pin,
			iomodule_0_IO_Write_Strobe_pin  => iomodule_0_IO_Write_Strobe_pin,
			iomodule_0_IO_Address_pin 		  => iomodule_0_IO_Address_pin,
			iomodule_0_IO_Byte_Enable_pin   => iomodule_0_IO_Byte_Enable_pin,
			iomodule_0_IO_Write_Data_pin    => iomodule_0_IO_Write_Data_pin,
			iomodule_0_IO_Read_Data_pin 	  => iomodule_0_IO_Read_Data_pin,
			iomodule_0_IO_Ready_pin         => iomodule_0_IO_Ready_pin,
			
			proc_sys_reset_0_Interconnect_aresetn_pin => userRst75,
			microblaze_clk_gen_out          => microblaze_clk_gen_out
		
      );
     
							---------------------------------------
							--------- REGISTER CONTROLS -----------
							---------------------------------------
	
	Inst_RegControl: entity work.RegControl PORT MAP(
		clk           => microblaze_clk_gen_out,
		sRst 			  => userRst75,
		regAddr 		  => iomodule_0_IO_Address_pin,
		regAddrStrb   => iomodule_0_IO_Addr_Strobe_pin,
		regWrStrb 	  => iomodule_0_IO_Write_Strobe_pin,
		regRdStrb     => iomodule_0_IO_Read_Strobe_pin,
		regReady 	  => iomodule_0_IO_Ready_pin,
		regWrData  	  => iomodule_0_IO_Write_Data_pin,
		regRdData 	  => iomodule_0_IO_Read_Data_pin,
		regDataByteEn => iomodule_0_IO_Byte_Enable_pin,
		-- Pins to external devices
		AsicIn_REG_CLEAR => AsicIn_REG_CLEAR,
      AsicIn_PCLK      => AsicIn_PCLK,
      AsicIn_SCLK      => AsicIn_SCLK,
      AsicIn_SIN       => AsicIn_SIN,
		--signals below added from broken, must each cross their own clock domain..
		data_addr_aft    => data_addr_afts,
		data_addr_bef    => data_addr_befs,
		
		prt_LAPPD_srcMac => prt_LAPPD_srcMac,
		prt_LAPPD_srcIp  => prt_LAPPD_srcIp,
		prt_NBIC_destMac => prt_NBIC_destMac,
		prt_NBIC_destIp  => prt_NBIC_destIp,
		prt_NBIC_ports	  => prt_NBIC_ports,		
		
		evtNumber 		  => evtnumber,
		soft_trigger 	  => soft_trigger
	);

										---------------------------------------
										-- Data Processing / Handling Module --
										---------------------------------------
	 
------------------------------------ASSIGN PINS TO SIGNAL VALUES--------------------------------------------------
	--ASIC Scrod ports --Side "A"
	input_pins_a <= 
							AsicOut_TRIG_OUTPUT_R1_C3_CH &
							AsicOut_TRIG_OUTPUT_R1_C2_CH &
							AsicOut_TRIG_OUTPUT_R1_C1_CH &
							AsicOut_TRIG_OUTPUT_R1_C0_CH &
							
							AsicOut_TRIG_OUTPUT_R0_C3_CH &
							AsicOut_TRIG_OUTPUT_R0_C2_CH &
							AsicOut_TRIG_OUTPUT_R0_C1_CH &
							AsicOut_TRIG_OUTPUT_R0_C0_CH;
--ASIC Scrod ports --Side "B"
--input_pins_b <= 
--							AsicOut_TRIG_OUTPUT_R3_C3_CH &
--							AsicOut_TRIG_OUTPUT_R3_C2_CH &
--							AsicOut_TRIG_OUTPUT_R3_C1_CH &
--							AsicOut_TRIG_OUTPUT_R3_C0_CH &
--							
--							AsicOut_TRIG_OUTPUT_R2_C3_CH &
--							AsicOut_TRIG_OUTPUT_R2_C2_CH &
--							AsicOut_TRIG_OUTPUT_R2_C1_CH &
--							AsicOut_TRIG_OUTPUT_R2_C0_CH;

--------------------------------------------------------------------------------------------------------------------	 
	data_processing0 : entity work.data_processing_top 
    Port Map ( 
			  --inputs from the ASIC / FPGA to take the DATA in..
			  clk100            => clk100,					--note that this needs to be that 100 MHz clk..
			  clk400_slv        => clk400_slv,
           clkDataFSM		  => microblaze_clk_gen_out,
			  rstFSM            => userRst75,
			  rstDATA			  => userRst125,
           input_pins        => input_pins_a,			--std_logic_vector of the 64 pins from the SiPm face..
			  data_addr_bef	  => data_addr_befs,			--4 bit slv to determine the num of addr to read before the hit
			  data_addr_aft     => data_addr_afts,			--4 bit slv to determine the num of addr to read after the hit
			  dataReady         => dataReadys,				--1 bit sl to say when the data is ready to read

			  --signals added from broken
			  evtDataValid      => evtDataValid,
			  evtData      	  => evtData,
			  evtDataLast       => evtDataLast,
			  evtDataFifoReady  => evtDataFifoReady,
			  evtDataKeep		  => evtDataKeep,
			  
			  prt_LAPPD_srcMac => prt_LAPPD_srcMac,
			  prt_LAPPD_srcIp  => prt_LAPPD_srcIp,
			  prt_NBIC_destMac => prt_NBIC_destMac,
		     prt_NBIC_destIp  => prt_NBIC_destIp,
			  prt_NBIC_ports	 => prt_NBIC_ports,
			  soft_trigger		 => soft_trigger,
			  ioce_slv			 => ioce_slv
  
			);	 
	 
--------------------------------------------------------------------------------------------------------
--------------------------------------------clk gen-----------------------------------------------------
------------------------------------------------------------------------------------------------------
--
--	bufio_2 : BufIO2
--		Port Map(
--			I     	=> ethClk125,
--			DivClk	=>	ethClk125_gen
--		);


clk_generate : for i in 0 to 2 generate 
	

	clk_gen: entity work.clk_gen
	  port map
		(-- Clock in ports
		 CLK_IN1	  => ethClk125,
		 -- Clock out ports
		 CLK_OUT2  => clk100(i),
		 CLK_OUT1  => clk400_PLL(i),
		 CLKFB_out => open,
		 CLKFB_IN  => CLKFB_IN(i),
		 RESET     => userRst125,
		 LOCKED    => locked(i)
		 );
	 -- Status and control signals

phase_lock : bufPLL
	Generic Map(
		ENABLE_SYNC => TRUE --false when driven by a buffG which is possible for ~300MHz cllk400 out..
	)
	port map (
		GCLK  		 => clk100(i),
		PLLIN  		 => clk400_PLL(i),
		locked 		 => locked(i), 
		lock   		 => open,
		ioclk  		 => clk400_slv(i),
		serdesstrobe => ioce_slv(i) --place in the serdes2 primitive blocks
	);	
	
bufio2fb_gen : BUFIO2FB 
		Generic Map(
			DIVIDE_BYPASS => TRUE
		)
		port map (
			I => clk100(i),
			O => clkfb_in(i)  --pin the 
		);
	
end generate;
--		

	 
end Behavioral;
