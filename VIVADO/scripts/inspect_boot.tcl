proc inspect {} {
    open_hw_manager
    connect_hw_server -url localhost:3121
    set matches {}
    foreach target [get_hw_targets] {
        if {[file tail $target] eq "210308B43939"} {lappend matches $target}
    }
    if {[llength $matches] != 1} {error "Expected the previously verified VCU118 cable"}
    current_hw_target [lindex $matches 0]
    open_hw_target
    set devices [get_hw_devices -filter {PART == xcvu9p}]
    if {[llength $devices] != 1} {error "Expected exactly one xcvu9p"}
    set dev [lindex $devices 0]
    current_hw_device $dev
    refresh_hw_device $dev
    report_property $dev
    puts "DEBUG CORES: [get_hw_ilas -quiet] [get_hw_vios -quiet]"
    puts "MIG QUERY COMMANDS: [info commands *hw_mig*]"
    if {[llength [info commands get_hw_migs]]} {
        set migs [get_hw_migs -quiet]
        puts "MIG DEBUG OBJECTS: $migs"
        foreach mig $migs {report_property $mig}
    }
    close_hw_target
    disconnect_hw_server
    close_hw_manager
}
if {[catch {inspect} message options]} {
    puts stderr "BOOT INSPECTION FAILED: $message"
    puts stderr [dict get $options -errorinfo]
    exit 1
}
puts "BOOT INSPECTION COMPLETED"
exit 0
