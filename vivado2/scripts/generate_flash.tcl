set base [file normalize [file join [file dirname [info script]] ..]]
proc generate_flash {} {
 global base
 open_project [file join $base build project wiring_bd.xpr]
 foreach name {synth_1 impl_1} {
  if {[get_property NEEDS_REFRESH [get_runs $name]]} {error "$name is stale; rebuild before Flash generation"}
 }
 if {![string match "*write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {error "Bitstream is not complete"}
 open_run impl_1
 if {![get_property BITSTREAM.GENERAL.COMPRESS [current_design]] || [get_property BITSTREAM.CONFIG.SPI_BUSWIDTH [current_design]]!=8 || abs([get_property BITSTREAM.CONFIG.CONFIGRATE [current_design]]-31.9)>0.01} {error "Expected compressed SPIx8/31.9 MHz"}
 set f [open [file join $base build flash_settings.rpt] w]
 foreach key {BITSTREAM.GENERAL.COMPRESS BITSTREAM.CONFIG.SPI_BUSWIDTH BITSTREAM.CONFIG.CONFIGRATE} {puts $f "$key=[get_property $key [current_design]]"}
 close $f
 set bit [file join $base build wiring_bd_800.bit]
 file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] wiring_wrapper.bit] $bit
 write_cfgmem -force -format mcs -interface SPIx8 -size 256 -loadbit [list up 0x0 $bit] -file [file join $base build wiring_bd_800.mcs]
 foreach suffix {.bit _primary.mcs _secondary.mcs} {
  set path [file join $base build wiring_bd_800$suffix]
  if {![file exists $path] || [file size $path]==0} {error "Missing Flash artifact $path"}
  puts "FLASH OUTPUT: $path ([file size $path] bytes)"
 }
 close_project
}
if {[catch {generate_flash} message options]} {puts stderr "BD FLASH FAILED: $message";puts stderr [dict get $options -errorinfo];exit 1}
puts "BD FLASH GENERATION PASSED (FILES ONLY)"
exit 0
