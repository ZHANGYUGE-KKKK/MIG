#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
mkdir -p tests/build
verilator --lint-only -Wall --top-module ddr_databit rtl/ddr_databit.sv > tests/build/lint.log 2>&1
verilator --binary --timing --assert -Wall -Wno-UNUSEDSIGNAL -Wno-BLKSEQ --top-module tb_databit --Mdir "$root/tests/build/obj" rtl/ddr_databit.sv tests/tb_databit.sv > tests/build/compile.log 2>&1
for mode in 0 1 2 3 4 5 6 7 8 9; do
 tests/build/obj/Vtb_databit +MODE="$mode" > "tests/build/mode_${mode}.log" 2>&1
done
verilator --binary --timing --assert -Wall -Wno-BLKSEQ --top-module databit_uart_tb --Mdir "$root/tests/build/uart_obj" tests/databit_uart_tb.sv rtl/probe_uart.sv rtl/uart_tx.v > tests/build/uart_compile.log 2>&1
tests/build/uart_obj/Vdatabit_uart_tb > tests/build/uart.log 2>&1
python3 tests/decode.py --self-test | tee tests/build/decoder.log
verilator --lint-only -Wall --top-module native_to_axi rtl/native_to_axi.v > tests/build/axi_lint.log 2>&1
verilator --lint-only -Wall -Wno-UNUSEDSIGNAL --top-module databit_block rtl/databit_block.v rtl/ddr_databit.sv > tests/build/block_lint.log 2>&1
verilator --binary --timing --assert -Wall -Wno-BLKSEQ -Wno-UNUSEDSIGNAL --top-module tb_native_axi --Mdir "$root/tests/build/axi_obj" rtl/native_to_axi.v tests/tb_native_axi.sv > tests/build/axi_compile.log 2>&1
for mode in 0 1 2 3 4 5 6 7 8 9; do
 tests/build/axi_obj/Vtb_native_axi +MODE="$mode" > "tests/build/axi_${mode}.log" 2>&1
done
verilator --binary --timing --assert -Wall -Wno-BLKSEQ -Wno-UNUSEDSIGNAL -Wno-DECLFILENAME --top-module tb_board_control --Mdir "$root/tests/build/board_obj" rtl/board_control.v tests/tb_board_control.sv > tests/build/board_compile.log 2>&1
tests/build/board_obj/Vtb_board_control > tests/build/board.log 2>&1
printf '%s\n' 'VIVADO2 SIMULATIONS PASSED'
