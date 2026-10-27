# Reproducible graphical Block Design, no application CPU or AXI subsystem.
set base [file normalize [file join [file dirname [info script]] ..]]
set stage [expr {[llength $argv]?[lindex $argv 0]:"prepare"}]
proc create_design {} {
 global base
 create_project wiring_bd [file join $base build project] -part xcvu9p-flga2104-2L-e
 set_property target_language Verilog [current_project]
 add_files [glob [file join $base rtl *]]
 update_compile_order -fileset sources_1
 create_bd_design wiring
 create_bd_cell -type ip -vlnv xilinx.com:ip:ddr3:1.4 mig
 set_property -dict [list CONFIG.C0.DDR3_isCustom true CONFIG.C0.DDR3_CustomParts [file join $base config vrp107_800.csv]] [get_bd_cells mig]
 set_property -dict [list CONFIG.C0.DDR3_MemoryPart VRP107_800_DIE CONFIG.C0.DDR3_MemoryVoltage {1.5V} CONFIG.C0.DDR3_OnDieTermination {RZQ/6} CONFIG.C0.DDR3_OutputDriverImpedenceControl {RZQ/7} CONFIG.C0.DDR3_DataWidth 16 CONFIG.C0.DDR3_TimePeriod 2500 CONFIG.C0.DDR3_InputClockPeriod 4000 CONFIG.C0.DDR3_CasLatency 6 CONFIG.C0.DDR3_CasWriteLatency 5 CONFIG.C0.DDR3_AxiSelection true CONFIG.C0.DDR3_AxiDataWidth 128 CONFIG.C0.DDR3_AxiIDWidth 1 CONFIG.C0.DDR3_AxiNarrowBurst false CONFIG.C0.DDR3_Mem_Add_Map ROW_COLUMN_BANK CONFIG.System_Clock No_Buffer CONFIG.Debug_Signal Disable] [get_bd_cells mig]
 create_bd_cell -type module -reference board_control clocks_resets
 create_bd_cell -type module -reference databit_block test_engine
 create_bd_cell -type module -reference uart_block uart
 set_property CONFIG.CLK_HZ 100000000 [get_bd_cells test_engine]
 set_property CONFIG.CLK_HZ 100000000 [get_bd_cells uart]
 create_bd_cell -type module -reference native_to_axi native_axi
 puts "MIG PORTS: [get_bd_pins mig/*]"
 puts "MIG INTERFACES: [get_bd_intf_pins mig/*]"
 foreach p {BADJ_CLK_clk_p BADJ_CLK_clk_n} {
  create_bd_port -dir I -type clk -freq_hz 250000000 $p
  connect_bd_net [get_bd_ports $p] [get_bd_pins clocks_resets/$p]
 }
 create_bd_port -dir I -type rst sys_rst
 set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_ports sys_rst]
 connect_bd_net [get_bd_ports sys_rst] [get_bd_pins clocks_resets/sys_rst]
 connect_bd_net [get_bd_pins clocks_resets/ref_clk] [get_bd_pins mig/c0_sys_clk_i]
 connect_bd_net [get_bd_pins clocks_resets/mig_rst] [get_bd_pins mig/sys_rst]
 connect_bd_net [get_bd_pins mig/c0_ddr3_ui_clk] [get_bd_pins clocks_resets/ui_clk] [get_bd_pins test_engine/clk] [get_bd_pins uart/clk] [get_bd_pins native_axi/clk]
 connect_bd_net [get_bd_pins clocks_resets/app_reset] [get_bd_pins test_engine/rst] [get_bd_pins uart/rst] [get_bd_pins native_axi/rst]
 connect_bd_net [get_bd_pins mig/c0_ddr3_ui_clk_sync_rst] [get_bd_pins test_engine/ui_reset] [get_bd_pins native_axi/ui_reset]
 connect_bd_net [get_bd_pins mig/c0_init_calib_complete] [get_bd_pins test_engine/calib_complete]
 create_bd_port -dir O GPIO_LED7
 connect_bd_net [get_bd_ports GPIO_LED7] [get_bd_pins mig/c0_init_calib_complete]
 create_bd_port -dir O tx
 connect_bd_net [get_bd_ports tx] [get_bd_pins uart/tx]
 foreach signal {addr cmd en rdy wdf_data wdf_mask wdf_wren wdf_end wdf_rdy rd_data rd_data_valid rd_data_end} {
  connect_bd_net [get_bd_pins test_engine/app_$signal] [get_bd_pins native_axi/app_$signal]
 }
 foreach signal {record_data record_valid record_ready} {
  connect_bd_net [get_bd_pins test_engine/$signal] [get_bd_pins uart/$signal]
 }
 connect_bd_intf_net [get_bd_intf_pins native_axi/M_AXI] [get_bd_intf_pins mig/C0_DDR3_S_AXI]
 connect_bd_net [get_bd_pins native_axi/axi_aresetn] [get_bd_pins mig/c0_ddr3_aresetn]
 make_bd_intf_pins_external [get_bd_intf_pins mig/C0_DDR3]
 assign_bd_address
 regenerate_bd_layout
 validate_bd_design
 save_bd_design
 set bd_file [get_files wiring.bd]
 make_wrapper -files $bd_file -top
 add_files [file join $base build project wiring_bd.gen sources_1 bd wiring hdl wiring_wrapper.v]
 set_property top wiring_wrapper [current_fileset]
 add_files -fileset constrs_1 [file join $base constraints vcu118.xdc]
 add_files -fileset constrs_1 [file join $base constraints flash_config.xdc]
 add_files -fileset constrs_1 [file join $base constraints reset_cdc.xdc]
 set_property USED_IN_SYNTHESIS false [get_files reset_cdc.xdc]
 update_compile_order -fileset sources_1
 write_bd_tcl -force [file join $base build wiring_export.tcl]
 catch {write_bd_layout -force -format svg [file join $base build wiring.svg]}
 generate_target all $bd_file
 report_ip_status -file [file join $base build ip_status.rpt]
 close_project
}
if {[catch {create_design} message options]} {
 puts stderr "BD CREATE FAILED: $message"
 puts stderr [dict get $options -errorinfo]
 exit 1
}
puts "BD CREATE PASSED"
exit 0
