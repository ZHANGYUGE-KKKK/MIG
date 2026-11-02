set out [file normalize vivado2/debug_online]
open_checkpoint $out/baseline_synth.dcp
set_param general.maxThreads 4
create_debug_core online_ila ila
set_property C_DATA_DEPTH 1024 [get_debug_cores online_ila]
set_property C_TRIGIN_EN false [get_debug_cores online_ila]
set_property C_TRIGOUT_EN false [get_debug_cores online_ila]
set_property C_INPUT_PIPE_STAGES 1 [get_debug_cores online_ila]
connect_debug_port online_ila/clk [get_nets wiring_i/test_engine/clk]
set map [open $out/probes.tsv w]
puts $map "probe\tlabel\tbit\tnet"
set idx 0
proc add_probe {label nets bits} {
 global idx map
 if {![llength $nets]} {error "Empty probe $label"}
 if {$idx > 0} {create_debug_port online_ila probe}
 set port [get_debug_ports online_ila/probe$idx]
 set_property port_width [llength $nets] $port
 connect_debug_port $port $nets
 foreach bit $bits net $nets {puts $map "$idx\t$label\t$bit\t$net"}
 puts "ONLINE_PROBE $idx $label WIDTH=[llength $nets]"
 incr idx
}
add_probe done [get_nets wiring_i/test_engine/done] {0}
foreach stem {total_writes total_reads total_errors fatal_code state pattern actual expected address} {
 set cells [lsort -dictionary [get_cells -hier -regexp [format {wiring_i/test_engine/inst/engine/%s_reg\[[0-9]+\]} $stem]]]
 set nets {};set bits {}
 foreach c $cells {
  regexp {\[([0-9]+)\]$} $c dummy bit
  set n [get_nets -of_objects [get_pins $c/Q]]
  if {[llength $n]!=1} {error "Invalid Q net $c"}
  lappend nets $n;lappend bits $bit
 }
 if {$stem in {total_reads total_writes total_errors} && [llength $nets]!=64} {error "Counter width mismatch $stem"}
 add_probe $stem $nets $bits
}
add_probe calib_complete [get_nets wiring_i/test_engine/calib_complete] {0}
add_probe ui_reset [get_nets wiring_i/test_engine/ui_reset] {0}
close $map
# Hub already exists for MIG; leave its working scan chain configuration intact.
implement_debug_core
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -delay_type min_max -file $out/timing.rpt
report_drc -file $out/drc.rpt
foreach delay {min max} {
 set p [get_timing_paths -delay_type $delay -max_paths 1]
 if {![llength $p] || [get_property SLACK $p]<0} {error "Online ILA $delay timing failed"}
}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {error "DRC errors"}
write_debug_probes -force $out/wiring_online.ltx
write_checkpoint -force $out/wiring_online_routed.dcp
write_bitstream -force $out/wiring_online.bit
puts "ONLINE_ILA_BUILD_PASS"
