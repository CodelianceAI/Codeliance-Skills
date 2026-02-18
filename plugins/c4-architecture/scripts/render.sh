#!/bin/sh
# render.sh — Export, link-inject, and render C4 architecture diagrams
#
# Usage: render.sh <workspace.dsl> <output-dir>
#
# Pipeline:
#   1. Export .puml from Structurizr DSL
#   2. Strip "structurizr-" prefix from filenames
#   3. Scan boundary declarations to build drill-down link targets
#   4. Inject $link values into .puml files
#   5. Render SVGs with PlantUML
#
# Link injection makes SVG diagrams clickable:
#   - System Context: clicking the primary system opens the Containers view
#   - Containers: clicking a container opens its Components view
#   - Components: sibling containers link to their own component views
#
# Requires: structurizr-cli, plantuml
# Portable: no associative arrays — works with bash 3, zsh, dash

set -e

if [ $# -ne 2 ]; then
  echo "Usage: render.sh <workspace.dsl> <output-dir>" >&2
  exit 1
fi

workspace="$1"
outdir="$2"

if [ ! -f "$workspace" ]; then
  echo "Error: workspace file not found: $workspace" >&2
  exit 1
fi

# Create temp dir for intermediate .puml files
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# ── Step 1: Export ──────────────────────────────────────────────────
structurizr-cli export \
  -workspace "$workspace" \
  -format plantuml/c4plantuml \
  -output "$tmpdir"

# ── Step 2: Strip structurizr- prefix ──────────────────────────────
for f in "$tmpdir"/structurizr-*.puml; do
  [ -f "$f" ] || continue
  mv "$f" "$tmpdir/$(basename "$f" | sed 's/^structurizr-//')"
done

# ── Step 3: Scan boundaries → build link map ───────────────────────
# Each line: <element_type> <identifier> <svg_filename>
# Container_Boundary("X.Y_boundary") → component view for container X.Y
# System_Boundary("X_boundary") alone → container view for system X
link_map="$tmpdir/_link_map.txt"
: > "$link_map"

for f in "$tmpdir"/*.puml; do
  [ -f "$f" ] || continue
  view_name=$(basename "$f" .puml)
  svg_name="${view_name}.svg"

  # Container_Boundary → component view for that container
  cb_id=$(sed -n 's/.*Container_Boundary("\([^"]*\)_boundary".*/\1/p' "$f" | head -1)
  if [ -n "$cb_id" ]; then
    echo "Container ${cb_id} ${svg_name}" >> "$link_map"
    continue
  fi

  # System_Boundary (without Container_Boundary) → container view
  sb_id=$(sed -n 's/.*System_Boundary("\([^"]*\)_boundary".*/\1/p' "$f" | head -1)
  if [ -n "$sb_id" ]; then
    echo "System ${sb_id} ${svg_name}" >> "$link_map"
  fi
done

# ── Step 4: Inject $link values ────────────────────────────────────
while IFS=' ' read -r elem_type elem_id svg_name; do
  # Escape dots for sed regex
  escaped_id=$(echo "$elem_id" | sed 's/\./\\./g')
  for f in "$tmpdir"/*.puml; do
    [ -f "$f" ] || continue
    sed '/'"${elem_type}"'('"${escaped_id}"',/s/\$link=""/\$link="'"${svg_name}"'"/' \
      "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  done
done < "$link_map"

# ── Step 5: Render SVGs ────────────────────────────────────────────
mkdir -p "$outdir"
abs_outdir=$(cd "$outdir" && pwd)
plantuml -tsvg -o "$abs_outdir" "$tmpdir"/*.puml

count=$(ls "$outdir"/*.svg 2>/dev/null | wc -l | tr -d ' ')
echo "Rendered ${count} SVG(s) to $outdir"
