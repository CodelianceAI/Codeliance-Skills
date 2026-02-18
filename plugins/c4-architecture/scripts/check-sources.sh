#!/usr/bin/env bash
# check-sources.sh — validate that source properties in a Structurizr DSL
# workspace point to files or directories that actually exist.
#
# Usage:  check-sources.sh <workspace.dsl>
# Exit 0: all local source paths exist (or no local paths to check)
# Exit 1: one or more paths are missing
#
# Non-local references (URLs, SSH, FQCNs) are silently skipped.
# AST suffixes (::ClassName.method) are stripped before checking.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: check-sources.sh <workspace.dsl>" >&2
  exit 2
fi

dsl_file="$1"

if [[ ! -f "$dsl_file" ]]; then
  echo "Error: DSL file not found: $dsl_file" >&2
  exit 2
fi

# Resolve project root: parent of the architecture/ directory that
# typically contains the workspace. If the DSL isn't under architecture/,
# fall back to the DSL file's parent directory.
dsl_dir="$(cd "$(dirname "$dsl_file")" && pwd)"
if [[ "$(basename "$dsl_dir")" == "architecture" ]]; then
  project_root="$(dirname "$dsl_dir")"
else
  project_root="$dsl_dir"
fi

missing=0

# Extract source property values from the DSL.
# Matches lines like:   source "path/to/file.ts"
# inside properties blocks.
while IFS= read -r source_value; do
  # Skip empty values
  [[ -z "$source_value" ]] && continue

  # Skip non-local references: URLs, SSH, and FQCN patterns
  [[ "$source_value" == *"://"* ]] && continue
  [[ "$source_value" == git@* ]] && continue

  # Skip Java-style FQCNs (e.g. com.example.service.OrderService)
  # Heuristic: 3+ dot-separated segments with no slashes
  if [[ "$source_value" != */* ]] && [[ "$source_value" =~ \..+\..+ ]]; then
    continue
  fi

  # Strip AST suffix (::ClassName, ::ClassName.method, etc.)
  path="${source_value%%::*}"

  # Check existence relative to project root
  if [[ ! -e "$project_root/$path" ]]; then
    echo "Missing: $source_value (resolved: $project_root/$path)" >&2
    missing=$((missing + 1))
  fi
done < <(sed -n 's/^[[:space:]]*source[[:space:]]\{1,\}"\([^"]*\)".*/\1/p' "$dsl_file")

if [[ $missing -gt 0 ]]; then
  echo "$missing source path(s) not found." >&2
  exit 1
fi
