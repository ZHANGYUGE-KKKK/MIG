# Explicit hardware mutation: program the two MCS images into one selected VCU118.
# Usage: vivado -mode batch -source program_flash.tcl -tclargs <Digilent serial>
set root [file normalize [file join [file dirname [info script]] ../..]]
proc program_flash {} {
    global root argv
    if {[llength $argv] != 1} {error "Supply the previously verified Digilent cable serial"}
    set serial [lindex $argv 0]
    if {$serial ne "210308B43939"} {error "Expected the verified VCU118 cable serial"}
    open_hw_manager
    connect_hw_server -url localhost:3121
    set matches {}
    foreach t [get_hw_targets] {
        if {[file tail $t] eq $serial} {lappend matches $t}
    }
    if {[llength $matches] != 1} {error "Expected exactly one JTAG target matching $serial"}
    current_hw_target [lindex $matches 0]
    open_hw_target
    set devices [get_hw_devices -filter {PART == xcvu9p}]
    if {[llength $devices] != 1} {error "Expected exactly one xcvu9p device on the selected cable"}
    set dev [lindex $devices 0]
    current_hw_device $dev
    refresh_hw_device $dev
    puts "SELECTED HARDWARE: [current_hw_target] / $dev PART=[get_property PART $dev]"
    set parts [get_cfgmem_parts -quiet mt25qu01g-spi-x1_x2_x4_x8]
    if {![llength $parts]} {error "Required dual-QSPI memory part not found"}
    create_hw_cfgmem -hw_device $dev -mem_dev [lindex $parts 0]
    set cfg [get_property PROGRAM.HW_CFGMEM $dev]
    set files [list [file join $root vivado2 build wiring_bd_800_primary.mcs] \
                    [file join $root vivado2 build wiring_bd_800_secondary.mcs]]
    foreach f $files {if {![file exists $f]} {error "Missing MCS: $f"}}
    puts "BD 800 MT/s FLASH FILES: $files"
    set_property PROGRAM.ADDRESS_RANGE use_file $cfg
    set_property PROGRAM.FILES $files $cfg
    set_property PROGRAM.PRM_FILE {} $cfg
    set_property PROGRAM.UNUSED_PIN_TERMINATION pull-none $cfg
    set_property PROGRAM.BLANK_CHECK 0 $cfg
    set_property PROGRAM.ERASE 1 $cfg
    set_property PROGRAM.CFG_PROGRAM 1 $cfg
    set_property PROGRAM.VERIFY 1 $cfg
    set_property PROGRAM.CHECKSUM 0 $cfg
    # Load Vivado's indirect SPI programming helper into the FPGA SRAM.
    create_hw_bitstream -hw_device $dev [get_property PROGRAM.HW_CFGMEM_BITFILE $dev]
    program_hw_devices $dev
    puts "FLASH OPERATION: erase used sectors, program both QSPI parts, verify"
    program_hw_cfgmem -hw_cfgmem $cfg
    puts "FLASH PROGRAM AND VERIFY PASSED"
    # Boot is a separate operation so flash verification has an unambiguous result.
    close_hw_target
    disconnect_hw_server
    close_hw_manager
}
if {[catch {program_flash} message options]} {
    puts stderr "BD 800 FLASH PROGRAM FAILED: $message"
    puts stderr [dict get $options -errorinfo]
    exit 1
}
puts "BD 800 FLASH PROGRAM PASSED"
exit 0
