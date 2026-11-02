set out [file normalize vivado2/debug_online]
open_hw_manager
connect_hw_server -url localhost:3121
set targets [get_hw_targets -filter {NAME =~ *210308B43939*}]
if {[llength $targets]!=1} {error "Known board target missing"}
current_hw_target [lindex $targets 0]
set_property PARAM.FREQUENCY 3000000 [current_hw_target]
open_hw_target
set dev [get_hw_devices -filter {PART == xcvu9p}]
if {[llength $dev]!=1} {error "Expected one xcvu9p"}
current_hw_device $dev
set_property PROGRAM.FILE $out/wiring_online.bit $dev
set_property PROBES.FILE $out/wiring_online.ltx $dev
set_property FULL_PROBES.FILE $out/wiring_online.ltx $dev
program_hw_devices $dev
refresh_hw_device $dev
set ila [get_hw_ilas -of_objects $dev]
if {[llength $ila]!=1} {error "Expected one online ILA"}
report_property $ila
set probes [get_hw_probes -of_objects $ila]
foreach p $probes {puts "ONLINE_HW_PROBE $p";report_property $p}
set done [get_hw_probes -of_objects $ila -filter {NAME =~ *done*}]
if {[llength $done]!=1} {error "Expected one done probe"}
set_property TRIGGER_COMPARE_VALUE eq1'b1 $done
set_property CONTROL.TRIGGER_POSITION 512 $ila
run_hw_ila $ila
wait_on_hw_ila -timeout 100 $ila
set data [upload_hw_ila_data $ila]
write_hw_ila_data -force -csv_file $out/2026-10-29_baseline_ila.csv $data
write_hw_ila_data -force $out/2026-10-29_baseline_ila.ila $data
foreach mig [get_hw_migs -of_objects $dev] {report_hw_mig $mig}
puts "ONLINE_BASELINE_CAPTURE_COMPLETE"
close_hw_target
disconnect_hw_server
close_hw_manager
