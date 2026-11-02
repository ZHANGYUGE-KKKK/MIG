set base [file normalize [file join [file dirname [info script]] ..]]
set rounds [expr {[llength $argv]?[lindex $argv 0]:1}]
set label [expr {[llength $argv]>1?[lindex $argv 1]:"initial"}]
open_hw_manager
connect_hw_server -url localhost:3121
set target [get_hw_targets -filter {NAME =~ *210308B43939*}]
if {[llength $target]!=1} {error "Known target missing"}
current_hw_target $target
set_property PARAM.FREQUENCY 3000000 $target
open_hw_target
set dev [get_hw_devices -filter {PART == xcvu9p}]
if {[llength $dev]!=1} {error "Expected one xcvu9p"}
current_hw_device $dev
set_property PROGRAM.FILE $base/build/wiring_online_axi.bit $dev
set_property PROBES.FILE $base/build/wiring_online_axi.ltx $dev
set_property FULL_PROBES.FILE $base/build/wiring_online_axi.ltx $dev
if {[lindex $argv 2] ne "reuse"} {program_hw_devices $dev}
refresh_hw_device $dev
set ila [get_hw_ilas -of_objects $dev]
set vio [get_hw_vios -of_objects $dev]
if {[llength $ila]!=1 || [llength $vio]!=1} {error "Expected ILA and VIO"}
set out [get_hw_probes -of_objects $vio -filter {NAME =~ *control_probe_out0}]
set cfg [get_hw_probes -of_objects $vio -filter {NAME =~ *control_probe_out1}]
if {[llength $out]!=1 || [llength $cfg]!=1} {error "Expected VIO start and size controls"}
set large [expr {[llength $argv]>3?[lindex $argv 3]:0}]
set_property OUTPUT_VALUE 0 $out
commit_hw_vio $vio
set_property OUTPUT_VALUE $large $cfg
commit_hw_vio $vio
set done [get_hw_probes -of_objects $ila -filter {NAME =~ *test_engine_done*}]
if {[llength $done]!=1} {error "Done probe missing: [get_hw_probes -of_objects $ila]"}
set_property TRIGGER_COMPARE_VALUE eq1'b1 $done
set_property CONTROL.TRIGGER_POSITION 512 $ila
foreach mig [get_hw_migs -of_objects $dev] {
 refresh_hw_mig $mig
 if {[get_property BIT_TIME $mig] ne "625"} {error "Expected DDR1600 bit time625ps"}
 if {[get_property CALIBRATION_FAIL.STATUS $mig] ne "FALSE"} {error "MIG calibration failed"}
 report_hw_mig $mig
}
for {set round 0} {$round<$rounds} {incr round} {
 set_property OUTPUT_VALUE 0 $out
 commit_hw_vio $vio
 after 20
 run_hw_ila $ila
 set_property OUTPUT_VALUE 1 $out
 commit_hw_vio $vio
 wait_on_hw_ila -timeout 60 $ila
 set data [upload_hw_ila_data $ila]
 set name [file join $base build ${label}_round${round}]
 write_hw_ila_data -force -csv_file ${name}.csv $data
 if {$round==0} {write_hw_ila_data -force ${name}.ila $data}
 set decoded [exec python3 $base/tests/decode_ila.py ${name}.csv]
 puts "ONLINE_DIAG_RESULT $round $decoded"
}
foreach mig [get_hw_migs -of_objects $dev] {report_hw_mig $mig}
puts "ONLINE_DIAG_RUN_COMPLETE"
close_hw_target
disconnect_hw_server
close_hw_manager
