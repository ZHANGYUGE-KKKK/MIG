proc probe {} {
    open_hw_manager
    connect_hw_server -url localhost:3121
    set targets [get_hw_targets]
    puts "HW TARGETS: $targets"
    if {[llength $targets] != 1} {error "Expected one connected JTAG target"}
    current_hw_target [lindex $targets 0]
    open_hw_target
    foreach dev [get_hw_devices] {
        puts "HW DEVICE: $dev PART=[get_property PART $dev]"
    }
    set parts [get_cfgmem_parts -quiet mt25qu01g-spi-x1_x2_x4_x8]
    puts "FLASH PART: [lindex $parts 0]"
    close_hw_target
    disconnect_hw_server
    close_hw_manager
}
if {[catch {probe} message options]} {
    puts stderr "HARDWARE PROBE FAILED: $message"
    puts stderr [dict get $options -errorinfo]
    exit 1
}
puts "HARDWARE PROBE PASSED"
exit 0
