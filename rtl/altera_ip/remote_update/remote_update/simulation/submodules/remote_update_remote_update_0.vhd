-- remote_update_remote_update_0.vhd

-- This file was auto-generated from altera_remote_update_hw.tcl.  If you edit it your changes
-- will probably be lost.
-- 
-- Generated using ACDS version 15.1 185

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity remote_update_remote_update_0 is
	port (
		busy            : out std_logic;                                        --            busy.busy
		data_out        : out std_logic_vector(31 downto 0);                    --        data_out.data_out
		param           : in  std_logic_vector(2 downto 0)  := (others => '0'); --           param.param
		read_param      : in  std_logic                     := '0';             --      read_param.read_param
		reconfig        : in  std_logic                     := '0';             --        reconfig.reconfig
		reset_timer     : in  std_logic                     := '0';             --     reset_timer.reset_timer
		write_param     : in  std_logic                     := '0';             --     write_param.write_param
		data_in         : in  std_logic_vector(31 downto 0) := (others => '0'); --         data_in.data_in
		clock           : in  std_logic                     := '0';             --           clock.clk
		reset           : in  std_logic                     := '0';             --           reset.reset
		asmi_busy       : in  std_logic                     := '0';             --       asmi_busy.asmi_busy
		asmi_data_valid : in  std_logic                     := '0';             -- asmi_data_valid.asmi_data_valid
		asmi_dataout    : in  std_logic_vector(7 downto 0)  := (others => '0'); --    asmi_dataout.asmi_dataout
		asmi_addr       : out std_logic_vector(31 downto 0);                    --       asmi_addr.asmi_addr
		asmi_read       : out std_logic;                                        --       asmi_read.asmi_read
		asmi_rden       : out std_logic;                                        --       asmi_rden.asmi_rden
		pof_error       : out std_logic                                         --       pof_error.pof_error
	);
end entity remote_update_remote_update_0;

architecture rtl of remote_update_remote_update_0 is
	component altera_remote_update_core is
		port (
			read_param      : in  std_logic                     := 'X';             -- read_param
			param           : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- param
			reconfig        : in  std_logic                     := 'X';             -- reconfig
			reset_timer     : in  std_logic                     := 'X';             -- reset_timer
			clock           : in  std_logic                     := 'X';             -- clk
			reset           : in  std_logic                     := 'X';             -- reset
			busy            : out std_logic;                                        -- busy
			data_out        : out std_logic_vector(31 downto 0);                    -- data_out
			write_param     : in  std_logic                     := 'X';             -- write_param
			data_in         : in  std_logic_vector(31 downto 0) := (others => 'X'); -- data_in
			asmi_busy       : in  std_logic                     := 'X';             -- asmi_busy
			asmi_data_valid : in  std_logic                     := 'X';             -- asmi_data_valid
			asmi_dataout    : in  std_logic_vector(7 downto 0)  := (others => 'X'); -- asmi_dataout
			pof_error       : out std_logic;                                        -- pof_error
			asmi_addr       : out std_logic_vector(31 downto 0);                    -- asmi_addr
			asmi_read       : out std_logic;                                        -- asmi_read
			asmi_rden       : out std_logic;                                        -- asmi_rden
			ctl_nupdt       : in  std_logic                     := 'X'              -- ctl_nupdt
		);
	end component altera_remote_update_core;

begin

	remote_update_core : component altera_remote_update_core
		port map (
			read_param      => read_param,      --      read_param.read_param
			param           => param,           --           param.param
			reconfig        => reconfig,        --        reconfig.reconfig
			reset_timer     => reset_timer,     --     reset_timer.reset_timer
			clock           => clock,           --           clock.clk
			reset           => reset,           --           reset.reset
			busy            => busy,            --            busy.busy
			data_out        => data_out,        --        data_out.data_out
			write_param     => write_param,     --     write_param.write_param
			data_in         => data_in,         --         data_in.data_in
			asmi_busy       => asmi_busy,       --       asmi_busy.asmi_busy
			asmi_data_valid => asmi_data_valid, -- asmi_data_valid.asmi_data_valid
			asmi_dataout    => asmi_dataout,    --    asmi_dataout.asmi_dataout
			pof_error       => pof_error,       --       pof_error.pof_error
			asmi_addr       => asmi_addr,       --       asmi_addr.asmi_addr
			asmi_read       => asmi_read,       --       asmi_read.asmi_read
			asmi_rden       => asmi_rden,       --       asmi_rden.asmi_rden
			ctl_nupdt       => '0'              --     (terminated)
		);

end architecture rtl; -- of remote_update_remote_update_0
