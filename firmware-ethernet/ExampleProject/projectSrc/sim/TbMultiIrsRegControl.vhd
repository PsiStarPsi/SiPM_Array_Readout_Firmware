--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   03:24:10 12/21/2018
-- Design Name:   
-- Module Name:   /home/ise/ise-shared/SiPM_Array_Readout_Firmware/firmware-ethernet/ExampleProject/projectSrc/sim/TbMultiIrsRegControl.vhd
-- Project Name:  exampleProject
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: MultiIrsRegControl
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
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY TbMultiIrsRegControl IS
END TbMultiIrsRegControl;
 
ARCHITECTURE behavior OF TbMultiIrsRegControl IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT MultiIrsRegControl
    PORT(
         clk : IN  std_logic;
         AsicIn_PCLK : OUT  std_logic_vector(15 downto 0);
         AsicIn_SCLK : OUT  std_logic;
         AsicIn_SIN : OUT  std_logic;
         irsNumber : IN  std_logic_vector(3 downto 0);
         irsAddr : IN  std_logic_vector(7 downto 0);
         irsWrData : IN  std_logic_vector(11 downto 0);
         irsRdData : OUT  std_logic_vector(31 downto 0);
         irsReq : IN  std_logic;
         irsOp : IN  std_logic;
         irsAck : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal irsNumber : std_logic_vector(3 downto 0) := x"3";
   signal irsAddr : std_logic_vector(7 downto 0) := x"15";
   signal irsWrData : std_logic_vector(11 downto 0) := x"ABC";
   signal irsReq : std_logic := '0';
   signal irsOp : std_logic := '1';

 	--Outputs
   signal AsicIn_PCLK : std_logic_vector(15 downto 0);
   signal AsicIn_SCLK : std_logic;
   signal AsicIn_SIN : std_logic;
   signal irsRdData : std_logic_vector(31 downto 0);
   signal irsAck : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
   constant AsicIn_PCLK_period : time := 10 ns;
   constant AsicIn_SCLK_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: MultiIrsRegControl PORT MAP (
          clk => clk,
          AsicIn_PCLK => AsicIn_PCLK,
          AsicIn_SCLK => AsicIn_SCLK,
          AsicIn_SIN => AsicIn_SIN,
          irsNumber => irsNumber,
          irsAddr => irsAddr,
          irsWrData => irsWrData,
          irsRdData => irsRdData,
          irsReq => irsReq,
          irsOp => irsOp,
          irsAck => irsAck
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process; 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 
      irsReq <= '1';

      wait;
   end process;

END;
