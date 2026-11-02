open_hw_manager
connect_hw_server -url localhost:3121
puts "AUDIT_TARGETS [get_hw_targets]"
set selected {}
foreach target [get_hw_targets] {
 if {[string match *210308B43939* $target]} {lappend selected $target}
}
if {[llength $selected] != 1} {error "Expected one known VCU118 target"}
current_hw_target [lindex $selected 0]
open_hw_target
puts "AUDIT_DEVICES [get_hw_devices]"
set devices [get_hw_devices -filter {PART == xcvu9p}]
if {[llength $devices] != 1} {error "Expected one xcvu9p"}
set dev [lindex $devices 0]
current_hw_device $dev
refresh_hw_device $dev
report_property $dev
puts "AUDIT_ILAS [get_hw_ilas -quiet]"
puts "AUDIT_VIOS [get_hw_vios -quiet]"
puts "AUDIT_MIGS [get_hw_migs -quiet]"
for {set i 0} {$i < 3} {incr i} {
 refresh_hw_device $dev
 puts "AUDIT_REFRESH_OK $i PART=[get_property PART $dev]"
}
close_hw_target
disconnect_hw_server
close_hw_manager
puts "AUDIT_COMPLETE"
