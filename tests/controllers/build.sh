#!/usr/bin/env bash
set -euo pipefail
mode=${1:?mode 0..6};name=${2:?variant name}
[[ "$mode" =~ ^[0-6]$ && "$name" =~ ^[A-Za-z0-9-]+$ ]]
# Each matrix job has its own checkout; append only the fixed protocol macro.
printf '\nset_global_assignment -name VERILOG_MACRO "AMIGA_SERIAL_MODE=%s"\n' "$mode" >> Minimig.qsf
quartus_sh --flow compile Minimig
python3 tests/controllers/timing.py
mkdir -p test-build
cp output_files/Minimig.rbf "test-build/Amiga_${name}_20261029_experimental.rbf"
cp CONTROLLERS-EXPERIMENTAL.md test-build/
printf 'Source: %s\nUpstream: bf5d061b414fa0c8cd56f0e6941c586202ebfbaa\nMODE: %s\nVariant: %s\n' "$(git rev-parse HEAD)" "$mode" "$name" > test-build/SOURCE.txt
cp output_files/timing-acceptance.json test-build/
(cd test-build && sha256sum *.rbf > SHA256SUMS)
