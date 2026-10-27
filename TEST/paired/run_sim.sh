#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p TEST/paired/build
for hz in 200000000 100000000; do
 verilator --lint-only --timing -Wall --top-module pair_system -GCLK_HZ="$hz" VIVADO/rtl/uart_tx.v VIVADO/probe/rtl/probe_uart.sv VIVADO/paired/rtl/*.sv > "TEST/paired/build/lint_${hz}.log" 2>&1
 verilator --binary --timing -j 2 --top-module pair_tb -GCLK_HZ="$hz" --Mdir "$PWD/TEST/paired/build/engine_${hz}" VIVADO/paired/rtl/ddr_pair.sv TEST/paired/pair_tb.sv > "TEST/paired/build/compile_${hz}.log" 2>&1
 "TEST/paired/build/engine_${hz}/Vpair_tb" | tee "TEST/paired/build/engine_${hz}.log"
 verilator --binary --timing -j 2 --top-module paired_uart_tb -GCLK_HZ="$hz" --Mdir "$PWD/TEST/paired/build/uart_${hz}" VIVADO/rtl/uart_tx.v VIVADO/probe/rtl/probe_uart.sv TEST/paired/paired_uart_tb.sv > "TEST/paired/build/uart_compile_${hz}.log" 2>&1
 "TEST/paired/build/uart_${hz}/Vpaired_uart_tb" | tee "TEST/paired/build/uart_${hz}.log"
done
