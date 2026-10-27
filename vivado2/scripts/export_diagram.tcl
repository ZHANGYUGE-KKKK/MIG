# GUI-only renderer; read-only project and no hardware access.
set base [file normalize [file join [file dirname [info script]] ..]]
if {[catch {
 open_project -read_only [file join $base build project wiring_bd.xpr]
 open_bd_design [get_files wiring.bd]
 write_bd_layout -force -format svg [file join $base build wiring.svg]
} message options]} {
 puts stderr "BD DIAGRAM FAILED: $message"
 exit 1
}
puts "BD DIAGRAM EXPORTED"
close_project
exit 0
