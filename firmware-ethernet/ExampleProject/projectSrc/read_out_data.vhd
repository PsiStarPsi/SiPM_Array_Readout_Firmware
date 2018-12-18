--updated sim version 11/9/2018
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--Kurtis Sensei
--use work.UtilityPkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
--use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity read_out_data is
   generic (
      GATE_DELAY_G : time := 2 ns		
   );
	 Port ( 
			  clk100			   : in  STD_LOGIC;
           rst 			   : in  STD_LOGIC;
			  new_trigger     : in  STD_LOGIC;
           data_read_in    : in  STD_LOGIC_VECTOR(63 downto 0);
			  data_addr_hit   : in  STD_LOGIC_VECTOR(7 downto 0);
			  --data inputs to determine how many address to read before and after the trigger
			  data_addr_bef   : in  STD_LOGIC_VECTOR(3 downto 0);
			  data_addr_aft   : in  STD_LOGIC_VECTOR(3 downto 0);
			  --address and phase data to select what memory to read
           data_phase_out  : out STD_LOGIC_VECTOR(1 downto 0);
           data_read_out   : out STD_LOGIC_VECTOR(7 downto 0);		
			  --outputs to send to the FIFO
			  evtDataValid    : out std_logic;
			  evtData         : out std_logic_vector(31 downto 0);
			  evtDataLast     : out std_logic;
			  evtDataFifoReady: in  std_logic;
			  evtDataKeep		: out std_logic_vector(3 downto 0);
			  evtNumber       : out std_logic_vector(31 downto 0);
			  --regControl Ports
			 --new conversion of signals to top levle 'ports' to send to data_processing_top
			  prt_LAPPD_srcMac : in std_logic_vector(63 downto 0);
			  prt_LAPPD_srcIP  : in std_logic_vector(31 downto 0);
			  prt_NBIC_destMac : in std_logic_vector(63 downto 0);
			  prt_NBIC_destIP  : in std_logic_vector(31 downto 0);
			  prt_NBIC_ports   : in std_logic_vector(31 downto 0);
			  soft_trigger     : in std_logic;
			  --evtData
			  dataReady       : out std_logic
			  );
end read_out_data;


architecture Behavioral of read_out_data is


type StateType     is (chillin, ETH_HEADER_S, IPV4_HEADER_S, UDP_HEADER_S, HEADER, Phase_0, Phase_1, Phase_2, Phase_3, FOOTER, DONE);
   type Hit_Event is record
      state           : StateType;  
		evtNumber       : std_logic_vector(31 downto 0);
      evtData         : std_logic_vector(31 downto 0);
      evtAddrOut	    : std_logic_vector(7 downto 0);
		evtAddrStop		 : std_logic_vector(7 downto 0);
		evtPhaseSel     : std_logic_vector(1 downto 0);		
		phase_change    : std_logic;
		half_phase      : std_logic;
		num_addr_bef    : std_logic_vector(3 downto 0);
		num_addr_aft    : std_logic_vector(3 downto 0);
		evtDataValid    : std_logic;
      evtDataLast     : std_logic;
		evtDataKeep		 : std_logic_vector(3 downto 0);
      --eth and ipv4 members
		header_Count    : std_logic_vector(2 downto 0);
		dataReady       : std_logic;
   end record Hit_Event;

   constant HIT_INIT_C : Hit_Event := (
      state          => chillin,
      evtNumber      => (others => '0'),
      evtData        => (others => '0'),
      evtAddrOut     => (others => '0'),
		evtAddrStop    => (others => '0'), 
		evtPhaseSel    => "00",
		phase_change   => '0',
		half_phase     => '0',
		num_addr_bef   => "0010", --signals are written to the state vector outsite of the case statement and can be updated whenever..
		num_addr_aft   => "0010", --default is to read one before and one after..
		evtDataValid   => '0',
      evtDataLast    => '0',
		evtDataKeep		=> (others => '0'),
      --eth and ipv4 members
		header_Count   => "000",
		dataReady      => '0'
   );    

   signal r   : Hit_Event := HIT_INIT_C;
   signal rin : Hit_Event;

	signal data_read_ins     : std_logic_vector(63 downto 0);
	signal data_phase_outs   : std_logic_vector(1 downto 0);
	signal data_read_outs    : std_logic_vector(7 downto 0);
	signal data_addr_hits    : std_logic_vector(7 downto 0);
		
	signal evtCount			 : std_logic_vector(31 downto 0) := (others => '0'); --used to store the count to add to r.evtNumber which reads to top level port
	
	signal num_addr_befs     : std_logic_vector(3 downto 0);
	signal num_addr_afts     : std_logic_Vector(3 downto 0);
	signal soft_trigger_s    : std_logic;
	
	----------------------------------------------------------------------------------------------------------------------
	--------------------------------------------ETHERNET / IPv4 / UDP SIGNALS---------------------------------------------
	----------------------------------------------------------------------------------------------------------------------
	--ethernet constants	
	constant eth_TYPE_1    		 : std_logic_vector(7 downto 0) := x"08"; 
	constant eth_TYPE_2         : std_logic_vector(7 downto 0) := x"00";
	
	--ipv4 constants
--	constant s_version    		 : std_logic_vector(3 downto 0)  := "0100";
--	constant s_IHL        		 : std_logic_vector(3 downto 0)  := "0101";
--	constant s_DSCP       		 : std_logic_vector(5 downto 0)  := "000000";
--	constant s_ECN        		 : std_logic_vector(1 downto 0)  := "00";
--	constant s_flags            : std_logic_vector(2 downto 0)  := "010";
--	constant s_fragment_offset  : std_logic_vector(12 downto 0) := (others => '0');

	constant IHL_VERSION 		 : std_logic_vector(7 downto 0) := "01000101";
	constant ECN_DSCP	 		 	 : std_logic_vector(7 downto 0) := "00000000";
	signal   length_1    	    : std_logic_vector(7 downto 0);
	signal   length_2		    	 : std_logic_vector(7 downto 0);
	
	signal   identification_1   : std_logic_vector(7 downto 0);
	signal   identification_2   : std_logic_vector(7 downto 0); 
	constant flags_offset_1     : std_logic_vector(7 downto 0) := "01000000";
	constant offset_2				 : std_logic_vector(7 downto 0) := "00000000";

	constant s_TTL 			    : std_logic_vector(7 downto 0)  := x"03";
	constant s_protocol         : std_logic_vector(7 downto 0)  := x"11";
	signal   header_chksm_1     : std_logic_vector(7 downto 0);
	signal   header_chksm_2     : std_logic_vector(7 downto 0);
	
	--evtNumber(15 downto 0) is used in lieu of s_identification
	signal   s_identification   : std_logic_vector(15 downto 0);
	
	--eth / ipv4 signals
	signal s_total_length       : std_logic_vector(15 downto 0); --s_total_length := convert to binary(22+20+12+8*data_address_length)
	
	signal ipv4_header_checksum : std_logic_vector(15 downto 0);
	
	signal eth_SrcMac    	    : std_logic_vector(47 downto 0);  
	signal eth_DestMac          : std_logic_vector(47 downto 0);
	  
	signal ipv4_DestIP          : std_logic_vector(31 downto 0);
	signal ipv4_SrcIP           : std_logic_vector(31 downto 0);

	--	new udp_packet info
	signal udp_SrcPort			 : std_logic_vector(15 downto 0);
	signal udp_DestPort			 : std_logic_vector(15 downto 0);
	signal s_udp_length			 : std_logic_vector(15 downto 0);
	--udp checksum (all zero's)
	constant udp_checksum 		 : std_logic_vector(15 downto 0) := x"0000";
	
	----------------------------------------------------------------------------------------------------------------------
	--------------------------------------------END ETH / IPV4 SIGNALS ---------------------------------------------------
	----------------------------------------------------------------------------------------------------------------------

   attribute dont_touch : string;
   attribute dont_touch of evtDataFifoReady : signal is "true";
 
begin

	--assign the top level ports to inputs:
		data_read_ins   <= data_read_in;
		data_read_outs  <= r.evtAddrOut;
		data_phase_outs <= r.evtPhaseSel;
		soft_trigger_s  <= soft_trigger;
	
	--assign the signals to ports
		data_read_out   <= data_read_outs;
		data_phase_out  <= data_phase_outs;
		data_addr_hits  <= data_addr_hit;
	
	--input ports which determine the before and after address selection from the trigger event.
		num_addr_befs   <= data_addr_bef; 
		num_addr_afts   <= data_addr_aft;
		evtNumber       <= r.evtNumber;
	
	--ethernet MAC
		eth_SrcMac 		 <= prt_LAPPD_srcMac(63 downto 32) & prt_LAPPD_srcMac(15 downto 8) & prt_LAPPD_srcMac(7 downto 0); -- & prt_LAPPD_srcMac(39 downto 32) & prt_LAPPD_srcMac(15 downto 8) & prt_LAPPD_srcMac (7 downto 0);
		eth_DestMac     <= prt_NBIC_destMac(63 downto 32) & prt_NBIC_destMac(15 downto 8) & prt_NBIC_destMac(7 downto 0); --& prt_NBIC_destMac(39 downto 32) & prt_NBIC_destMac(15 downto 8) & prt_NBIC_destMac (7 downto 0);
	
	--ipv4 IP
		ipv4_DestIP     <= prt_NBIC_destIP(31 downto 0); --& prt_NBIC_destIP(15 downto 8) & prt_NBIC_destIP(23 downto 16) & prt_NBIC_destIP(31 downto 24);-- & prt_NBIC_destIP( downto 24) & prt_NBIC_destIP(7 downto 0) & prt_NBIC_destIP(15 downto 8);
		ipv4_SrcIP      <= prt_LAPPD_SrcIP(31 downto 0); --& prt_LAPPD_SrcIP(15 downto 8) & prt_LAPPD_SrcIP(23 downto 16) & prt_LAPPD_SrcIP(31 downto 24);--& prt_LAPPD_SrcIP(31 downto 24) & prt_LAPPD_SrcIP(7 downto 0) & prt_LAPPD_SrcIP(15 downto 8);
	
	--udp ports, src is first 16 bits as read, but is still flipped..
		udp_SrcPort		 <= prt_NBIC_ports(31 downto 24)   & prt_NBIC_ports(23 downto 16);
		udp_DestPort	 <= prt_NBIC_ports(15 downto 8)    & prt_NBIC_ports(7 downto 0 );

	--	assign the byte signals their updated values..
		s_identification   <= r.evtNumber(15 downto 0);
		length_1 			 <= s_total_length(7 downto 0);
		length_2 			 <= s_total_length(15 downto 8);
		identification_1   <= s_identification(7 downto 0);
		identification_2   <= s_identification(15 downto 8);
		header_chksm_1     <= ipv4_header_checksum(7 downto 0);
		header_chksm_2     <= ipv4_header_checksum(15 downto 8);

--------------------------------------------------------------------------------------------------------------------------------- 
---------------------------component to connect data_read_out to Eth core--------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

--parse through the data_phase_out chains 4 clock cycle minimum to read each of the values..
   comb : process( r, rst, new_trigger, data_read_ins, data_addr_hits, num_addr_befs, num_addr_afts, evtDataFifoReady, evtCount,
						 eth_DestMac, eth_SrcMac, ipv4_DestIP, ipv4_SrcIP, s_total_length, s_udp_length, soft_trigger_s
                   ) is
      variable v : Hit_Event;
   begin
      v := r;
      -- Resets for pulsed outputs
      v.evtDataValid := '0';
      v.evtDataLast  := '0';         
		-- State machine 
      case(r.state) is 
         when chillin =>			
				v 				   := HIT_INIT_C;
				v.evtNumber    := r.evtNumber;   --read these values every time to prevent them from being reset to zero or constant.
				v.num_addr_bef := num_addr_befs; 
				v.num_addr_aft := num_addr_afts;
				v.dataReady    := '1';			
				--reset values which control process of state machine here..			
					if(new_trigger = '1' or soft_trigger_s = '1')then --this is the output of the trigger condition! If triggered, go into header state
						v.state        := ETH_HEADER_S;
						v.evtAddrStop  := std_logic_vector((unsigned(data_addr_hits)+unsigned("0000"&r.num_addr_aft)));	--stopping address
						v.evtAddrOut   := std_logic_vector((unsigned(data_addr_hits)-unsigned("0000"&r.num_addr_bef)));
						v.phase_change := '0'; --make sure the state starts in the initial phase..	
					end if;

         when ETH_HEADER_S =>			
					v.evtDataValid   := '1';
					v.dataReady      := '0';					
			--begin ethernet sequence
				case r.header_count is
			--MacDest
					when "000" => 
						if(r.half_phase = '0') then
								v.evtData     := x"0000" & eth_DestMac(15 downto 8) & eth_DestMac(7 downto 0);
								v.evtDataKeep := "0011"; --keep half of the values
								v.half_phase  := '1';
						elsif
						   (r.half_phase = '1') then
								v.evtData      := eth_DestMac(47 downto 40) & eth_DestMac(39 downto 32) & eth_DestMac(31 downto 24) & eth_DestMac(23 downto 16);
								v.evtDataKeep  := x"F";
								v.half_phase   := '0';
								v.header_Count := "001";
						end if;
			--MacSouce
					when "001" =>
							v.evtData      := eth_SrcMac(31 downto 24) & eth_SrcMac(23 downto 16) & eth_SrcMac(15 downto 8) & eth_SrcMac(7 downto 0);
							v.evtDataKeep  := x"F";
							v.header_Count := "010";
			--EthType --note that eth type is somewhat shorter than the 32 bits..
					when "010" =>
							v.evtData      := eth_TYPE_2 & eth_TYPE_1 & eth_srcMac(47 downto 40) & eth_srcMac(39 downto 32); 		--only 16 bits here right now.... double cat only for practice purposes..
							v.evtDataKeep  := x"F";
							v.state        := IPV4_HEADER_S;
							v.half_phase   := '0';
							v.phase_change := '0';
							v.header_Count := "000";
					when others =>
							v.state := CHILLIN;
							v 		  := HIT_INIT_C;
				end case;
			
			when IPV4_HEADER_S =>			
					v.evtDataValid   := '1';
					v.dataReady      := '0';				
				case r.header_count is 
					when "000" =>
								v.evtData      := length_1 & length_2 & ECN_DSCP & IHL_VERSION;
								v.evtDataKeep  := x"F";
								v.header_count := "001";
					when "001" =>
								v.evtData      :=  offset_2 & flags_offset_1 & identification_2 & identification_1;
								v.evtDataKeep  := x"F";
								v.header_count := "010";
					when "010" =>
								v.evtData      := header_chksm_1 & header_chksm_2 & s_protocol & S_TTL;
								v.evtDataKeep  := x"F";
								v.header_count := "011";
					when "011" =>
								v.evtData      := ipv4_SrcIP;
								v.evtDataKeep  := x"F";
								v.header_count := "100"; 
					when "100" =>
								v.evtData      := ipv4_DestIP;
								v.evtDataKeep  := x"F";
								v.state        := UDP_HEADER_S;
								v.header_count := "000";
								v.half_phase   := '0';
								v.phase_change := '0';
					when others =>
								v.state := CHILLIN;
								v 		  := HIT_INIT_C;
				end case;
							
			when UDP_HEADER_S  =>
					v.evtDataValid   := '1';
					v.dataReady      := '0';
				case r.header_count is		
					when "000" =>
							v.evtData      := udp_DestPort & udp_SrcPort;
							v.evtDataKeep  := x"F";
							v.header_count := "001";
					when "001" =>
							v.evtData      := udp_Checksum & s_udp_length(7 downto 0) & s_udp_length(15 downto 8);
							v.evtDataKeep  := x"F";
							v.header_count := "000";
							v.state 			:= HEADER;
							v.half_phase	:= '0';
							v.phase_change := '0';
					when others =>
								v.state := CHILLIN;
								v 		  := HIT_INIT_C;
				end case;
				
			when HEADER =>			
				if(r.phase_change = '0') then				
					v.evtData        := x"DAA80085";
					v.evtDataKeep    := x"F";
					v.evtDataValid   := '1';
					v.dataReady      := '0';
					v.phase_change   := '1';
					v.evtNumber      := evtCount;						
					--check to see if the fifo is ready
				elsif(r.phase_change = '1' and evtDataFifoREady = '1') then
					v.evtData      := v.evtNumber;
					v.evtDataKeep  := x"F";
					v.evtDataValid := '1';
					v.dataReady    := '0';
					v.phase_change := '0';
					v.state 			:= phase_0;
				end if;
		
			when Phase_0 =>
			--select the address for the beginning phase only since all of the phases have the same address
				v.evtPhaseSel     := "00";
			   v.evtDataValid    := '1';
			--phase cycle	
				if (r.half_phase = '0') then
					v.evtAddrOut   := std_logic_vector((unsigned(r.evtAddrOut) + 1));  --proceed to the next addr
					v.evtData      := data_read_ins(63 downto 32);
					v.evtDataKeep  := x"F";
					v.half_phase   := '1';
				else
					v.evtData      := data_read_ins(31 downto 0);
					v.evtDataKeep  := x"F";
					v.half_phase   := '0';
					v.phase_change := '1';
				end if;

				if(r.phase_change = '1') then
					v.state 		   := Phase_1;
					v.phase_change := '0';
				else
					v.phase_Change := '1';
				end if;

         when Phase_1 =>			
				v.evtPhaseSel     := "01";
			   v.evtDataValid    := '1';
			--phase cycle
				if (r.half_phase = '0') then
					v.evtData      := data_read_ins(63 downto 32);
					v.evtDataKeep  := x"F";
					v.half_phase   := '1';
				else
					v.evtData := data_read_ins(31 downto 0);
					v.evtDataKeep  := x"F";
					v.half_phase   := '0';
					v.phase_change := '1';
				end if;
				
				if(r.phase_change = '1') then
					v.state	      := Phase_2;
					v.phase_change := '0';
				else
					v.phase_Change := '1';			
				end if;

         when Phase_2 =>			
				v.evtPhaseSel 	   := "10";
			   v.evtDataValid    := '1';
			--phase cycle
				if (r.half_phase = '0') then
					v.evtData      := data_read_ins(63 downto 32);
					v.evtDataKeep  := x"F";
					v.half_phase   := '1';
				else
					v.evtData      := data_read_ins(31 downto 0);
					v.evtDataKeep  := x"F";
					v.half_phase   := '0';
					v.phase_change := '1';
				end if;

				if(r.phase_change = '1') then
					v.state        := Phase_3;
					v.phase_change := '0';
				else
					v.phase_Change := '1';
				end if;

         when Phase_3 =>
				v.evtPhaseSel   := "11";
			   v.evtDataValid  := '1';				
			--phase cycle
				if (r.half_phase = '0') then
					v.evtData    := data_read_ins(63 downto 32);
					v.evtDataKeep  := x"F";
					v.half_phase := '1';
				else
					v.evtData    := data_read_ins(31 downto 0);
					v.evtDataKeep  := x"F";
					v.half_phase := '0';
				end if;
			  
				if(r.phase_change = '1') then
					if (r.evtAddrOut = r.evtAddrStop) then
						v.state 		     := FOOTER;	    				   												--have read from all of the assigned addresses.. go to footer!
					else
						v.state 			  := phase_0;   					                                       --go back and begin reading from the new address
						v.half_phase     := '0';
						v.phase_change   := '0';
					end if;
				else
					v.phase_change := '1';
				end if;

         when FOOTER =>	
				v.evtData        := x"EDEDEDED";
			   v.evtDataKeep    := x"F";
				v.evtDataValid   := '1';
            v.evtDataLast    := '1';
				v.phase_change   := '0';
				v.half_phase     := '0';
            v.state          := DONE;

         when DONE =>		
				v           	  := HIT_INIT_C;
				v.state     	  := chillin;
				v.DataReady 	  := '1';
	
         when others =>
            v.state := chillin;
				v    	  := HIT_INIT_C;
      end case;

      -- Reset logic
      if (rst = '1') then
         v := HIT_INIT_C;
      end if;

      -- Outputs to ports
      dataReady    <= r.dataReady;
		evtDataValid <= r.evtDataValid;
		evtData      <= r.evtData;
		evtDataLast  <= r.evtDataLast;
		evtDataKeep  <= r.evtDataKeep;
		
      -- Assignment of combinatorial variable to signal
      rin <= v;

   end process;

   seq : process (clk100) is
   begin
      if (rising_edge(clk100)) then
         r 	<= rin after GATE_DELAY_G;
      end if;
   end process seq;


	evtCountToSet : process(new_trigger, soft_trigger_s, clk100) is	
		variable hit_number : unsigned(31 downto 0) := (others => '0');	
	begin
		if (rising_edge(clk100)) then
			if (new_trigger = '1' or soft_trigger_s = '1') then
				hit_number := hit_number + 1;
				evtCount <= std_logic_vector(hit_number);
			end if;
		end if;
	end process evtCountToSet;

proc_ipChecksum : process (s_total_length, s_identification, ipv4_DestIp) is
      variable iWord1     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord2     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord3     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord4     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord5     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord6     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord7     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord8     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord9     : std_logic_vector(31 downto 0) := (others => '0');
      variable iChecksum1 : unsigned(31 downto 0) := (others => '0');
      variable iChecksum2 : unsigned(31 downto 0) := (others => '0');
      variable iChecksum3 : unsigned(31 downto 0) := (others => '0');
      variable iChecksum4 : unsigned(15 downto 0) := (others => '0');
   begin
      -- Prep words
      iWord1 := x"0000" & IHL_VERSION & ECN_DSCP;
      iWord2 := x"0000" & s_total_length;
      
		--identification?
      iWord7 := x"0000" & s_identification;
		iWord3 := x"0000" & flags_offset_1 & offset_2;
      
		iWord4 := x"0000" & s_TTL & s_protocol;
      
		iWord5 := x"0000" & ipv4_SrcIp(7 downto 0)   & ipv4_SrcIp(15 downto 8);
      iWord6 := x"0000" & ipv4_SrcIp(23 downto 16) & ipv4_SrcIp(31 downto 24);
          
		iWord8 := x"0000" & ipv4_destIp(7 downto 0)   & ipv4_destIp(15 downto 8);
      iWord9 := x"0000" & ipv4_destIp(23 downto 16) & ipv4_destIp(31 downto 24);
      -- Static part
      iChecksum1 := unsigned(iWord1) +     -- x4500 
                    unsigned(iWord2) +     -- x0318
                    -- + ipId(2 bytes)     --
                    unsigned(iWord3) +     -- x4000
                    unsigned(iWord4) +     -- x0311
                    -- + ipChecksum(this)
                    unsigned(iWord5) +     -- x???? [known at compile time]
                    unsigned(iWord6);      -- xC0A8
      -- Dynamic part
      iChecksum2 := iChecksum1 + 
                    unsigned(iWord7) +     -- x????
                    unsigned(iWord8) +     -- x???? [also known at compile time usually?]
                    unsigned(iWord9);      -- xC0A8
      -- Do the carry once
      iChecksum3 := (x"0000" & iChecksum2(15 downto 0)) + 
                    (x"0000" & iChecksum2(31 downto 16));
      -- Do the carry again
      iChecksum4 := iChecksum3(15 downto 0) + iChecksum3(31 downto 16);
      -- Perform one's complement
      ipv4_header_checksum <= not(std_logic_vector( iChecksum4 ));
end process;

	--calculate the value of the total length for the ipv4 address
	--length calculations:
		-- eth frame: 14 Bytes : 6 destMac, 6 SrcMac, 2 ethType
		--IPV4 frame: 20 Bytes : 4 per packet * 5 packets
		-- UDP Frame:  8 Bytes : 4 per packet * 2 packets
		--Data Frame: 12 Bytes : 4 per packet, (header, count, footer)
		--Data Phase: 32 Bytes : 4 per half_phase * 2 half_phases * 4 phases * n addresses
 proc_s_total_length : process (num_addr_afts, num_addr_befs) is

		variable counts_after    : unsigned(15 downto 0)  := (others => '0');
		variable counts_before   : unsigned(15 downto 0)  := (others => '0');
		variable bytes_in_frames : unsigned(15 downto 0)  := (others => '0');
		
	begin
		
		counts_after    := unsigned(x"000" & num_addr_afts);
		counts_before   := unsigned(x"000" & num_addr_befs);
		
		bytes_in_frames := counts_before + counts_after;
		bytes_in_frames := bytes_in_frames(10 downto 0) & "00000";
		bytes_in_frames := 40 + bytes_in_frames;
		
		s_total_length <= std_logic_vector(bytes_in_frames);
		s_udp_length   <= std_logic_vector(bytes_in_frames - 20);
	
	end process;		

end Behavioral;

