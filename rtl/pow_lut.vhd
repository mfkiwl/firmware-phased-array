---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      phased-array trigger board
-- FILE:         pow_lut.vhd
-- AUTHOR:       e.oberla
-- EMAIL         ejo@uchicago.edu
-- DATE:         3/2017
--
-- DESCRIPTION:  includes look-up-table for squaring data points for power calc.
--
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.defs.all;

package pow_lut is

constant lut_size  : integer := 2**define_beam_bits-1;
constant lut_range : integer := 2**define_beam_bits;

type power_lut_type is array(integer range<>) of integer range 0 to 2**(define_beam_bits*2);

--function init_lut_positive(size: integer) return power_lut_type;
--function init_lut_negative(size: integer) return power_lut_type;
--constant lut_power_pos :  power_lut_type(0 to lut_size-1) := init_lut_positive(lut_size);
--constant lut_power_neg :  power_lut_type(lut_size to 2*lut_size-1) := init_lut_negative(lut_size);

function init_lut(size : integer) return power_lut_type;
constant lut_power : power_lut_type(-128 to 127) := init_lut(256);

end pow_lut;

package body pow_lut is

function init_lut(size : integer) return power_lut_type is
	variable j : power_lut_type(-size/2 to size/2-1);
begin
	for i in j'range loop
		j(i) := i*i;
	end loop;
	return j;
end function;

--//////////////////
--//define LUT for positive samples
--//////////////////
--function init_lut_positive(size : integer) return power_lut_type is
--	variable j : power_lut_type(0 to size-1);
--begin
--	for i in j'range loop
--		j(i) := i*i;
--	end loop;
--	return j;
--end function;
--
----//////////////////
----//define LUT for negative samples
----//////////////////
--function init_lut_negative(size : integer) return power_lut_type is
--	variable j : power_lut_type(size to 2*size-1);
--begin
--	for i in j'range loop
--		j(i) := (i-lut_range)*(i-lut_range);
--	end loop;
--	return j;
--end function;

end package body;