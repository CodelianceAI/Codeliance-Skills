#!/usr/bin/env bash
# Test suite for build-viewer.py and check-viewer.js
#
# Usage: bash tests/test-viewer.sh
# Requires uv and node. The fixture export is the example workspace plus a deployment view
# (fixtures/viewer/deployment-workspace.dsl); with structurizr-cli on PATH it is re-exported and
# checked against the committed JSON.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_dir="$(dirname "$script_dir")"
build="$plugin_dir/scripts/build-viewer.py"
check="$plugin_dir/scripts/check-viewer.js"
fixtures="$script_dir/fixtures/viewer"
export_json="$fixtures/deployment-workspace.json"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

passed=0
failed=0

# ── Helpers ──────────────────────────────────────────────────────────

run() {
  # Run a command, capture exit code and combined output.
  LAST_EXIT=0
  LAST_OUT=$("$@" 2>&1) || LAST_EXIT=$?
}

pass() { echo "  PASS: $1"; passed=$((passed + 1)); }
fail() { echo "  FAIL: $1"; [[ -n "${2:-}" ]] && echo "$2" | sed 's/^/        /'; failed=$((failed + 1)); }

assert_exit() {
  if [[ $LAST_EXIT -eq $1 ]]; then pass "$2"; else fail "$2 (expected exit $1, got $LAST_EXIT)" "$LAST_OUT"; fi
}

assert_contains() {
  if grep -qF -- "$1" <<<"$LAST_OUT"; then pass "$2"; else fail "$2 (output did not contain: $1)" "$LAST_OUT"; fi
}

build_viewer() {
  uv run --quiet --script "$build" "$@"
}

# Rewrite a file in place with a JavaScript expression over its text, `s`.
edit_js() {
  node -e 'const fs = require("fs"); const f = process.argv[1]; let s = fs.readFileSync(f, "utf8");
           const t = eval(process.argv[2]); if (t === s) { console.error("edit_js: no change"); process.exit(1); }
           fs.writeFileSync(f, t);' "$1" "$2"
}

# ── Tests ────────────────────────────────────────────────────────────

echo "=== Build ==="

run build_viewer --out "$work/viewer" example="$export_json"
assert_exit 0 "Builds from the example export"
assert_contains "LiveDeployment (15 elements, 10 relationships)" "Lists the deployment view with its counts"
for f in index.html viewer-core.js model.js vendor/cytoscape.min.js vendor/LICENSE-elkjs; do
  if [[ -f "$work/viewer/$f" ]]; then pass "Writes $f"; else fail "Writes $f"; fi
done

# The page's expected counts against the raw export, read independently of build-viewer.py.
run node -e '
  const fs = require("fs"), vm = require("vm");
  const ws = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  const ctx = {}; ctx.window = ctx; vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(process.argv[2], "utf8"), ctx);
  const got = {};
  for (const v of ctx.C4_VIEWER_MODEL.datasets[0].views) got[v.key] = v.expectedElements + "/" + v.expectedRelationships;
  let n = 0;
  for (const [k, list] of Object.entries(ws.views)) {
    if (!k.endsWith("Views")) continue;
    for (const v of list) {
      n++;
      const want = v.elements.length + "/" + v.relationships.length;
      if (got[v.key] !== want) { console.log("mismatch " + v.key + ": " + got[v.key] + " vs " + want); process.exit(1); }
    }
  }
  if (n !== Object.keys(got).length || n === 0) { console.log("view count " + Object.keys(got).length + " vs " + n); process.exit(1); }
  console.log(n + " views match");' "$export_json" "$work/viewer/model.js"
assert_exit 0 "Every view's expected counts match the raw export"
assert_contains "7 views match" "All seven views are compared"

echo ""
echo "=== Build fails loudly ==="

run build_viewer --out "$work/empty" --views 'example=NoSuchView' example="$export_json"
assert_exit 1 "A view filter that matches nothing fails"
assert_contains "refusing to build an empty viewer" "Says why"

echo '{"model": {}, "views": {}}' > "$work/empty.json"
run build_viewer --out "$work/empty" example="$work/empty.json"
assert_exit 1 "An export with no elements fails"
assert_contains "has no elements" "Says why"

mkdir -p "$work/not-a-viewer"
touch "$work/not-a-viewer/keep.txt"
run build_viewer --out "$work/not-a-viewer" example="$export_json"
assert_exit 1 "Refuses to replace a directory that is not a viewer"
if [[ -f "$work/not-a-viewer/keep.txt" ]]; then pass "Leaves that directory alone"; else fail "Leaves that directory alone"; fi

echo ""
echo "=== Check ==="

run node "$check"
assert_exit 2 "No arguments exits 2"

run node "$check" "$work/viewer"
assert_exit 0 "The example viewer passes"
assert_contains "7 of 7 views hold, collapsed and expanded" "Covers every view"
assert_contains "self-test: 28 of 28 mutations caught" "The self-test catches every mutation"
assert_contains "collapsed 3 boxes + 12 inside of 15 elements" "The deployment view collapses"

echo ""
echo "=== Mutations ==="

# A relationship dropped from the model, as a lossy build would leave it.
cp -R "$work/viewer" "$work/m1"
edit_js "$work/m1/model.js" 's.replace(/\n    "[0-9]+": \{\n     "id": "[0-9]+",\n     "sourceId"[^}]*\},?/, "")'
run node "$check" "$work/m1"
assert_exit 1 "A relationship missing from the model fails the check"
assert_contains "Containers (expanded): relationships 15 + 0 != 16" "The relationship identity fails"
assert_contains "6 of 7 views hold" "The summary counts the failing view"

# Collapse code that loses the elements inside a collapsed box.
cp -R "$work/viewer" "$work/m2"
edit_js "$work/m2/viewer-core.js" 's.replace("n + (vm.synthetic.has(c) ? 0 : 1) + countInside(vm, c)", "n")'
run node "$check" "$work/m2"
assert_exit 1 "Collapse code that loses hidden elements fails the check"
assert_contains "elements 3 + 0 != 15" "The element identity fails on the collapsed deployment view"

# An identity that can no longer fail: the self-test must catch it.
cp -R "$work/viewer" "$work/m3"
edit_js "$work/m3/viewer-core.js" 's.replace("individual + merged === view.expectedRelationships", "true")'
run node "$check" "$work/m3"
assert_exit 1 "An identity that cannot fail fails the self-test"
assert_contains "self-test: dropping relationship" "Names the mutation that survived"

# A viewer built by another version of the plugin.
cp -R "$work/viewer" "$work/m4"
echo "<!-- -->" >> "$work/m4/index.html"
run node "$check" "$work/m4"
assert_exit 1 "A viewer from another plugin version fails"
assert_contains "differs or missing: index.html" "Says which file differs"

echo ""
echo "=== Fixture freshness ==="

if command -v structurizr-cli >/dev/null 2>&1; then
  structurizr-cli export -workspace "$fixtures/deployment-workspace.dsl" -format json -output "$work/fresh" >/dev/null
  build_viewer --out "$work/fresh-viewer" example="$work/fresh/deployment-workspace.json" >/dev/null
  if cmp -s "$work/viewer/model.js" "$work/fresh-viewer/model.js"; then
    pass "The committed export matches a fresh export of the DSL"
  else
    fail "The committed export matches a fresh export of the DSL (re-export it into $fixtures)"
  fi
else
  echo "  SKIP: structurizr-cli not on PATH; the committed export was not compared with the DSL"
fi

# ── Summary ──────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────"
echo "Passed: $passed  Failed: $failed"
echo "─────────────────────────────────"

[[ $failed -eq 0 ]]
