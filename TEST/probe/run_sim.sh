#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p TEST/probe/build
verilator --lint-only --timing -Wall --top-module probe_system VIVADO/rtl/uart_tx.v VIVADO/probe/rtl/*.sv > TEST/probe/build/lint.log 2>&1
verilator --binary --timing -j 2 --top-module probe_tb --Mdir "$PWD/TEST/probe/build/engine" VIVADO/probe/rtl/ddr_probe.sv TEST/probe/probe_tb.sv > TEST/probe/build/compile.log 2>&1
TEST/probe/build/engine/Vprobe_tb | tee TEST/probe/build/engine.log
verilator --binary --timing -j 2 --top-module uart_tb --Mdir "$PWD/TEST/probe/build/uart" VIVADO/rtl/uart_tx.v VIVADO/probe/rtl/probe_uart.sv TEST/probe/uart_tb.sv > TEST/probe/build/uart_compile.log 2>&1
TEST/probe/build/uart/Vuart_tb | tee TEST/probe/build/uart.log
