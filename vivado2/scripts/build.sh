#!/usr/bin/env bash
set -euo pipefail
base="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
vivado_bin="${VIVADO_BIN:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2/bin/vivado}"
mkdir -p "$base/build"
"$base/tests/run_sim.sh" > "$base/build/simulation_console.log" 2>&1
if [[ ! -f "$base/build/project/wiring_bd.xpr" ]]; then
 "$vivado_bin" -mode batch -source "$base/scripts/create_bd.tcl" -log "$base/build/create_bd.log" -journal "$base/build/create_bd.jou" > "$base/build/create_bd_console.log" 2>&1
fi
"$vivado_bin" -mode batch -source "$base/scripts/build.tcl" -log "$base/build/build.log" -journal "$base/build/build.jou" -tclargs "${1:-2}" > "$base/build/build_console.log" 2>&1
"$vivado_bin" -mode batch -source "$base/scripts/generate_flash.tcl" -log "$base/build/flash_generation.log" -journal "$base/build/flash_generation.jou" > "$base/build/flash_generation_console.log" 2>&1
python3 "$base/tests/check_artifacts.py"
