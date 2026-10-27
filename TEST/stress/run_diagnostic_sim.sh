#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
mkdir -p "$script_dir/build"
verilator --lint-only --timing -Wall --top-module ddr_stress_system -GMAX_READS=1 \
    "$repo_root/VIVADO/rtl/uart_tx.v" "$repo_root"/VIVADO/stress/rtl/*.sv \
    > "$script_dir/build/single_read_lint.log" 2>&1
verilator --binary --timing -j 2 --top-module single_read_tb \
    --Mdir "$script_dir/build/single_read_tb" \
    "$repo_root/VIVADO/stress/rtl/ddr_stress_engine.sv" "$script_dir/single_read_tb.sv" \
    > "$script_dir/build/single_read_tb_compile.log" 2>&1
"$script_dir/build/single_read_tb/Vsingle_read_tb" | tee "$script_dir/build/single_read_tb.log"
