library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
--use work.Version.all;
--use work.P1Pkg.all;
-- For Xilinx primitives
library UNISIM;
use UNISIM.VComponents.all;

entity RegMap is
  port (
    clk           : in  sl;
    sRst          : in  sl;
	 -- Pins to external devices
    AsicIn_REG_CLEAR : out sl;
    AsicIn_PCLK      : out slv(7 downto 0);
    AsicIn_SCLK      : out sl;
    AsicIn_SIN       : out sl;
    -- Register interfaces to UART controller
    regAddr       : in  slv(31 downto 0);
    regWrData     : in  slv(31 downto 0);
    regRdData     : out slv(31 downto 0);
    regReq        : in  sl;
    regOp         : in  sl;
    regAck        : out sl;
	 
	 --new conversion of signals to top levle 'ports' to send to data_processing_top
	 prt_LAPPD_srcMac : out slv(63 downto 0);
	 prt_LAPPD_srcIP  : out slv(31 downto 0);
	 
	 prt_NBIC_destMac : out slv(63 downto 0);
	 prt_NBIC_destIP  : out slv(31 downto 0);
	 prt_NBIC_ports   : out slv(31 downto 0);

	 data_addr_bef    : out slv(3 downto 0);
	 data_addr_aft    : out slv(3 downto 0);
	 
	 evtNumber        : in slv(31 downto 0);
	 soft_trigger     : out sl
	
    );
	 
end RegMap;

architecture Behavioral of RegMap is
  
  signal efuseVal      : slv(31 downto 0);
  signal deviceDna     : slv(63 downto 0);

  signal scratchPad    : slv(31 downto 0);
  
  -- Signals for LAPPD Board: SRC MAC,IP
  signal LAPPD_srcMac    : slv(63 downto 0);
  signal LAPPD_srcIP     : slv(31 downto 0);
  
  -- Signals for the NishiBackplaneIonCannon: Outgoing Port, Dest MAC, Dest IP, Dest port}
  signal NBIC_ports      : slv (31 downto 0);
  signal NBIC_destIP     : slv (31 downto 0);
  signal NBIC_destMac    : slv (63 downto 0);
  
  --signals for determining before and after port readings
  signal data_addr_befs  : slv(3 downto 0);
  signal data_addr_afts  : slv(3 downto 0);
  signal soft_trigger_s : sl;
   
  --evtNumber
  signal evtNumbers 		 : slv(31 downto 0);
  
  -- Signals for itchy and scratchy
  signal itchy_scratchy  : slv(31 downto 0);     
    
  -- IRS reset signal	 
  signal iAsicReset : sl := '0';

  -- Shim address interfaces signals to the IRS
  signal irsReq : sl := '0';
  signal irsOp  : sl := '0';
  signal irsAck : sl := '0';
  signal irsRdData : slv(31 downto 0) := (others => '0');
	 
  constant BITS_ADDR_C   : integer := 32;               
  constant BITS_DATA_C   : integer := 32;
  
  attribute dont_touch   : string;
--   attribute dont_touch of i2cSclT : signal is "true";
--   attribute dont_touch of i2cSdaT : signal is "true";

begin
	
	----------------------------------------------------------------------------------
	--assign the signals to the top level ports to have them read by data_processing--
	----------------------------------------------------------------------------------
	
	prt_LAPPD_srcMac <= LAPPD_srcMac;
	prt_LAPPD_srcIP  <= LAPPD_srcIP;
	
	prt_NBIC_destIP  <= NBIC_destIP;
	prt_NBIC_destMac <= NBIC_destMac;
	prt_NBIC_ports   <= NBIC_ports;
	
	data_addr_bef <= data_addr_befs;
	data_addr_aft <= data_addr_afts;
	soft_trigger  <= soft_trigger_s;
	
	AsicIn_REG_CLEAR <= iAsicReset;
	
	-----------------------------------------------------------------------------------
	----------------------------keefe changes 11/5/2018--------------------------------
	-----------------------------------------------------------------------------------
  process (clk) 
    variable adcAddr : integer range 0 to 3 := 0;
  begin
    if rising_edge(clk) then
      -- if sRst = '1' then
      --    p1ConfigReg <= CONFIG_TYPE_INIT_C;
      -- else
      -- Default for all registers write and read in one cycle.
      -- This can be overridden below for specific registers.
      regAck     <= regReq;
		irsReq     <= '0';
		irsOp      <= '0';
		iAsicReset <= '0';
		
		-- Defaults for pulsed signals
		soft_trigger_s <= '0';

      --
      -- Register mapping: provincial
      -- KC 10/20/18
      --
      -- *) Segmented at 4K boundaries based on "logical" subsystems
      -- *) Spaced by 32 bits to accommodate a full metadata register for
      --    each register.
      --
      if regAddr(15 downto 12) = x"0" then
        case regAddr(11 downto 0) is
          --- Registers: 0x000 (raw device stuff)
          when x"000" => regRdData <= x"c0decafe";
          when x"008" => regRdData <= deviceDna(31 downto 0);
          when x"010" => regRdData <= deviceDna(63 downto 32);
          when x"018" => regRdData <= efuseVal;
                         
          -- Signal itchy_scratchy
          when x"020" => regRdData <= itchy_scratchy;
                         if regOp = '1' and regReq = '1' then
                           itchy_scratchy <= regWrData;
                         end if;

          --- Registers: 0x100 (LAPPD uBlaze stuff)
          -- Signal LAPPD_srcMac
          when x"100" => regRdData <= LAPPD_srcMac (31 downto 0);
                        if regOp = '1' and regReq = '1' then
                          LAPPD_srcMac (31 downto 0) <= regWrData;
                        end if;          

          when x"108" => regRdData <= LAPPD_srcMac (63 downto 32);
                        if regOp = '1' and regReq = '1' then
                          LAPPD_srcMac (63 downto 32) <= regWrData;
                        end if;          

          -- Signal LAPPD_srcIP
          when x"110" => regRdData <= LAPPD_srcIP;
                        if regOp = '1' and regReq = '1' then
                          LAPPD_srcIP <= regWrData;
                        end if;

          -- Registers: 0x200 (NBIC hardware stuff)
          -- Signal NBIC_destMac
          when x"200" => regRdData <= NBIC_destMac (31 downto 0);
                        if regOp = '1' and regReq = '1' then
                          NBIC_destMac (31 downto 0) <= regWrData;
                        end if;          

          when x"208" => regRdData <= NBIC_destMac (63 downto 32);
                        if regOp = '1' and regReq = '1' then
                          NBIC_destMac (63 downto 32) <= regWrData;
                        end if;          

          -- Signal NBIC_destIP              
          when x"210" => regRdData <= NBIC_destIP;
                        if regOp = '1' and regReq = '1' then
                          NBIC_destIP <= regWrData;
                        end if;

          -- Signal NBIC_ports
          -- The source port is in the low bytes, the dest
          -- port is in the high bytes
          when x"218" => regRdData <= NBIC_ports;
                        if regOp = '1' and regReq = '1' then
                          NBIC_ports <= regWrData;
                        end if;

			 -- Set the boobcode if you tried to get something that wasn't there
          when others => regRdData <= x"B00BC0DE";
        end case;
 
	-----------------------------------------------------------------------------------
	--------keefe changes 11/5/2018 - incorporated addr modulation---------------------
	-----------------------------------------------------------------------------------
		
		elsif regAddr(15 downto 12) = x"1" then
			case regAddr(11 downto 0) is
			--set the # of addr aft
			 when x"000" => regRdData <= "0000000000000000000000000000" & data_addr_afts;
								if regOp = '1' and regReq = '1' then
									data_addr_afts <= regWrData(3 downto 0);
								end if;			
			--set the # of addr bef 
			 when x"004" => regRdData <= "0000000000000000000000000000" & data_addr_befs;
								if regOp = '1' and regReq = '1' then
									data_addr_befs <= regWrData(3 downto 0);
								end if;
			--read the evtNumber
--			 when x"008" => regRdData <= evtNumber; (currently commented out to prevent timing error..
--								if regOp = '1' and regReq = '1' then
--									evtNumbers <= regWrData;
--								end if;
			--set the soft trigget from this address						
          when x"028" => regRdData <= evtNumber; --read from the evt number during the triggering..
								if regOp = '1' then
									soft_trigger_s <= regReq;
								end if;
			-- Reset the IRS3D registers
         when x"030" => regRdData <= (others => '0');
			               iAsicReset <= regOp and regReq;
         -- other invalid cases
			when others => regRdData <= x"B00BCAFE";			 
		  end case;

	---------------------------------------------------------
	-------- Add IRS3D register control ---------------------
	---------------------------------------------------------
      elsif regAddr(15 downto 14) = x"1" then
		   irsReq    <= regReq;
			irsOp     <= regOp;
			regAck    <= irsAck;
			regRdData <= irsRdData;
		
		else
        regRdData    <= x"DEADC0DE";
      end if;
    end if;
  end process;

  -----------------------------------------------------
  -- Xilinx primitives or simple derivatives thereof --
  -----------------------------------------------------
--  -- One-time burnable eFUSE (32-bit)
--  U_Efuse : EFUSE_USR
--    generic map (
--      SIM_EFUSE_VALUE => X"00000000" -- Value of the 32-bit non-volatile value used in simulation
--      )
--    port map (
--      EFUSEUSR => efuseVal -- 32-bit output: User eFUSE register value output
--      );
--  -- Device DNA (64-bit)
  
  
  U_DeviceDna : entity work.DeviceDna
    port map ( 
      clk       => clk,
      rst       => sRst,
      -- Parallel interface for current ticks value
      dnaOut    => deviceDna
      );
  
  U_MultiIrsRegControl : entity work.MultiIrsRegControl
	 generic map (
	   NUM_IRS_G    => 8
    )
    port map (
      -- Core CLK
      clk           => clk,
      -- ASIC pins
      AsicIn_PCLK   => AsicIn_PCLK,
      AsicIn_SCLK   => AsicIn_SCLK,
      AsicIn_SIN    => AsicIn_SIN, 
      -- Register interfaces 
      irsNumber     => regAddr(13 downto 10),   --: in  slv( 3 downto 0);
      irsAddr       => regAddr( 9 downto  2),   --: in  slv( 7 downto 0);
      irsWrData     => regWrData(11 downto 0), --: in  slv(11 downto 0);
      irsRdData     => irsRdData, --: out slv(31 downto 0);
      irsReq        => irsReq,    --: in  sl;
      irsOp         => irsOp,     --: in  sl;
      irsAck        => irsAck     --: out sl
    );

end Behavioral;
