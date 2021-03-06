---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      phased-array trigger board
-- FILE:         trigger.vhd
-- AUTHOR:       e.oberla
-- EMAIL         ejo@uchicago.edu
-- DATE:         6/2017...
--
-- DESCRIPTION:  trigger generation
--               this module takes in the power sums, adds additional smoothing/averaging
--					  compares to threshold
--
---------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.defs.all;
use work.register_map.all;
------------------------------------------------------------------------------------------------------------------------------
entity trigger is
	generic(
		ENABLE_PHASED_TRIGGER : std_logic := '1'); --//compile-time flag
	port(
		rst_i				:	in		std_logic;
		clk_data_i		:	in		std_logic; --//data clock ~93 MHz
		clk_iface_i		: 	in		std_logic; --//slow logic clock =7.5 MHz
			
		reg_i				: 	in		register_array_type;		
		powersums_i		:	in		sum_power_type;
		
		data_write_busy_i	:	in	std_logic; --//prevent triggers if triggered event is already being written to ram
		 
		last_trig_pow_o	:	out	average_power_16samp_type; 
		 
		trig_beam_o						:	out	std_logic_vector(define_num_beams-1 downto 0); --//for scalers
		trig_clk_data_o				:	inout	std_logic;  --//trig flag on faster clock
		last_trig_beam_clk_data_o 	: 	out 	std_logic_vector(define_num_beams-1 downto 0); --//register the beam trigger 
		trig_clk_iface_o				:	out	std_logic); --//trigger on clk_iface_i [trig_o is high for one clk_iface_i cycle (use for scalers)]
		
end trigger;
------------------------------------------------------------------------------------------------------------------------------
architecture rtl of trigger is
------------------------------------------------------------------------------------------------------------------------------
type buffered_powersum_type is array(define_num_beams-1 downto 0) of 
	std_logic_vector(2*define_num_power_sums*(define_pow_sum_range+1)-1 downto 0);

signal buffered_powersum : buffered_powersum_type;
signal instantaneous_avg_power_0 : average_power_16samp_type;  --//defined in defs.vhd
signal instantaneous_avg_power_1 : average_power_16samp_type;  --//defined in defs.vhd

signal instant_power_0_buf : average_power_16samp_type;
signal instant_power_1_buf : average_power_16samp_type;
signal instant_power_0_buf2 : average_power_16samp_type;
signal instant_power_1_buf2 : average_power_16samp_type;
signal instant_power_0_buf3 : average_power_16samp_type;
signal instant_power_1_buf3 : average_power_16samp_type;
signal instant_power_0_buf4 : average_power_16samp_type;
signal instant_power_1_buf4 : average_power_16samp_type;

signal instantaneous_above_threshold	:	std_logic_vector(define_num_beams-1 downto 0); --//check if beam above threshold at each clk_data_i edge
signal instantaneous_above_threshold_buf	:	std_logic_vector(define_num_beams-1 downto 0); 
signal instantaneous_above_threshold_buf2	:	std_logic_vector(define_num_beams-1 downto 0); 
signal internal_last_trig_latched_beam_pattern :  std_logic_vector(define_num_beams-1 downto 0);

signal thresholds_meta : average_power_16samp_type;
signal thresholds  : average_power_16samp_type;
signal internal_trig_en_reg : std_logic_vector(2 downto 0) := (others=>'0'); --//for clk transfer

--//here's the trigger state machine, which looks for power-above-threshold in each beam and checks for stuck-on beams
type trigger_state_machine_state_type is (idle_st, trig_high_st, trig_hold_st, trig_done_st);
type trigger_state_machine_state_array_type is array(define_num_beams-1 downto 0) of trigger_state_machine_state_type;
signal trigger_state_machine_state : trigger_state_machine_state_array_type;

type trig_hold_counter_type is array(define_num_beams-1 downto 0) of std_logic_vector(11 downto 0);
signal trigger_holdoff_counter		:	trig_hold_counter_type;
signal internal_trig_holdoff_count : std_logic_vector(11 downto 0);
signal internal_per_beam_trigger_holdoff : std_logic_vector(define_num_beams-1 downto 0); --//indicates if beam in trigger-holdoff mode
signal internal_global_trigger_holdoff : std_logic; --//OR of all the bits in the internal_per_beam_trigger_holdoff
signal internal_trig_holdoff_mode : std_logic := '1';

signal internal_data_manager_write_busy_reg : std_logic_vector(2 downto 0) := (others=>'0');

signal internal_trig_pow_latch_0 : std_logic_vector(define_num_beams-1 downto 0) := (others=>'0'); --//flag to record last beam power values
signal internal_trig_pow_latch_1 : std_logic_vector(define_num_beams-1 downto 0) := (others=>'0'); --//flag to record last beam power values
signal internal_trig_pow_latch_0_reg : std_logic_vector(1 downto 0) := (others=>'0');
signal internal_trig_pow_latch_1_reg : std_logic_vector(1 downto 0) := (others=>'0');

signal internal_trigger_beam_mask :  std_logic_vector(define_num_beams-1 downto 0);

signal internal_trig_clk_data : std_logic;
------------------------------------------------------------------------------------------------------------------------------
component flag_sync is
port(
	clkA			: in	std_logic;
   clkB			: in	std_logic;
   in_clkA		: in	std_logic;
   busy_clkA	: out	std_logic;
   out_clkB		: out	std_logic);
end component;
component signal_sync is
port(
	clkA			: in	std_logic;
   clkB			: in	std_logic;
   SignalIn_clkA	: in	std_logic;
   SignalOut_clkB	: out	std_logic);
end component;
-------------------------------------------------------------------------------------
begin
-------------------------------------------------------------------------------------
TrigMaskSync : for i in 0 to define_num_beams-1 generate
	xTRIGMASKSYNC : signal_sync
	port map(
		clkA				=> clk_iface_i,
		clkB				=> clk_data_i,
		SignalIn_clkA	=> reg_i(80)(i), --//reg 80 has the beam mask
		SignalOut_clkB	=> internal_trigger_beam_mask(i));
end generate;
-------------------------------------------------------------------------------------
TrigHoldoffSync : for i in 0 to 11 generate
	xTRIGHOLDOFFSYNC : signal_sync
	port map(
		clkA				=> clk_iface_i,
		clkB				=> clk_data_i,
		SignalIn_clkA	=> reg_i(81)(i), --//reg 81 has the programmable trig holdoff (lowest 12 bits)
		SignalOut_clkB	=> internal_trig_holdoff_count(i));
end generate;
-------------------------------------------------------------------------------------	
xTRIGHOLDOFFMODESYNC : signal_sync
port map(
	clkA				=> clk_iface_i,
	clkB				=> clk_data_i,
	SignalIn_clkA	=> reg_i(85)(0), 
	SignalOut_clkB	=> internal_trig_holdoff_mode);
-------------------------------------------------------------------------------------
--///////////////////////////////////////////////////////////////////////////////////
proc_clk_xfer : process(clk_data_i, reg_i, internal_trig_en_reg)
begin
	if rising_edge(clk_data_i) then
		for i in 0 to define_num_beams-1 loop
			thresholds(i) <= thresholds_meta(i);
			thresholds_meta(i)  <= reg_i(base_adrs_trig_thresh+i)(define_16avg_pow_sum_range-1 downto 0);
		end loop;
		internal_trig_en_reg <= internal_trig_en_reg(1 downto 0) & reg_i(82)(0); --//phased trig enable
	end if;
end process;
------------------------------------------------------------------------------------------------------------------------------
proc_get_trig_holdoff : process(rst_i, clk_data_i, internal_per_beam_trigger_holdoff, internal_trig_holdoff_mode)
begin
	if rst_i = '1' then
		internal_global_trigger_holdoff <= '0';
	elsif rising_edge(clk_data_i) and internal_trig_holdoff_mode = '0' then
		internal_global_trigger_holdoff <= '0';
	elsif rising_edge(clk_data_i) then
		internal_global_trigger_holdoff <=	internal_per_beam_trigger_holdoff(0) or internal_per_beam_trigger_holdoff(1) or
														internal_per_beam_trigger_holdoff(2) or internal_per_beam_trigger_holdoff(3) or
														internal_per_beam_trigger_holdoff(4) or internal_per_beam_trigger_holdoff(5) or
														internal_per_beam_trigger_holdoff(6) or internal_per_beam_trigger_holdoff(7) or
														internal_per_beam_trigger_holdoff(8) or internal_per_beam_trigger_holdoff(9) or
														internal_per_beam_trigger_holdoff(10) or internal_per_beam_trigger_holdoff(11) or
														internal_per_beam_trigger_holdoff(12) or internal_per_beam_trigger_holdoff(13) or
														internal_per_beam_trigger_holdoff(14);
	end if;
end process;
------------------------------------------------------------------------------------------------------------------------------
proc_get_last_beam_trigger_pattern : process(rst_i, clk_data_i, internal_last_trig_latched_beam_pattern, data_write_busy_i, 
															internal_data_manager_write_busy_reg, internal_trig_pow_latch_0_reg, internal_trig_pow_latch_1_reg)
begin	
	if rst_i = '1' then
		last_trig_beam_clk_data_o <= (others=>'0');
		for i in 0 to define_num_beams-1 loop
			last_trig_pow_o(i) <= (others=>'0');
		end loop;
		internal_trig_pow_latch_0_reg <= (others=>'0');
		internal_trig_pow_latch_1_reg <= (others=>'0');
		internal_data_manager_write_busy_reg <= (others=>'0');
	---------------------------------------------------------------------------------------------
	elsif rising_edge(clk_data_i) then
--		internal_data_manager_write_busy_reg <= internal_data_manager_write_busy_reg(1 downto 0) & data_write_busy_i;
--		
--		--this is only really going to be useful when trig_holdoff_mode = 1
--		--otherwise, at high trigger rates, multiple beams may have overlapping triggers
--		if internal_data_manager_write_busy_reg(2 downto 1) = "01" then
--			last_trig_beam_clk_data_o <= internal_last_trig_latched_beam_pattern; --//latch last triggered beam pattern
--		end if;
		
		------------------------------------------------------------------------------------
		--save last trig beam powers
		internal_trig_pow_latch_0_reg(1) <= internal_trig_pow_latch_0_reg(0);
		internal_trig_pow_latch_1_reg(1) <= internal_trig_pow_latch_1_reg(0);
		
		internal_trig_pow_latch_0_reg(0) <= internal_trig_pow_latch_0(0) or internal_trig_pow_latch_0(1) or internal_trig_pow_latch_0(2) or
													internal_trig_pow_latch_0(3) or internal_trig_pow_latch_0(4) or internal_trig_pow_latch_0(5) or
													internal_trig_pow_latch_0(6) or internal_trig_pow_latch_0(7) or internal_trig_pow_latch_0(8) or
													internal_trig_pow_latch_0(9) or internal_trig_pow_latch_0(10) or internal_trig_pow_latch_0(11) or
													internal_trig_pow_latch_0(12) or internal_trig_pow_latch_0(13) or internal_trig_pow_latch_0(14);
		internal_trig_pow_latch_1_reg(0) <= internal_trig_pow_latch_1(0) or internal_trig_pow_latch_1(1) or internal_trig_pow_latch_1(2) or
													internal_trig_pow_latch_1(3) or internal_trig_pow_latch_1(4) or internal_trig_pow_latch_1(5) or
													internal_trig_pow_latch_1(6) or internal_trig_pow_latch_1(7) or internal_trig_pow_latch_1(8) or
													internal_trig_pow_latch_1(9) or internal_trig_pow_latch_1(10) or internal_trig_pow_latch_1(11) or
													internal_trig_pow_latch_1(12) or internal_trig_pow_latch_1(13) or internal_trig_pow_latch_1(14);
													
		if internal_trig_pow_latch_0_reg = "01" then
			last_trig_pow_o <= instant_power_0_buf2;
			last_trig_beam_clk_data_o <= internal_last_trig_latched_beam_pattern; 
		elsif internal_trig_pow_latch_1_reg = "01" then
			last_trig_pow_o <= instant_power_1_buf2;
			last_trig_beam_clk_data_o <= internal_last_trig_latched_beam_pattern; 
		end if;
	
	end if;
end process;
------------------------------------------------------------------------------------------------------------------------------
proc_buf_powsum : process(rst_i, clk_data_i, data_write_busy_i, internal_trig_en_reg, internal_trig_holdoff_count, internal_global_trigger_holdoff,
									instantaneous_avg_power_0, instantaneous_avg_power_1)
begin
	for i in 0 to define_num_beams-1 loop
		if rst_i = '1' or ENABLE_PHASED_TRIGGER = '0' then
			instantaneous_avg_power_0(i) <= (others=>'0');
			instantaneous_avg_power_1(i) <= (others=>'0');
			instant_power_0_buf(i) <= (others=>'0');
			instant_power_1_buf(i) <= (others=>'0');
			instant_power_0_buf2(i) <= (others=>'0');
			instant_power_1_buf2(i) <= (others=>'0');
			instant_power_0_buf3(i) <= (others=>'0');
			instant_power_1_buf3(i) <= (others=>'0');		
			instant_power_0_buf4(i) <= (others=>'0');
			instant_power_1_buf4(i) <= (others=>'0');	
			
			internal_last_trig_latched_beam_pattern(i) <= '0';
			
			instantaneous_above_threshold(i) <= '0';
			instantaneous_above_threshold_buf(i) <= '0';
			instantaneous_above_threshold_buf2(i) <= '0';
			
			internal_trig_pow_latch_0(i) <= '0';  --//flag to record last beam power values
			internal_trig_pow_latch_1(i) <= '0';  --//flag to record last beam power values

			buffered_powersum(i) <= (others=>'0');
			
			trigger_state_machine_state(i) 	<= idle_st;
			trigger_holdoff_counter(i) 		<= (others=>'0');
			internal_per_beam_trigger_holdoff(i) <= '0';
		
		elsif rising_edge(clk_data_i) and internal_trig_en_reg(2) = '0' then
			instantaneous_avg_power_0(i) <= (others=>'0');
			instantaneous_avg_power_1(i) <= (others=>'0');
			instant_power_0_buf(i) <= (others=>'0');
			instant_power_1_buf(i) <= (others=>'0');
			instant_power_0_buf2(i) <= (others=>'0');
			instant_power_1_buf2(i) <= (others=>'0');
			instant_power_0_buf3(i) <= (others=>'0');
			instant_power_1_buf3(i) <= (others=>'0');	
			instant_power_0_buf4(i) <= (others=>'0');
			instant_power_1_buf4(i) <= (others=>'0');				
			
			internal_last_trig_latched_beam_pattern(i) <= '0';
			
			instantaneous_above_threshold(i) <= '0';
			instantaneous_above_threshold_buf(i) <= '0';
			instantaneous_above_threshold_buf2(i) <= '0';
			
			internal_trig_pow_latch_0(i) <= '0';
			internal_trig_pow_latch_1(i) <= '0';
			
			buffered_powersum(i) <= (others=>'0');
			
			trigger_state_machine_state(i) 	<= idle_st;
			trigger_holdoff_counter(i) 		<= (others=>'0');
		
		--//there are 16 samples every clock cycle. We want to calculate the power in 16 sample units every 8 samples.
		--//So that's two power calculations every clk_data_i cycle
		elsif rising_edge(clk_data_i) then
			instant_power_0_buf4(i) <= instant_power_0_buf3(i);
			instant_power_1_buf4(i) <= instant_power_1_buf3(i);
			instant_power_0_buf3(i) <= instant_power_0_buf2(i);
			instant_power_1_buf3(i) <= instant_power_1_buf2(i);
			instant_power_0_buf2(i) <= instant_power_0_buf(i);
			instant_power_1_buf2(i) <= instant_power_1_buf(i);
			instant_power_0_buf(i) <= instantaneous_avg_power_0(i);
			instant_power_1_buf(i) <= instantaneous_avg_power_1(i);
			--//calculate first 16-sample power
			--//note that buffered_powersum already contains 2 samples, so we need to sum over 8 of these
			instantaneous_avg_power_0(i) <= 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(1*(define_pow_sum_range+1)-1 downto 0)), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(2*(define_pow_sum_range+1)-1 downto 1*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(3*(define_pow_sum_range+1)-1 downto 2*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(4*(define_pow_sum_range+1)-1 downto 3*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(5*(define_pow_sum_range+1)-1 downto 4*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(6*(define_pow_sum_range+1)-1 downto 5*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(7*(define_pow_sum_range+1)-1 downto 6*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(8*(define_pow_sum_range+1)-1 downto 7*(define_pow_sum_range+1))), define_16avg_pow_sum_range));
			
			--//calculate second 16-sample power, overlapping with first sample
			instantaneous_avg_power_1(i) <=
					std_logic_vector(resize(unsigned(buffered_powersum(i)(5*(define_pow_sum_range+1)-1 downto 4*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(6*(define_pow_sum_range+1)-1 downto 5*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(7*(define_pow_sum_range+1)-1 downto 6*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(8*(define_pow_sum_range+1)-1 downto 7*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(9*(define_pow_sum_range+1)-1 downto 8*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(10*(define_pow_sum_range+1)-1 downto 9*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(11*(define_pow_sum_range+1)-1 downto 10*(define_pow_sum_range+1))), define_16avg_pow_sum_range)) + 
					std_logic_vector(resize(unsigned(buffered_powersum(i)(12*(define_pow_sum_range+1)-1 downto 11*(define_pow_sum_range+1))), define_16avg_pow_sum_range));	
			
			buffered_powersum(i) <= buffered_powersum(i)(define_num_power_sums*(define_pow_sum_range+1)-1 downto 0) & powersums_i(i);	
			
			instantaneous_above_threshold_buf2(i) 	<= instantaneous_above_threshold_buf(i);
			instantaneous_above_threshold_buf(i)	<= instantaneous_above_threshold(i);
			--/////////////////////////////////////////////////
			--// THE TRIGGER
			case trigger_state_machine_state(i) is
			
				--//waiting for trigger
				when idle_st => 
					internal_trig_pow_latch_0(i) <= '0';
					internal_trig_pow_latch_1(i) <= '0';
					trigger_holdoff_counter(i) <= (others=>'0');
					internal_per_beam_trigger_holdoff(i) <= '0';
					internal_last_trig_latched_beam_pattern(i) <= '0';

					if data_write_busy_i = '1' or internal_global_trigger_holdoff = '1' then
						instantaneous_above_threshold(i) <= '0';
						trigger_state_machine_state(i) <= idle_st;
					
					elsif instantaneous_avg_power_0(i) > thresholds(i) then
						instantaneous_above_threshold(i) <= '1'; --// high for two clk_data_i cycles
						-----------FLAG power in sum 0 ------------------------
						internal_trig_pow_latch_0(i) <= '1';
						--------------------------------------------------------
						trigger_state_machine_state(i) <= trig_high_st;
						
					elsif instantaneous_avg_power_1(i) > thresholds(i) then
						instantaneous_above_threshold(i) <= '1'; --// high for two clk_data_i cycles
						-----------FLAG power in sum 1 ------------------------
						internal_trig_pow_latch_1(i) <= '1';
						--------------------------------------------------------
						trigger_state_machine_state(i) <= trig_high_st;
						
					else
						instantaneous_above_threshold(i) <= '0';
						trigger_state_machine_state(i) <= idle_st;
					end if;
					
				when trig_high_st =>
					internal_per_beam_trigger_holdoff(i) <= '1';
					internal_last_trig_latched_beam_pattern(i) <= '1'; --//active for holdoff cycle
					instantaneous_above_threshold(i) <= '1';
					trigger_state_machine_state(i) <= trig_hold_st;
					
				--//trig hold off
				when trig_hold_st =>
					internal_trig_pow_latch_0(i) <= '0';
					internal_trig_pow_latch_1(i) <= '0';
					internal_per_beam_trigger_holdoff(i) <= '1';
					instantaneous_above_threshold(i) <= '0';
					
					--//need to limit trigger burst rate in order to register on interface clock
					if trigger_holdoff_counter(i) = internal_trig_holdoff_count then
						trigger_holdoff_counter(i) <= (others=>'0');
						trigger_state_machine_state(i) <= trig_done_st;
						
					elsif trigger_holdoff_counter(i) = x"FFF" then
						trigger_holdoff_counter(i) <= (others=>'0');
						trigger_state_machine_state(i) <= trig_done_st;
						
					else
						trigger_holdoff_counter(i) <= trigger_holdoff_counter(i) + 1;
						trigger_state_machine_state(i) <= trig_hold_st;
					end if;
					
				--//trig done, go back to idle_st
				when trig_done_st =>
					internal_trig_pow_latch_0(i) <= '0';
					internal_trig_pow_latch_1(i) <= '0';
					internal_per_beam_trigger_holdoff(i) <= '0';
					instantaneous_above_threshold(i) <= '0';
					trigger_holdoff_counter(i) <= (others=>'0');
					trigger_state_machine_state(i) <= idle_st;
			
			end case;

		end if;
	end loop;
end process;
------------------------------------------------------------------------------------------------------------------------------
process(clk_data_i, rst_i)
begin
	if rst_i = '1'  or ENABLE_PHASED_TRIGGER = '0' then
		internal_trig_clk_data <= '0';
		trig_clk_data_o <= '0';
	elsif rising_edge(clk_data_i) then
		internal_trig_clk_data <=  trig_clk_data_o;
		trig_clk_data_o	<=	(instantaneous_above_threshold_buf(0) and internal_trigger_beam_mask(0)) or
									(instantaneous_above_threshold_buf(1) and internal_trigger_beam_mask(1)) or
									(instantaneous_above_threshold_buf(2) and internal_trigger_beam_mask(2)) or
									(instantaneous_above_threshold_buf(3) and internal_trigger_beam_mask(3)) or
									(instantaneous_above_threshold_buf(4) and internal_trigger_beam_mask(4)) or
									(instantaneous_above_threshold_buf(5) and internal_trigger_beam_mask(5)) or
									(instantaneous_above_threshold_buf(6) and internal_trigger_beam_mask(6)) or
									(instantaneous_above_threshold_buf(7) and internal_trigger_beam_mask(7)) or
									(instantaneous_above_threshold_buf(8) and internal_trigger_beam_mask(8)) or
									(instantaneous_above_threshold_buf(9) and internal_trigger_beam_mask(9)) or
									(instantaneous_above_threshold_buf(10) and internal_trigger_beam_mask(10)) or
									(instantaneous_above_threshold_buf(11) and internal_trigger_beam_mask(11)) or
									(instantaneous_above_threshold_buf(12) and internal_trigger_beam_mask(12)) or
									(instantaneous_above_threshold_buf(13) and internal_trigger_beam_mask(13)) or
									(instantaneous_above_threshold_buf(14) and internal_trigger_beam_mask(14));
	end if;
end process;
------------------------------------------------------------------------------------------------------------------------------
--/////////////////////////////////////////////////////
--/////////////////////////////////////////////////////
--//now, sync beam triggers to slower clock
--//note, these do not get masked, in order to keep counting in scalers
TrigSync	:	 for i in 0 to define_num_beams-1 generate
	xBEAMTRIGSYNC : flag_sync
	port map(
		clkA 			=> clk_data_i,
		clkB			=> clk_iface_i,
		in_clkA		=> instantaneous_above_threshold_buf2(i),
		busy_clkA	=> open,
		out_clkB		=> trig_beam_o(i));
end generate TrigSync;
------------------------------------------------------------------------------------------------------------------------------
xTRIGSYNC : flag_sync
	port map(
		clkA 			=> clk_data_i,
		clkB			=> clk_iface_i,
		in_clkA		=> internal_trig_clk_data,
		busy_clkA	=> open,
		out_clkB		=> trig_clk_iface_o); --//trig_o is high for one clk_iface_i cycle (use for scalers and to send off-board)

--//////////////////////
end rtl;