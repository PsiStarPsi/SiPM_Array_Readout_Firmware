--
--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 
--
--   To use any of the example code shown below, uncomment the lines and modify as necessary
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package PLL_integer_array is

 type PLL_integer_array is array (63 downto 0) of integer;

	--bank15 corresponds to int 0 (banks 1/5 share a pll)
	--bank2  corresponds to int 1
	--bank34 corresponds to int 2 (banks3/4 share a pll

constant pll_array_ints : PLL_integer_array := (
																0 => 2,
																1 => 2,
																2 => 1,
																3 => 1,
																4 => 1,
																5 => 1,
																6 => 1,
																7 => 2,
																
																8  => 2,
																9  => 2,
																10 => 1,
																11 => 1,
																12 => 2,
																13 => 2,
																14 => 2,
																15 => 2,
																
																16 => 0,
																17 => 0,
																18 => 2,
																19 => 2,
																20 => 0,
																21 => 0,
																22 => 0,
																23 => 0,
																
																24 => 0,
																25 => 0,
																26 => 0,
																27 => 0,
																28 => 0,
																29 => 0,
																30 => 0,
																31 => 0,
																
																32 => 2,
																33 => 2,
																34 => 1,
																35 => 1,
																36 => 1,
																37 => 1,
																38 => 2,
																39 => 2,
																
																40 => 2,
																41 => 2,
																42 => 1,
																43 => 1,
																44 => 2,
																45 => 2,
																46 => 2,
																47 => 2,
																
																48 => 0,
																49 => 0,
																50 => 2,
																51 => 2,
																52 => 0,
																53 => 0,
																54 => 0,
																55 => 0,
																
																56 => 0,
																57 => 0,
																58 => 0,
																59 => 0,
																60 => 0,
																61 => 0,
																62 => 0,
																63 => 0
															);
 
 
 
-- Declare constants
--
-- constant <constant_name>		: time := <time_unit> ns;
-- constant <constant_name>		: integer := <value;
--
-- Declare functions and procedure
--
-- function <function_name>  (signal <signal_name> : in <type_declaration>) return <type_declaration>;
-- procedure <procedure_name> (<type_declaration> <constant_name>	: in <type_declaration>);
--

end PLL_integer_array;

package body PLL_integer_array is

---- Example 1
--  function <function_name>  (signal <signal_name> : in <type_declaration>  ) return <type_declaration> is
--    variable <variable_name>     : <type_declaration>;
--  begin
--    <variable_name> := <signal_name> xor <signal_name>;
--    return <variable_name>; 
--  end <function_name>;

---- Example 2
--  function <function_name>  (signal <signal_name> : in <type_declaration>;
--                         signal <signal_name>   : in <type_declaration>  ) return <type_declaration> is
--  begin
--    if (<signal_name> = '1') then
--      return <signal_name>;
--    else
--      return 'Z';
--    end if;
--  end <function_name>;

---- Procedure Example
--  procedure <procedure_name>  (<type_declaration> <constant_name>  : in <type_declaration>) is
--    
--  begin
--    
--  end <procedure_name>;
 
end PLL_integer_array;
