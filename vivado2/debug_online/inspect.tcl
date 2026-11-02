open_project vivado2/build/project/wiring_bd.xpr
open_run synth_1
foreach pat {*engine*state* *engine*total* *engine*fatal* *engine*pattern* *engine*actual* *engine*expected* *engine*done* *native_axi*clk* *test_engine*clk*} {
 set nets [get_nets -hier -filter [list NAME =~ $pat]]
 puts "NETS $pat COUNT=[llength $nets] FIRST=[lrange [lsort -dictionary $nets] 0 8]"
}
puts "DEBUG_CORES [get_debug_cores]"
write_checkpoint -force vivado2/debug_online/baseline_synth.dcp
close_project
