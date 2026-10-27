#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
mkdir -p TEST/databit/build
verilator --lint-only -Wall --top-module ddr_databit VIVADO/databit/rtl/ddr_databit.sv > TEST/databit/build/lint.log 2>&1
verilator --binary --timing --assert -Wall -Wno-UNUSEDSIGNAL -Wno-BLKSEQ --top-module tb_databit --Mdir "$root/TEST/databit/build/obj" VIVADO/databit/rtl/ddr_databit.sv TEST/databit/tb_databit.sv > TEST/databit/build/compile.log 2>&1
for mode in 0 1 2 3 4 5 6 7 8 9; do
 TEST/databit/build/obj/Vtb_databit +MODE="$mode" > "TEST/databit/build/mode_${mode}.log" 2>&1
done
verilator --binary --timing --assert -Wall -Wno-BLKSEQ --top-module databit_uart_tb --Mdir "$root/TEST/databit/build/uart_obj" TEST/databit/databit_uart_tb.sv VIVADO/probe/rtl/probe_uart.sv VIVADO/rtl/uart_tx.v > TEST/databit/build/uart_compile.log 2>&1
TEST/databit/build/uart_obj/Vdatabit_uart_tb > TEST/databit/build/uart.log 2>&1
python3 TEST/databit/decode.py --self-test | tee TEST/databit/build/decoder.log
