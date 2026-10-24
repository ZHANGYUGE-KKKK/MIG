# Migrated from the reference C910_SOC DDR3 1.4 configuration; native UI replaces AXI.
if {![llength [get_ips -quiet ddr3_mig]]} {
    create_ip -name ddr3 -vendor xilinx.com -library ip -version 1.4 -module_name ddr3_mig
}
set_property -dict [list \
    CONFIG.C0.DDR3_MemoryPart {MT41K512M16HA-125} \
    CONFIG.C0.DDR3_DataWidth {16} \
    CONFIG.C0.DDR3_TimePeriod {1250} \
    CONFIG.C0.DDR3_InputClockPeriod {4000} \
    CONFIG.C0.DDR3_CasLatency {11} \
    CONFIG.C0.DDR3_CasWriteLatency {8} \
    CONFIG.C0.DDR3_AxiSelection {false} \
    CONFIG.System_Clock {No_Buffer} \
    CONFIG.Debug_Signal {Disable}] [get_ips ddr3_mig]
