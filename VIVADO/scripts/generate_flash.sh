#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
vivado_root="${VIVADO_ROOT:-/home/wenhan/SOFTWARE/VIVADO2022.2/Vivado/2022.2}"
vivado_bin="${VIVADO_BIN:-$vivado_root/bin/vivado}"
mkdir -p "$script_dir/../build"
cd "$script_dir/../build"
exec "$vivado_bin" -mode batch -source "$script_dir/generate_flash.tcl" -log flash_generation.log -journal flash_generation.jou
