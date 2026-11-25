#!/usr/bin/env bash
# Run the self-checking testbenches with Icarus Verilog.
#
#   scripts/sim.sh               run every sim/tb_*.v
#   scripts/sim.sh player_ctrl   run sim/tb_player_ctrl.v only (several names allowed)
#
# Each testbench is compiled with `iverilog -g2005 -Wall -I src`, with
# tb_<name> as the only root, against every file in src/. The script exits
# non-zero if any testbench fails to compile, prints FAIL, or does not end
# with "PASS tb_<name>". Logs go to build/sim/.
set -u

cd "$(dirname "$0")/.." || exit 2
out=build/sim
mkdir -p "$out"

if ! command -v iverilog >/dev/null 2>&1; then
  echo "iverilog not found. Install Icarus Verilog (brew install icarus-verilog)."
  exit 2
fi

tbs=()
if [ $# -gt 0 ]; then
  for n in "$@"; do
    n=${n#tb_}; n=${n%.v}
    tbs+=("sim/tb_${n}.v")
  done
else
  for f in sim/tb_*.v; do tbs+=("$f"); done
fi

pass=0
fail=0
failed=()
for tb in "${tbs[@]}"; do
  name=$(basename "$tb" .v)
  if [ ! -f "$tb" ]; then
    echo "MISSING  $tb"
    fail=$((fail + 1)); failed+=("$name"); continue
  fi
  if ! iverilog -g2005 -Wall -I src -s "$name" -o "$out/$name.vvp" "$tb" src/*.v \
       > "$out/$name.compile.log" 2>&1; then
    cat "$out/$name.compile.log"
    echo "COMPILE FAIL  $name"
    fail=$((fail + 1)); failed+=("$name"); continue
  fi
  if [ -s "$out/$name.compile.log" ]; then
    echo "--- compiler warnings for $name:"
    cat "$out/$name.compile.log"
  fi
  start=$(date +%s)
  vvp -n "$out/$name.vvp" > "$out/$name.log" 2>&1
  secs=$(( $(date +%s) - start ))
  if grep -q "FAIL" "$out/$name.log" || ! grep -qx "PASS $name" "$out/$name.log"; then
    grep -v "^VCD info" "$out/$name.log" | tail -40
    echo "FAIL  $name  (${secs}s, full log: $out/$name.log)"
    fail=$((fail + 1)); failed+=("$name")
  else
    echo "PASS  $name  (${secs}s)"
    pass=$((pass + 1))
  fi
done

echo "----"
echo "$pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  echo "failed: ${failed[*]}"
  exit 1
fi
exit 0
