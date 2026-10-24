# Generate dual-QSPI files only; this script never connects to hardware.
set root [file normalize [file join [file dirname [info script]] ../..]]
proc generate_flash {} {
    global root
    set out [file join $root VIVADO build]
    open_project [file join $out project ddr3_loopback.xpr]
    set run [get_runs impl_1]
    if {[get_property NEEDS_REFRESH [get_runs synth_1]] || [get_property NEEDS_REFRESH $run]} {
        error "Design is stale; run build.sh bitstream before generating Flash images"
    }
    if {![string match "*write_bitstream Complete*" [get_property STATUS $run]]} {
        error "A completed implementation is required"
    }
    open_run impl_1
    set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
    set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 8 [current_design]
    set_property BITSTREAM.CONFIG.CONFIGRATE 31.9 [current_design]
    set flash_bit [file join $out ddr3_flash_compressed.bit]
    write_bitstream -force $flash_bit
    # VCU118 Rev2: two 1-Gbit QSPI parts, 256 MiB combined capacity.
    write_cfgmem -force -format mcs -interface SPIx8 -size 256 \
        -loadbit [list up 0x0 $flash_bit] -file [file join $out ddr3_flash_compressed.mcs]
    foreach name {ddr3_flash_compressed.bit ddr3_flash_compressed_primary.mcs ddr3_flash_compressed_secondary.mcs} {
        set path [file join $out $name]
        if {![file exists $path] || [file size $path] == 0} {error "Missing output: $path"}
        puts "FLASH OUTPUT: $path ([file size $path] bytes)"
    }
    close_project
}
if {[catch {generate_flash} message options]} {
    puts stderr "COMPRESSED FLASH GENERATION FAILED: $message"
    puts stderr [dict get $options -errorinfo]
    exit 1
}
puts "COMPRESSED FLASH GENERATION PASSED"
exit 0
