library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
use work.Eth1000BaseXPkg.all;
use work.GigabitEthPkg.all;

library UNISIM;
use UNISIM.VComponents.all;

entity S6EthTop is
   generic (
     NUM_IP_G        : integer := 2; --not included in A7
     GATE_DELAY_G    : time    := 1 ns
   );
   port ( 
      -- Direct GT connections
      gtTxP           : out sl;
      gtTxN           : out sl;
      gtRxP           :  in sl;
      gtRxN           :  in sl;
      gtClkP          :  in sl;
      gtClkN          :  in sl;
      -- SFP transceiver disable pin
      txDisable       : out sl;
      -- Clocks out from Ethernet core
      ethUsrClk62     : out sl;
      ethUsrClk125    : out sl;

      -- Status and diagnostics out
      ethSync         : out  sl;
      ethReady        : out  sl;
      led             : out  slv(15 downto 0);
      -- User data paths in and out, including clocks and reset
      userClk         : in  sl;
      userRstIn       : in  sl;
      userRstOut      : out sl;
		
      -- TX data is sent out on userClk domain
      userTxData      : in  slv(7 downto 0);
      userTxDataValid : in  sl;
      userTxDataLast  : in  sl;
      userTxDataReady : out sl;
      -- RX data comes in on clk125 domain
      userRxData      : out slv(7 downto 0);
      userRxDataValid : out sl;
      userRxDataLast  : out sl;
      userRxDataReady : in  sl;

      
      --not included in A7
      -- Alternative clock input from fabric
      fabClkIn        :  in sl := '0'

      -- --am going to let the microblaze take care of these ports..
      -- -- Core settings in 
      -- macAddr         : in  MacAddrType := MAC_ADDR_DEFAULT_C;
      -- ipAddrs         : in  IpAddrArray(NUM_IP_G-1 downto 0) := (others => IP_ADDR_DEFAULT_C);
      -- udpPorts        : in  Word16Array(NUM_IP_G-1 downto 0) := (others => (others => '0'))
      );
end S6EthTop;

architecture Behavioral of S6EthTop is

   signal gtClk        : sl;
   signal ethClk62     : sl;
   signal ethClk62Rst  : sl;
   signal ethClk125    : sl;
   signal ethClk125Rst : sl;

   signal dcmClkValid   : sl;
   signal dcmSpLocked   : sl;
   signal usrClkValid   : sl;
   signal usrClkLocked  : sl;
   signal pllLock0      : sl;
   signal gtpResetDone0 : sl;
  --KK       
  --included from A7ethtop.vhd..--      
   signal rxResetDone    : sl;
   signal txResetDone    : sl;
   signal rxFsmResetDone : sl;
   signal txFsmResetDone : sl;
  --

   signal gtpReset0     : sl;
   signal gtpReset1     : sl;
   signal txReset0      : sl;
   signal txReset1      : sl;
   signal rxReset0      : sl;
   signal rxReset1      : sl;
   signal rxBufReset0   : sl;
   signal rxBufReset1   : sl;

   signal rxBufStatus0  : slv(2 downto 0);
   signal rxBufStatus1  : slv(2 downto 0);
   signal txBufStatus0  : slv(1 downto 0);
   signal txBufStatus1  : slv(1 downto 0);
   signal rxBufError0   : sl;
   signal rxBufError1   : sl;

   signal rxByteAligned0   : sl;
   signal rxByteAligned1   : sl;
   signal rxEnMCommaAlign0 : sl;
   signal rxEnMCommaAlign1 : sl;
   signal rxEnPCommaAlign0 : sl;
   signal rxEnPCommaAlign1 : sl;

   signal ethRxLinkSync  : sl;
   signal ethAutoNegDone : sl;

   signal phyRxLaneIn    : EthRxPhyLaneInType;
   signal phyTxLaneOut   : EthTxPhyLaneOutType;
   
   signal tpData      : slv(31 downto 0);
   signal tpDataValid : sl;
   signal tpDataLast  : sl;
   signal tpDataReady : sl;

   signal userRst     : sl;

   -- --KK
   -- --unused in A7ethtop.vhd..--   
   -- signal fabClk       : sl; --renamed
   -- signal fabClkRst    : sl; --renamed

  --KK
  --included from A7ethtop.vhd..--   
   signal gte2Clk     : sl; --renames: fabClk
   signal gte2ClkRst  : sl; --renames: fabClkRst

   signal macTxData   : EthMacDataType;
   signal macRxData   : EthMacDataType;

   signal macBadCrcCount : slv(15 downto 0);

   attribute dont_touch : string;
   attribute dont_touch of rxFsmResetDone : signal is "true";
   attribute dont_touch of txFsmResetDone : signal is "true";  
   attribute dont_touch of rxResetDone    : signal is "true";
   attribute dont_touch of txResetDone    : signal is "true";
   attribute dont_touch of macBadCrcCount : signal is "true";

   
begin

   txDisable         <= '0';
   ethSync           <= ethRxLinkSync;
   ethReady          <= ethAutoNegDone;
   ethUsrClk62       <= ethClk62;
   ethUsrClk125      <= ethClk125;
   userRstOut        <= userRst;
   
   led(0)            <= dcmSpLocked;
   led(1)            <= dcmClkValid;
   led(2)            <= not(gtpReset0);
   led(3)            <= gtpResetDone0;
   led(4)            <= pllLock0;
   led(5)            <= usrClkLocked;
   led(6)            <= usrClkValid;
   led(7)            <= ethRxLinkSync;
   led(8)            <= ethAutoNegDone;
   led(9)            <= not(ethClk62Rst);
   led(10)           <= not(ethClk125Rst);
   led(15 downto 11) <= (others => '1');

   --fabClks don't exist in A7ethTop..
   gte2Clk <= fabClkIn;

   --KK
   --included in the wrapper instead..
   --not included in A7Ethtop
   U_IBUFDS  : IBUFDS  port map ( I => gtClkP,  IB => gtClkN,  O => gtClk);

   --all of the following sync bits are used in the GtpS6 entity which are
   --removed from the A7 entity..
   U_GtpS6 : entity work.GtpS6
      generic map (
         -- Reference clock selection --
         -- 000: CLK00/CLK01 selected
         -- 001: GCLK00/GCLK01 selected
         -- 010: PLLCLK00/PLLCLK01 selected
         -- 011: CLKINEAST0/CLKINEAST0 selected
         -- 100: CLK10/CLK11 selected
         -- 101: GCLK10/GCLK11 selected
         -- 110: PLLCLK10/PLLCLK11 selected
         -- 111: CLKINWEST0/CLKINWEST1 selected 
         REF_SEL_PLL0_G => "001",
         REF_SEL_PLL1_G => "001"
      )
      port map (

           ------------------
           -- USED SIGNALs --
           ------------------

        -- Input signals (raw) 
         gtpRxP0       => gtRxP,
         gtpRxN0       => gtRxN,
         gtpTxP0       => gtTxP,
         gtpTxN0       => gtTxN,
         -- User clock out
         usrClkOut     => ethClk62,
         usrClkX2Out   => ethClk125,
         -- Clocking & reset 
         gtpClkIn      => gte2Clk, --used but renamed to gte2Clk
         -- General status outputs
         pllLock0      => pllLock0,--renamed from Plllock 

         --note none of the open signals are included in A7
         
         -- Data interfaces
         rxDataOut0    => phyRxLaneIn.data,
         txDataIn0     => phyTxLaneOut.data,

         -- RX status
         rxCharIsK0       => phyRxLaneIn.dataK,
         rxDispErr0       => phyRxLaneIn.dispErr, -- out slv(1 downto 0);
         rxNotInTable0    => phyRxLaneIn.decErr, -- out slv(1 downto 0);
         rxByteAligned0   => rxByteAligned0, -- out std_logic;
         rxByteAligned1   => rxByteAligned1, -- out std_logic;

         -- TX status
         txCharIsK0       => phyTxLaneOut.dataK, --  in slv(1 downto 0);
      
           --------------------
           -- UNUSED SIGNALs --
           --------------------

         --Input signals (raw)
         gtpRxP1       => '0',
         gtpRxN1       => '0',
         gtpTxP1       => open,
         gtpTxN1       => open,

         -- General status outputs
         pllLock1      => open,    --does not exist in A7
         
         -- Data interfaces
         rxDataOut1    => open,
         txDataIn1     => (others => '0'),
         gtpReset0     => gtpReset0,
         gtpReset1     => gtpReset1,
         txReset0      => txReset0,
         txReset1      => txReset1,
         rxReset0      => rxReset0,
         rxReset1      => rxReset1,
         rxBufReset0   => rxBufReset0,
         rxBufReset1   => rxBufReset1,

         -- DCM clocking
         dcmClkValid   => dcmClkValid,
         dcmSpLocked   => dcmSpLocked,
         usrClkValid   => usrClkValid,
         usrClkLocked  => usrClkLocked,

         --Rx Status
         rxEnMCommaAlign0 => rxEnMCommaAlign0, --  in std_logic;
         rxEnMCommaAlign1 => rxEnMCommaAlign1, --  in std_logic;
         rxEnPCommaAlign0 => rxEnPCommaAlign0, --  in std_logic;
         rxEnPCommaAlign1 => rxEnPCommaAlign1, --  in std_logic;
         rxCharIsComma0   => open,
         rxCharIsComma1   => open,
         rxCharIsK1       => open,
         rxDispErr1       => open, -- out slv(1 downto 0);
         rxNotInTable1    => open, -- out slv(1 downto 0);
         rxRunDisp0       => open, -- out slv(1 downto 0);
         rxRunDisp1       => open, -- out slv(1 downto 0);
         rxClkCor0        => open, -- out slv(2 downto 0);
         rxClkCor1        => open, -- out slv(2 downto 0);
         rxBufStatus0     => rxBufStatus0, -- out slv(2 downto 0);
         rxBufStatus1     => rxBufStatus1, -- out slv(2 downto 0);
         
         -- TX status
         txCharDispMode0  => "00", --  in slv(1 downto 0) := "00";
         txCharDispMode1  => "00", --  in slv(1 downto 0) := "00";
         txCharDispVal0   => "00", --  in slv(1 downto 0) := "00";
         txCharDispVal1   => "00", --  in slv(1 downto 0) := "00";
         txCharIsK1       => "00", --  in slv(1 downto 0);
         txRunDisp0       => open, -- out slv(1 downto 0);
         txRunDisp1       => open, -- out slv(1 downto 0);
         txBufStatus0     => txBufStatus0, -- out slv(1 downto 0);
         txBufStatus1     => txBufStatus1, -- out slv(1 downto 0);
         
         -- General status outputs         
         gtpResetDone0 => gtpResetDone0,
         gtpResetDone1 => open,

         -- Loopback settings
         loopbackIn0      => "000", -- :  in slv(2 downto 0) := "000";
         loopbackIn1      => "000"  -- :  in slv(2 downto 0) := "000"; 

         
           --------------------------
           -- NOT INCLUDED SIGNALs --
           --------------------------

         -- -- TX data interfaces
         -- txDataIn          => phyTxLaneOut.data, --: in  slv(15 downto
         -- 0);--used but as txDataIn0
         -- -- Direct GT connections
         -- gtClkP            => gtClkP,
         -- gtClkN            => gtClkN,
         -- -- Resets are done
         -- txFsmResetDoneOut => txFsmResetDone, --: out sl;
         -- rxFsmResetDoneOut => rxFsmResetDone, --: out sl;
         -- rxResetDoneOut    => rxResetDone,    --: out sl;
         -- txResetDoneOut    => txResetDone,    --: out sl;
         );

   --none of the comma alignment is used in A7
   -- Simple comma alignment
   rxEnMCommaAlign0 <= not(rxByteAligned0);
   rxEnPCommaAlign0 <= not(rxByteAligned0);
   rxEnMCommaAlign1 <= not(rxByteAligned1);
   rxEnPCommaAlign1 <= not(rxByteAligned1);

   -- Reset sequencing, as per UG386, Table 2-14
   -- Not all resets are implemented, only those for the functionality
   -- we care about.
   --
   -- 1. Perform GTP reset after turning on the reference clock
   U_GtpReset0 : entity work.SyncBit
      port map (
         clk      => gte2Clk,
         rst      => not(dcmClkValid),
         asyncBit => '0',
         syncBit  => gtpReset0 --A7 does nothing with gtpReset0
      );
   gtpReset1 <= gtpReset0; --A7 does nothing with the gtpReset1
   -- 2. Assert rxReset and txReset when usrClk, usrClk2 is not stable
   -- 3. txReset should be asserted on tx Buffer over/underflow

   U_RxReset0 : entity work.SyncBit
      generic map (
         INIT_STATE_G => '1'
      )
      port map (
         clk      => gte2Clk,
         rst      => not(usrClkValid) or not(dcmClkValid),
         asyncBit => '0',
         syncBit  => rxReset0 --A7 does nothing with rxReset0
      );
   rxReset1 <= rxReset0; --A7 does nothing with rxReset1
   U_TxReset0 : entity work.SyncBit
      generic map (
         INIT_STATE_G => '1'
      )
      port map (
         clk      => gte2Clk,
         rst      => not(usrClkValid) or txBufStatus0(1),
         asyncBit => '0',
         syncBit  => txReset0 --A7 does nothing with txReset0
      );
	U_TxReset1 : entity work.SyncBit
      generic map (
         INIT_STATE_G => '1'
      )
      port map (
         clk      => gte2Clk,
         rst      => not(usrClkValid) or txBufStatus1(1),--usrClkValid assigned
                                                         --only to led
         asyncBit => '0',
         syncBit  => txReset1 --A7 does nothing with txReset1
      );

   -- 4. rxBufReset should be asserted on rx buffer over/underflow 
   rxBufError0 <= '1' when rxBufStatus0 = "101" or rxBufStatus0 = "110" else '0';
   U_RxBufReset0 : entity work.SyncBit
      generic map (
         INIT_STATE_G => '1'
      )
      port map (
        clk      => gte2Clk
        ,
         rst      => rxBufError0, --A7 does nothing with rxBufError0
         asyncBit => '0',
         syncBit  => rxBufReset0 --A7 does nothing with rxbufReset0
      );
   rxBufError1 <= '1' when rxBufStatus1 = "101" or rxBufStatus1 = "110" else '0';
   U_RxBufReset1 : entity work.SyncBit
      generic map (
         INIT_STATE_G => '1'
      )
      port map (
         clk      => gte2Clk,
         rst      => rxBufError1, --A7 does nothing with rxBufError1
         asyncBit => '0',
         syncBit  => rxBufReset1 --A7 does nothing with rxBufReset1
      );

   --------------------------------
   -- Gigabit Ethernet Interface --
   --------------------------------
   U_Eth1000BaseXCore : entity work.Eth1000BaseXCore
      generic map (
         NUM_IP_G        => NUM_IP_G, --next three generics are unused
         MTU_SIZE_G      => 1500,
         LITTLE_ENDIAN_G => true,

         EN_AUTONEG_G    => true,
         GATE_DELAY_G    => GATE_DELAY_G
      )
      port map ( 
         -- 125 MHz clock and reset
         eth125Clk          => ethClk125,
         eth125Rst          => ethClk125Rst,
         -- 62 MHz clock and reset
         eth62Clk           => ethClk62,
         eth62Rst           => ethClk62Rst,
         -- Data to/from GT
         phyRxData          => phyRxLaneIn,
         phyTxData          => phyTxLaneOut,
         -- Status signals
         statusSync         => ethRxLinkSync,
         statusAutoNeg      => ethAutoNegDone,
         -- --all below signals NOT included --tentatively included in signals..
         -- MAC TX/RX data (125 MHz clock domain)
         macTxData          => macTxData,
         macRxData          => macRxData

       -- --all below signals are unused..
       -- -- User clock and reset
       -- --these below data types are instead ported to the macTx and macRx modules..  
       -- userClk            => userClk,
       -- userRst            => userRst,
       -- -- User data
       -- userTxData         => userTxData,
       -- userTxDataValid    => userTxDataValid,
       -- userTxDataLast     => userTxDataLast,
       -- userTxDataReady    => userTxDataReady,
       -- userRxData         => userRxData,
       -- userRxDataValid    => userRxDataValid,
       -- userRxDataLast     => userRxDataLast,
       -- userRxDataReady    => userRxDataReady
       -- Addressing
       --let microblaze take care of the addressing in the future..
       -- macAddr            => macAddr,
       -- ipAddrs            => ipAddrs,
       -- udpPorts           => udpPorts,
         );

   -- --------------------------------------------------------- --
   -- -- BELOW UNTIL RESET ARE BRAND NEW INSTANTIATED MODULES.. --
   -- --------------------------------------------------------- --

   ------------------------
   -- MAC Layer, RX data --
   ------------------------
   U_MacRx : entity work.Eth1000BaseXMacRx  
      generic map (
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map ( 
         -- 125 MHz ethernet clock in
         ethRxClk       => ethClk125,       --: in sl;
         ethRxRst       => ethClk125Rst,    --: in sl := '0';
         -- Incoming data from the 16-to-8 mux
         macDataIn      => macRxData,       --: in EthMacDataType;
         -- Outgoing bytes and flags to the applications
         macRxData      => userRxData,      --: out slv(7 downto 0);
         macRxDataValid => userRxDataValid, --: out sl;
         macRxDataLast  => userRxDataLast,  --: out sl;
         macRxBadFrame  => open,            --: out sl;
         -- Monitoring flags
         macBadCrcCount => macBadCrcCount   --: out slv(15 downto 0)
      ); 
   ------------------------
   -- MAC Layer, TX data --
   ------------------------
   U_MacTx : entity work.Eth1000BaseXMacTx 
      generic map (
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map ( 
         -- 125 MHz ethernet clock in
         ethTxClk         => ethClk125,       --: in  sl;
         ethTxRst         => ethClk125Rst,    --: in  sl := '0';
         -- User data to be sent
         userDataIn       => userTxData,      --: in  slv(7 downto 0);
         userDataValid    => userTxDataValid, --: in  sl;
         userDataLastByte => userTxDataLast,  --: in  sl;
         userDataReady    => userTxDataReady, --: out sl;
         -- Data out to the GTX
         macDataOut       => macTxData        --: out EthMacDataType
      ); 
      
   ---------------------------------------------------------------------------
   -- Resets
   ---------------------------------------------------------------------------
   -- Generate stable reset signal
   U_PwrUpRst : entity work.InitRst
      generic map (
         RST_CNT_G    => 25000000, --value in A7ethtop is 7812500
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map (
         clk     => gte2Clk, --named gte2Clk
         syncRst => gte2ClkRst --named gte2Clk
      );
   -- Synchronize the reset to the 125 MHz domain
   U_RstSync125 : entity work.SyncBit
      generic map (
         INIT_STATE_G    => '1',
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map (
         clk      => ethClk125,
         rst      => '0',
         asyncBit => ethClk62Rst,
         syncBit  => ethClk125Rst
      );


-- Synchronize the reset to the 62 MHz domain
   U_RstSync62 : entity work.SyncBit
      generic map (
         INIT_STATE_G    => '1',
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map (
         clk      => ethClk125,
         rst      => '0',
         asyncBit => gte2ClkRst, --gte2ClkRst
         syncBit  => ethClk62Rst
      );
   -- User reset
   U_RstSyncUser : entity work.SyncBit
      generic map (
         INIT_STATE_G    => '1',
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map (
         clk      => userClk, --named userClk
         rst      => '0',
         asyncBit => ethClk62Rst or not(ethAutoNegDone) or userRstIn,
         syncBit  => userRst
      );
         
end Behavioral;

