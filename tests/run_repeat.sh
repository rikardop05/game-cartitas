#!/bin/sh
# Usage: tests/run_repeat.sh <test_name> <runs> [timeout_s]  -- runs a test N times, counts hangs/failures.
T=${1:-smoke_rapid_taps}; N=${2:-20}; TO=${3:-60}
G=./Godot/Godot_v4.7-stable_win64_console.exe
ok=0; fail=0; hang=0
for i in $(seq 1 $N); do
  timeout $TO $G --path . --headless --script res://tests/$T.gd > /tmp/rep_$i.txt 2>&1
  rc=$?
  if [ $rc -eq 124 ]; then hang=$((hang+1)); echo "run $i: HANG"; elif [ $rc -eq 0 ]; then ok=$((ok+1)); echo "run $i: ok"; else fail=$((fail+1)); echo "run $i: FAIL rc=$rc"; fi
done
echo "RESULT ok=$ok fail=$fail hang=$hang of $N"
