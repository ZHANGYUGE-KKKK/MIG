#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
mkdir -p "$script_dir/build"
verilator --binary --timing --top-module ddr_hello_tb -Wno-fatal \
    --Mdir "$script_dir/build/verilator" \
    "$repo_root/VIVADO/rtl/uart_tx.v" "$repo_root/VIVADO/rtl/ddr_hello.v" \
    "$script_dir/ddr_hello_tb.sv" > "$script_dir/build/compile.log" 2>&1
"$script_dir/build/verilator/Vddr_hello_tb" | tee "$script_dir/build/simulation.log"
rg -q 'ALL TESTS PASSED' "$script_dir/build/simulation.log"
