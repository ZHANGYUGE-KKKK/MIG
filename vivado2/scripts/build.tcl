set base [file normalize [file join [file dirname [info script]] ..]]
set jobs [expr {[llength $argv]?[lindex $argv 0]:2}]
proc require_run {name} {
 wait_on_run $name
 set status [get_property STATUS [get_runs $name]]
 if {![string match "*Complete*" $status]} {error "$name failed: $status"}
}
proc build {} {
 global base jobs
 open_project [file join $base build project wiring_bd.xpr]
 open_bd_design [get_files wiring.bd]
 validate_bd_design
 save_bd_design
 generate_target all [get_files wiring.bd]
 set_param general.maxThreads 4
 foreach ip [get_ips -filter {IS_LOCKED == 0}] {catch {create_ip_run $ip}}
 if {[get_property PROGRESS [get_runs synth_1]] ne "100%" || [get_property NEEDS_REFRESH [get_runs synth_1]]} {
  if {[get_property STATUS [get_runs synth_1]] ne "Not started"} {reset_run synth_1}
  launch_runs synth_1 -jobs $jobs
 }
 require_run synth_1
 if {[get_property NEEDS_REFRESH [get_runs impl_1]]} {reset_run impl_1}
 if {![string match "*write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {launch_runs impl_1 -to_step write_bitstream -jobs $jobs}
 require_run impl_1
 open_run impl_1
 set ui_clocks [get_clocks -quiet -filter {NAME =~ *mmcm_clkout0*}]
 if {[llength $ui_clocks]!=1 || abs([get_property PERIOD $ui_clocks]-10.0)>0.01} {error "Expected 100 MHz UI clock"}
 set pins [get_pins -hier -regexp {.*app_reset_sync_reg\[[012]\]/PRE}]
 if {[llength $pins]!=3} {error "Expected 3 reset PRE pins"}
 foreach cell [get_cells -of_objects $pins] {if {![get_property ASYNC_REG $cell]} {error "Missing ASYNC_REG"}}
 for {set i 0} {$i<3} {incr i} {
  set cells($i) [get_cells -hier -regexp [format {.*app_reset_sync_reg\[%d\]} $i]]
  if {[llength $cells($i)]!=1} {error "Expected unique reset stage $i"}
 }
 for {set i 0} {$i<2} {incr i} {
  set j [expr {$i+1}]
  set from [get_pins $cells($i)/Q];set to [get_pins $cells($j)/D]
  set paths [get_timing_paths -from $from -to $to -max_paths 1]
  if {![llength $paths] || [get_property SLACK $paths]<0} {error "Reset stage timing failed"}
  report_timing -from $from -to $to -file [file join $base build reset_stage_${i}.rpt]
 }
 set paths [get_timing_paths -from [get_pins $cells(2)/Q] -max_paths 1]
 if {![llength $paths] || [get_property SLACK $paths]<0} {error "Reset output timing failed"}
 report_timing -from [get_pins $cells(2)/Q] -file [file join $base build reset_output.rpt]
 report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -file [file join $base build timing_summary.rpt]
 report_drc -file [file join $base build drc.rpt]
 report_bus_skew -file [file join $base build bus_skew.rpt]
 report_route_status -file [file join $base build route_status.rpt]
 report_io -file [file join $base build io.rpt]
 report_clocks -file [file join $base build clocks.rpt]
 report_utilization -file [file join $base build utilization.rpt]
 report_exceptions -file [file join $base build exceptions.rpt]
 if {[get_property PACKAGE_PIN [get_ports GPIO_LED7]] ne "BA37" || [get_property IOSTANDARD [get_ports GPIO_LED7]] ne "LVCMOS12"} {error "LED7 pin mismatch"}
 foreach delay {min max} {
  set path [get_timing_paths -quiet -delay_type $delay -max_paths 1]
  if {![llength $path] || [get_property SLACK $path]<0} {error "$delay timing failed"}
 }
 foreach report {timing_summary bus_skew} {
  set f [open [file join $base build ${report}.rpt]];set text [read $f];close $f
  if {[string match "*VIOLATED*" $text]} {error "$report violation"}
  if {$report eq "timing_summary" && ![string match "*All user specified timing constraints are met.*" $text]} {error "Timing constraints not met"}
 }
 if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {error "DRC errors"}
 file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] wiring_wrapper.bit] [file join $base build wiring_bd_800.bit]
 close_project
}
if {[catch {build} message options]} {puts stderr "BD BUILD FAILED: $message";puts stderr [dict get $options -errorinfo];exit 1}
puts "BD BUILD PASSED"
exit 0
