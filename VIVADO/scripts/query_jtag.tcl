open_hw_manager
connect_hw_server -url localhost:3121
foreach target [get_hw_targets] {
    puts "TARGET PARAMETERS: $target"
    report_property $target
}
disconnect_hw_server
close_hw_manager
exit 0
