#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
testdir=$(mktemp -d)
trap 'rm -rf "$testdir"' EXIT
for test in serial parallel db15 llapi_map; do
  iverilog -g2012 -s "${test}_tb" -o "$testdir/$test" "tests/controllers/${test}_tb.sv" rtl/controllers/amiga_serial.sv rtl/controllers/llapi.sv rtl/controllers/joydb15.v
  vvp "$testdir/$test"
done
