#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
mkdir -p "$script_dir/build"
for tb in engine_tb telemetry_tb address_tb; do
    verilator --binary --timing -j 2 --top-module "$tb" \
        --Mdir "$script_dir/build/$tb" \
        "$repo_root/VIVADO/rtl/uart_tx.v" "$repo_root"/VIVADO/stress/rtl/*.sv \
        "$script_dir/$tb.sv" > "$script_dir/build/${tb}_compile.log" 2>&1
    "$script_dir/build/$tb/V$tb" | tee "$script_dir/build/${tb}.log"
done
