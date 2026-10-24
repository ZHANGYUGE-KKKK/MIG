set root [file normalize [file join [file dirname [info script]] ../..]]
set stage [expr {[llength $argv] ? [lindex $argv 0] : "bitstream"}]
set jobs [expr {[llength $argv] > 1 ? [lindex $argv 1] : 2}]
proc require_run {name} {
    wait_on_run $name
    set status [get_property STATUS [get_runs $name]]
    if {![string match "*Complete*" $status]} {error "$name failed: $status"}
}
proc build {} {
    global root stage jobs
    if {$stage ni {prepare synth impl bitstream}} {error "Expected prepare, synth, impl, or bitstream"}
    if {![string is integer -strict $jobs] || $jobs < 1} {error "jobs must be positive"}
    set_param general.maxThreads 4
    set project [file join $root VIVADO build project ddr3_loopback.xpr]
    if {[file exists $project]} {
        open_project $project
    } else {
        create_project ddr3_loopback [file dirname $project] -part xcvu9p-flga2104-2L-e
        set_property target_language Verilog [current_project]
        add_files [glob [file join $root VIVADO rtl *.v]]
        add_files -fileset constrs_1 [file join $root VIVADO constraints vcu118.xdc]
        set_property top ddr3_loopback_top [current_fileset]
    }
    source [file join $root VIVADO ip ddr3_config.tcl]
    foreach rtl [glob [file join $root VIVADO rtl *.v]] {
        if {![llength [get_files -quiet $rtl]]} {add_files -norecurse $rtl}
    }
    update_compile_order -fileset sources_1
    generate_target all [get_ips ddr3_mig]
    report_ip_status -file [file join $root VIVADO build ip_status.rpt]
    if {$stage eq "prepare"} {close_project; return}
    create_ip_run [get_ips ddr3_mig]
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%" || [get_property NEEDS_REFRESH [get_runs synth_1]]} {
        if {[get_property STATUS [get_runs synth_1]] ne "Not started"} {reset_run synth_1}
        launch_runs synth_1 -jobs $jobs
    }
    require_run synth_1
    if {$stage eq "synth"} {close_project; return}
    set step [expr {$stage eq "impl" ? "route_design" : "write_bitstream"}]
    if {![string match "*${step} Complete*" [get_property STATUS [get_runs impl_1]]] &&
        ![string match "*write_bitstream Complete*" [get_property STATUS [get_runs impl_1]]]} {
        launch_runs impl_1 -to_step $step -jobs $jobs
    }
    require_run impl_1
    open_run impl_1
    report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -file [file join $root VIVADO build timing_summary.rpt]
    report_drc -file [file join $root VIVADO build drc.rpt]
    report_io -file [file join $root VIVADO build io.rpt]
    report_clocks -file [file join $root VIVADO build clocks.rpt]
    report_route_status -file [file join $root VIVADO build route_status.rpt]
    report_bus_skew -file [file join $root VIVADO build bus_skew.rpt]
    if {[get_property PACKAGE_PIN [get_ports GPIO_LED7]] ne "BA37" ||
        [get_property IOSTANDARD [get_ports GPIO_LED7]] ne "LVCMOS12"} {error "LED 7 pin constraint mismatch"}
    set f [open [file join $root VIVADO build bus_skew.rpt]]
    set skew [read $f]
    close $f
    if {[string match "*VIOLATED*" $skew]} {error "Bus skew violation"}
    report_utilization -file [file join $root VIVADO build utilization.rpt]
    foreach delay {min max} {
        set path [get_timing_paths -quiet -delay_type $delay -max_paths 1]
        if {![llength $path] || [get_property SLACK $path] < 0} {error "Missing or failing $delay timing path"}
    }
    set f [open [file join $root VIVADO build timing_summary.rpt]]
    set timing [read $f]
    close $f
    if {![string match "*All user specified timing constraints are met.*" $timing]} {error "Timing constraints not met"}
    if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {error "DRC errors remain"}
    if {$stage eq "bitstream"} {
        file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] ddr3_loopback_top.bit] [file join $root VIVADO build ddr3_loopback.bit]
    }
    close_project
}
if {[catch {build} message options]} {
    puts stderr "BUILD FAILED: $message"
    puts stderr [dict get $options -errorinfo]
    exit 1
}
puts "BUILD PASSED: $stage"
exit 0
