library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
--use work.Version.all;
--use work.P1Pkg.all;

entity RegControl is
   generic (
      GATE_DELAY_G : time := 1 ns;
      FAIL_WORD_G  : slv(31 downto 0) := x"4641494C";
      TIMEOUT_G    : unsigned(23 downto 0) := x"EE6B28" -- 100 ms timeout 
   );
   port (
      -- Clock and synchronous reset
      clk            : in  sl;
      sRst           : in  sl;
      -- Register interface to Microblaze IO module
      regAddr        : in  slv(31 downto 0);
      regAddrStrb    : in  sl;
      regWrStrb      : in  sl;
      regRdStrb      : in  sl;
      regReady       : out sl;
      regWrData      : in  slv(31 downto 0);
      regRdData      : out slv(31 downto 0);
      regDataByteEn  : in slv(3 downto 0);
		
		data_addr_bef  : out slv(3 downto 0);
		data_addr_aft  : out slv(3 downto 0);
		
		prt_LAPPD_srcMac : out slv(63 downto 0);
		prt_LAPPD_srcIP  : out slv(31 downto 0);
	 
		prt_NBIC_destMac : out slv(63 downto 0);
		prt_NBIC_destIP  : out slv(31 downto 0);
		prt_NBIC_ports   : out slv(31 downto 0);
		
		evtNumber        : in slv(31 downto 0);
		soft_trigger     : out sl
		
   );
end RegControl;

architecture Behavioral of RegControl is

   signal iRegAck    : sl;
   signal iRegRdData : slv(31 downto 0);

   type StateType is (IDLE_S, READ_S, WRITE_S, WAIT_S);

   type RegType is record
      state     : StateType;
      regAddr   : slv(31 downto 0);
      regWrData : slv(31 downto 0);
      regRdData : slv(31 downto 0);
      regReq    : sl;
      regOp     : sl;
      regReady  : sl;
      timer     : unsigned(23 downto 0);
   end record;
   
   constant REG_INIT_C : RegType := (
      state     => IDLE_S,
      regAddr   => (others => '0'),
      regWrData => (others => '0'),
      regRdData => (others => '0'),
      regReq    => '0',
      regOp     => '0',
      regReady  => '0',
      timer     => (others => '0')
   );
   
   signal curReg : RegType := REG_INIT_C;
   signal nxtReg : RegType := REG_INIT_C;

begin
   
   regReady <= curReg.regReady;
   regRdData <= curReg.regRdData;
   
   -- Asynchronous state logic
   process(curReg, regAddr, regAddrStrb, regWrStrb, regRdStrb, regWrData, regDataByteEn, iRegAck, iRegRdData) begin
      -- Set defaults
      nxtReg          <= curReg;
      nxtReg.regReq   <= '0';
      nxtReg.regReady <= '0';
      -- Actual state definitions
      case(curReg.state) is
         when IDLE_S  =>
            nxtReg.timer   <= (others => '0');
            if regAddrStrb = '1' then
               nxtReg.regAddr <= regAddr;
            end if;
            if regWrStrb = '1' then
               nxtReg.regReq    <= '1';
               nxtReg.regWrData <= regWrData;
               nxtReg.regOp     <= '1';
               nxtReg.state     <= WRITE_S;
            end if;
            if regRdStrb = '1' then
               nxtReg.regReq    <= '1';
               nxtReg.regOp     <= '0';
               nxtReg.state     <= READ_S;
            end if;
         when READ_S  =>
            nxtReg.timer  <= curReg.timer + 1;
            nxtReg.regReq <= '1';
            if iRegAck = '1' then
               nxtReg.regRdData <= iRegRdData;
               nxtReg.regReq    <= '0';
               nxtReg.state     <= WAIT_S;
            elsif curReg.timer = TIMEOUT_G then
               nxtReg.regRdData <= FAIL_WORD_G;
               nxtReg.regReq    <= '0';
               nxtReg.state     <= WAIT_S;
            end if; 
         when WRITE_S =>
            nxtReg.regReq <= '1';
            nxtReg.timer  <= curReg.timer + 1;
            if iRegAck = '1' then
               nxtReg.regReq <= '0';
               nxtReg.state  <= WAIT_S;
            elsif curReg.timer = TIMEOUT_G then
               nxtReg.regReq <= '0';
               nxtReg.state  <= WAIT_S;               
            end if;
         when WAIT_S =>
            nxtReg.regReq <= '0';
            if iRegAck = '0' then
               nxtReg.regReady <= '1';
               nxtReg.state    <= IDLE_S;
            end if;
         when others  =>
            nxtReg.state <= IDLE_S;
      end case;         
   end process;
   
   -- Synchronous part of state machine, including reset
   process(clk) begin
      if rising_edge(clk) then
         if (sRst = '1') then
            curReg <= REG_INIT_C after GATE_DELAY_G;
         else
            curReg <= nxtReg after GATE_DELAY_G;
         end if;
      end if;
   end process;

   -----------------------------------------
   -- Interface to main register map here --
   -----------------------------------------
   U_RegMap : entity work.RegMap
      port map (
         clk           => clk,
         sRst          => sRst,
         -- Pin connections to external devices
      --   I2C_SCL       => I2C_SCL,
       --  I2C_SDA       => I2C_SDA,
        -- adcSclk       => adcSclk,
        -- adcSen        => adcSen,
       --  adcSdata      => adcSdata,
       --  adcSdout      => adcSdout,
       --  henrySpiClk   => henrySpiClk, 
       --  henrySpiData  => henrySpiData,
       --  henrySpiLoad  => henrySpiLoad,
       --  henrySpiRdBit => henrySpiRdBit, 
         -- Register interfaces to this controller
         regAddr       => curReg.regAddr,
         regWrData     => curReg.regWrData,
         regRdData     => iRegRdData,
         regReq        => curReg.regReq,
         regOp         => curReg.regOp,
         regAck        => iRegAck,
		--keefe additions to read signals from reg map: 11/5/2018
			prt_LAPPD_srcMac => prt_LAPPD_srcMac,
			prt_LAPPD_srcIP  => prt_LAPPD_srcIP,	
			prt_NBIC_destMac => prt_NBIC_destMac,
			prt_NBIC_destIP  => prt_NBIC_destIP,
			prt_NBIC_ports   => prt_NBIC_ports,
			
			data_addr_aft    => data_addr_aft,
			data_addr_bef    => data_addr_bef,
			evtNumber 		  => evtNumber,
			soft_trigger     => soft_trigger
      );

end Behavioral;