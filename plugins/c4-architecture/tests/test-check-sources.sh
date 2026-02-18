#!/usr/bin/env bash
# Test suite for check-sources.sh and check-ast.py
#
# Usage: bash tests/test-check-sources.sh
# Run from the plugin root (plugins/c4-architecture/).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_dir="$(dirname "$script_dir")"
check="$plugin_dir/scripts/check-sources.sh"
fixtures="$script_dir/fixtures"

passed=0
failed=0

# ── Helpers ──────────────────────────────────────────────────────────

run() {
  # Run check-sources.sh, capture exit code and stderr.
  # Usage: run [flags...] <dsl_file>
  local stderr_file
  stderr_file=$(mktemp)
  local exit_code=0
  bash "$check" "$@" 2>"$stderr_file" || exit_code=$?
  LAST_EXIT=$exit_code
  LAST_STDERR=$(cat "$stderr_file")
  rm -f "$stderr_file"
}

assert_exit() {
  local expected=$1 label=$2
  if [[ $LAST_EXIT -eq $expected ]]; then
    echo "  PASS: $label"
    passed=$((passed + 1))
  else
    echo "  FAIL: $label (expected exit $expected, got $LAST_EXIT)"
    [[ -n "$LAST_STDERR" ]] && echo "        stderr: $LAST_STDERR"
    failed=$((failed + 1))
  fi
}

assert_stderr_contains() {
  local pattern=$1 label=$2
  if echo "$LAST_STDERR" | grep -q "$pattern"; then
    echo "  PASS: $label"
    passed=$((passed + 1))
  else
    echo "  FAIL: $label (stderr did not contain: $pattern)"
    echo "        stderr: $LAST_STDERR"
    failed=$((failed + 1))
  fi
}

assert_stderr_not_contains() {
  local pattern=$1 label=$2
  if ! echo "$LAST_STDERR" | grep -q "$pattern"; then
    echo "  PASS: $label"
    passed=$((passed + 1))
  else
    echo "  FAIL: $label (stderr unexpectedly contained: $pattern)"
    failed=$((failed + 1))
  fi
}

# ── Tests ────────────────────────────────────────────────────────────

echo "=== Usage errors ==="

run 2>/dev/null || true
# No arguments — should exit 2
run_no_args_exit=0
bash "$check" 2>/dev/null || run_no_args_exit=$?
LAST_EXIT=$run_no_args_exit
LAST_STDERR=""
assert_exit 2 "No arguments exits 2"

LAST_EXIT=0
LAST_STDERR=""
bash "$check" "/tmp/nonexistent-file.dsl" 2>/dev/null || LAST_EXIT=$?
assert_exit 2 "Nonexistent DSL file exits 2"

echo ""
echo "=== Non-local references (all skipped) ==="

run "$fixtures/architecture/non-local.dsl"
assert_exit 0 "URLs, SSH refs, and FQCNs are skipped"

echo ""
echo "=== Local file paths ==="

run "$fixtures/architecture/all-valid.dsl" --no-ast
assert_exit 0 "All valid paths pass (--no-ast)"

run "$fixtures/architecture/missing-file.dsl"
assert_exit 1 "Missing file detected"
assert_stderr_contains "does-not-exist.py" "Reports the missing filename"
assert_stderr_contains "1 source path" "Reports count"

echo ""
echo "=== Python AST validation ==="

run "$fixtures/architecture/all-valid.dsl"
assert_exit 0 "Valid classes, methods, and async functions pass AST check"

run "$fixtures/architecture/missing-symbol.dsl"
assert_exit 1 "Missing AST symbols detected"
assert_stderr_contains "NonExistentClass" "Reports missing class"
assert_stderr_contains "non_existent" "Reports missing method"

echo ""
echo "=== --no-ast flag ==="

run --no-ast "$fixtures/architecture/missing-symbol.dsl"
assert_exit 0 "Missing symbols ignored with --no-ast (files exist)"
assert_stderr_not_contains "Missing symbol" "No AST errors with --no-ast"

echo ""
echo "=== Non-Python :: suffixes ==="

run "$fixtures/architecture/all-valid.dsl"
assert_exit 0 "Non-Python :: suffix (utils.ts::Logger) passes with file-only check"

# ── Summary ──────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────"
echo "Passed: $passed  Failed: $failed"
echo "─────────────────────────────────"

[[ $failed -eq 0 ]]
