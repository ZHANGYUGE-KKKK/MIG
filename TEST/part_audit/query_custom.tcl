create_project -in_memory audit_custom -part xcvu9p-flga2104-2L-e
file mkdir /home/wenhan/PROJECTS/DDR3_MIG/TEST/part_audit/custom_ip
create_ip -name ddr3 -vendor xilinx.com -library ip -version 1.4 -module_name custom_mig -dir /home/wenhan/PROJECTS/DDR3_MIG/TEST/part_audit/custom_ip
set ip [get_ips custom_mig]
set_property CONFIG.C0.DDR3_CustomParts /home/wenhan/PROJECTS/DDR3_MIG/TEST/part_audit/vrp107_trial.csv $ip
set_property -dict [list CONFIG.C0.DDR3_MemoryPart VRP107_800_DIE CONFIG.C0.DDR3_DataWidth 16 CONFIG.C0.DDR3_TimePeriod 2500 CONFIG.C0.DDR3_InputClockPeriod 4000 CONFIG.C0.DDR3_CasLatency 6 CONFIG.C0.DDR3_CasWriteLatency 5 CONFIG.C0.DDR3_AxiSelection false CONFIG.C0.DDR3_MemoryVoltage 1.5V CONFIG.System_Clock No_Buffer] $ip
generate_target all $ip
report_property -all $ip -file /home/wenhan/PROJECTS/DDR3_MIG/TEST/part_audit/custom_properties.txt
exit 0
