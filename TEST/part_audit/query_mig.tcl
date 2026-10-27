create_project -in_memory audit -part xcvu9p-flga2104-2L-e
create_ip -name ddr3 -vendor xilinx.com -library ip -version 1.4 -module_name audit_mig -dir /home/wenhan/PROJECTS/DDR3_MIG/TEST/part_audit/ip
set ip [get_ips audit_mig]
set f [open /home/wenhan/PROJECTS/DDR3_MIG/TEST/part_audit/mig_part_values.txt w]
puts $f [list_property_value CONFIG.C0.DDR3_MemoryPart $ip]
close $f
set_property -dict [list CONFIG.C0.DDR3_MemoryPart MT41K512M16HA-125 CONFIG.C0.DDR3_DataWidth 16 CONFIG.C0.DDR3_TimePeriod 2500 CONFIG.C0.DDR3_InputClockPeriod 4000 CONFIG.C0.DDR3_CasLatency 6 CONFIG.C0.DDR3_CasWriteLatency 5 CONFIG.C0.DDR3_AxiSelection false CONFIG.System_Clock No_Buffer] $ip
report_property -all $ip -file /home/wenhan/PROJECTS/DDR3_MIG/TEST/part_audit/ha125_properties.txt
exit 0
