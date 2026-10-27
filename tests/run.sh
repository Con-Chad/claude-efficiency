#!/usr/bin/env bash
# run.sh — run every tests/test_*.sh. Plain bash, no runtime dependencies.
# Test exit codes: 0 = pass, 77 = skipped (with reason printed), anything else = fail.
# Usage: bash tests/run.sh            (all tests)
#        bash tests/run.sh brake      (only tests whose name contains "brake")
# Also works as tests/process/run.sh (layout used by adopt-into.sh when a
# project already has its own tests/run.sh): ROOT is then two levels up.
set -u
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
case "$TESTS_DIR" in
  */tests/process) ROOT="$(cd "$TESTS_DIR/../.." && pwd)" ;;
  *) ROOT="$(cd "$TESTS_DIR/.." && pwd)" ;;
esac
export ROOT
filter="${1:-}"
pass=0; fail=0; skip=0; failed=""

for t in "$TESTS_DIR"/test_*.sh; do
  name="$(basename "$t" .sh)"
  case "$name" in *"$filter"*) ;; *) continue;; esac
  out="$(cd "$ROOT" && bash "$t" 2>&1)"; rc=$?
  if [ $rc -eq 0 ]; then
    pass=$((pass + 1)); echo "PASS  $name"
  elif [ $rc -eq 77 ]; then
    skip=$((skip + 1)); echo "SKIP  $name — $(printf '%s' "$out" | tail -1)"
  else
    fail=$((fail + 1)); failed="$failed $name"; echo "FAIL  $name"
    printf '%s\n' "$out" | sed 's/^/      /'
  fi
done

total=$((pass + fail + skip))
echo "----"
echo "$total tests: $pass passed, $fail failed, $skip skipped"
[ "$total" -eq 0 ] && { echo "ERROR: no tests ran — that is not a pass."; exit 1; }
[ $fail -gt 0 ] && { echo "Failed:$failed"; exit 1; }
exit 0
