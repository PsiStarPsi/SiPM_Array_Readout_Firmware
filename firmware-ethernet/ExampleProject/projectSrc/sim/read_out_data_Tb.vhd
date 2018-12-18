--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   19:19:38 11/09/2018
-- Design Name:   
-- Module Name:   /home/ise/Documents/Projects/11_9_working_version_sim/trash_1/firmware-ethernet/ExampleProject/projectSrc/sim/read_out_data_Tb.vhd
-- Project Name:  exampleProject
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: read_out_data
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

--use UNISIM.VComponents.all;


 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
USE ieee.numeric_std.ALL;
 
ENTITY read_out_data_Tb IS
END read_out_data_Tb;
 
ARCHITECTURE behavior OF read_out_data_Tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT read_out_data
    PORT(
         clk100 : IN  std_logic;
         rst : IN  std_logic;
         new_trigger : IN  std_logic;
         data_read_in : IN  std_logic_vector(63 downto 0);
         data_addr_hit : IN  std_logic_vector(7 downto 0);
         data_addr_bef : IN  std_logic_vector(3 downto 0);
         data_addr_aft : IN  std_logic_vector(3 downto 0);
         data_phase_out : OUT  std_logic_vector(1 downto 0);
         data_read_out : OUT  std_logic_vector(7 downto 0);
         evtDataValid : OUT  std_logic;
         evtData : OUT  std_logic_vector(31 downto 0);
         evtDataLast : OUT  std_logic;
         evtDataFifoReady : IN  std_logic;
         evtDataKeep : OUT  std_logic_vector(3 downto 0);
         evtNumber : OUT  std_logic_vector(31 downto 0);
         prt_LAPPD_srcMac : IN  std_logic_vector(63 downto 0);
         prt_LAPPD_srcIP : IN  std_logic_vector(31 downto 0);
         prt_NBIC_destMac : IN  std_logic_vector(63 downto 0);
         prt_NBIC_destIP : IN  std_logic_vector(31 downto 0);
         prt_NBIC_ports : IN  std_logic_vector(31 downto 0);
         soft_trigger : IN  std_logic;
         dataReady : OUT  std_logic
        );
    END COMPONENT;

COMPONENT AXIS_fifo_1
  PORT (
    ACLK : IN STD_LOGIC;
    ARESETN : IN STD_LOGIC;
    S00_AXIS_ACLK : IN STD_LOGIC;
    S01_AXIS_ACLK : IN STD_LOGIC;
    S00_AXIS_ARESETN : IN STD_LOGIC;
    S01_AXIS_ARESETN : IN STD_LOGIC;
    S00_AXIS_TVALID : IN STD_LOGIC;
    S01_AXIS_TVALID : IN STD_LOGIC;
    S00_AXIS_TREADY : OUT STD_LOGIC;
    S01_AXIS_TREADY : OUT STD_LOGIC;
    S00_AXIS_TDATA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    S01_AXIS_TDATA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    S00_AXIS_TKEEP : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    S01_AXIS_TKEEP : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    S00_AXIS_TLAST : IN STD_LOGIC;
    S01_AXIS_TLAST : IN STD_LOGIC;
    M00_AXIS_ACLK : IN STD_LOGIC;
    M00_AXIS_ARESETN : IN STD_LOGIC;
    M00_AXIS_TVALID : OUT STD_LOGIC;
    M00_AXIS_TREADY : IN STD_LOGIC;
    M00_AXIS_TDATA : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    M00_AXIS_TKEEP : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    M00_AXIS_TLAST : OUT STD_LOGIC;
    S00_ARB_REQ_SUPPRESS : IN STD_LOGIC;
    S01_ARB_REQ_SUPPRESS : IN STD_LOGIC;
    S00_FIFO_DATA_COUNT : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    S01_FIFO_DATA_COUNT : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    M00_FIFO_DATA_COUNT : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

   --Inputs
   signal clk100 : std_logic := '0';
	signal clk125 : std_logic := '0';
   signal rst : std_logic := '0';
   signal new_trigger : std_logic := '0';
   signal data_read_in : std_logic_vector(63 downto 0) := (others => '0');
   signal data_addr_hit : std_logic_vector(7 downto 0) := (others => '0');
   signal data_addr_bef : std_logic_vector(3 downto 0) := (others => '0');
   signal data_addr_aft : std_logic_vector(3 downto 0) := (others => '0');
   signal evtDataFifoReady : std_logic;
   signal prt_LAPPD_srcMac : std_logic_vector(63 downto 0) := (others => '0');
   signal prt_LAPPD_srcIP : std_logic_vector(31 downto 0) := (others => '0');
   signal prt_NBIC_destMac : std_logic_vector(63 downto 0) := (others => '0');
   signal prt_NBIC_destIP : std_logic_vector(31 downto 0) := (others => '0');
   signal prt_NBIC_ports : std_logic_vector(31 downto 0) := (others => '0');
   signal soft_trigger : std_logic := '0';

 	--Outputs
   signal data_phase_out : std_logic_vector(1 downto 0);
   signal data_read_out : std_logic_vector(7 downto 0);
   signal evtDataValid : std_logic;
   signal evtData : std_logic_vector(31 downto 0);
   signal evtDataLast : std_logic;
   signal evtDataKeep : std_logic_vector(3 downto 0);
   signal evtNumber : std_logic_vector(31 downto 0);
   signal dataReady : std_logic;
	
	signal M00_AXIS_TKEEP : std_logic_vector(0 downto 0);

	signal userTxDataValids   : std_logic;
	signal userTxDataReadys   : std_logic;
	signal userTxDataChannels : std_logic_vector(7 downto 0);
	signal userTxDataLasts    : std_logic;

   -- Clock period definitions
   constant clk100_period : time := 13.333 ns;
	constant clk125_period : time := 8 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: read_out_data PORT MAP (
          clk100 => clk100,
          rst => rst,
          new_trigger => new_trigger,
          data_read_in => data_read_in,
          data_addr_hit => data_addr_hit,
          data_addr_bef => data_addr_bef,
          data_addr_aft => data_addr_aft,
          data_phase_out => data_phase_out,
          data_read_out => data_read_out,
          evtDataValid => evtDataValid,
          evtData => evtData,
          evtDataLast => evtDataLast,
          evtDataFifoReady => evtDataFifoReady,
          evtDataKeep => evtDataKeep,
          evtNumber => evtNumber,
          prt_LAPPD_srcMac => prt_LAPPD_srcMac,
          prt_LAPPD_srcIP => prt_LAPPD_srcIP,
          prt_NBIC_destMac => prt_NBIC_destMac,
          prt_NBIC_destIP => prt_NBIC_destIP,
          prt_NBIC_ports => prt_NBIC_ports,
          soft_trigger => soft_trigger,
          dataReady => dataReady
        );

AXIS_fifo_output : AXIS_fifo_1
  PORT MAP (
    ACLK             => clk125,
    ARESETN          => '1',

	--input from microblaze, make sure the microblaze ports run on its clock!
    S00_AXIS_ACLK    => clk100,
    S00_AXIS_ARESETN => '1',
    S00_AXIS_TVALID  => '0',
    S00_AXIS_TREADY  => open,
    S00_AXIS_TDATA   => (others => '0'),
    S00_AXIS_TLAST   => '0',
	 S00_AXIS_TKEEP   => x"F", 										--keep everything the microblaze sends
		--input from data processessing
    S01_AXIS_ACLK    => clk100,
    S01_AXIS_ARESETN => '1',
	 S01_AXIS_TVALID  => evtDataValid,
    S01_AXIS_TREADY  => evtDataFifoReady,
    S01_AXIS_TDATA   => evtData,
    S01_AXIS_TLAST   => evtDataLast,	
	 S01_AXIS_TKEEP   => evtDataKeep,	
		--output to user
    M00_AXIS_ACLK    => clk125,
    M00_AXIS_ARESETN => '1',
    M00_AXIS_TVALID  => userTxDataValids,
    M00_AXIS_TREADY  => userTxDataReadys,
    M00_AXIS_TDATA   => userTxDataChannels,
    M00_AXIS_TLAST   => userTxDataLasts,
	 M00_AXIS_TKEEP   => M00_AXIS_TKEEP, 												--Keep Everything this FIFO Sends

    S00_ARB_REQ_SUPPRESS => '0',
    S01_ARB_REQ_SUPPRESS => '0',
	 
    S00_FIFO_DATA_COUNT => open,
	 S01_FIFO_DATA_COUNT => open,
	 M00_FIFO_DATA_COUNT => open
  );

   -- Clock process definitions
   clk100_process :process
   begin
		clk100 <= '0';
		wait for clk100_period/2;
		clk100 <= '1';
		wait for clk100_period/2;
   end process;
 
   clk125_process :process
   begin
		clk125 <= '0';
		wait for clk125_period/2;
		clk125 <= '1';
		wait for clk125_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		

--	signal userTxDataValids   : std_logic;
--	signal userTxDataReadys   : std_logic;
--	signal userTxDataChannels : std_logic_vector(7 downto 0);
--	signal userTxDataLasts    : std_logic;
		
		--userTxDataValids  <= '1';
		userTxDataReadys  <= '1';
		data_addr_hit     <= "00000100";
		data_addr_aft     <= "0011";
		data_addr_bef     <= "0011";
		M00_AXIS_TKEEP(0) <= '1';
		
		--assign fake port / mac addresses 
		prt_LAPPD_srcMac <= x"11" & x"22" & x"33" & x"44" & x"55" & x"66" & x"77" & x"88";
      prt_LAPPD_srcIP  <= x"12345678";
      prt_NBIC_destMac <= x"0123456789abcdef";
      prt_NBIC_destIP  <= x"87654321";
      prt_NBIC_ports   <= x"aabbccdd";	
		--make sure the fifo is always ready
		--evtDataFifoReady <= '1';
		
		wait for 20 ns;	

      wait for clk100_period*2;
		
		new_trigger  <= '1';
		soft_trigger <= '1';
		
		wait for clk100_period*1;

		soft_trigger <= '0';

      wait;
   end process;

END;
