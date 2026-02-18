#!/usr/bin/env bash
# check-sources.sh — validate that source properties in a Structurizr DSL
# workspace point to files or directories that actually exist.
#
# Usage:  check-sources.sh [--no-ast] <workspace.dsl>
# Exit 0: all local source paths exist (or no local paths to check)
# Exit 1: one or more paths are missing
#
# Non-local references (URLs, SSH, FQCNs) are silently skipped.
# AST suffixes (::ClassName.method) are stripped before checking the file.
# For Python files, symbols after :: are validated against the AST (requires uv).
# Pass --no-ast to skip symbol validation.

set -euo pipefail

no_ast=false
dsl_file=""

for arg in "$@"; do
  case "$arg" in
    --no-ast) no_ast=true ;;
    -*) echo "Unknown option: $arg" >&2; exit 2 ;;
    *) dsl_file="$arg" ;;
  esac
done

if [[ -z "$dsl_file" ]]; then
  echo "Usage: check-sources.sh [--no-ast] <workspace.dsl>" >&2
  exit 2
fi

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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

missing=0
ast_checks=()

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

  # Split path and optional AST symbol
  path="${source_value%%::*}"
  symbol="${source_value#*::}"
  [[ "$symbol" == "$source_value" ]] && symbol=""

  # Check file/directory existence relative to project root
  if [[ ! -e "$project_root/$path" ]]; then
    echo "Missing: $source_value (resolved: $project_root/$path)" >&2
    missing=$((missing + 1))
  elif [[ -n "$symbol" ]] && [[ "$path" == *.py ]]; then
    # Collect Python AST checks for batch validation
    ast_checks+=("$project_root/$path::$symbol")
  fi
done < <(sed -n 's/^[[:space:]]*source[[:space:]]\{1,\}"\([^"]*\)".*/\1/p' "$dsl_file")

# AST symbol validation for Python files
if [[ ${#ast_checks[@]} -gt 0 ]]; then
  if [[ "$no_ast" == true ]]; then
    : # skip
  elif ! command -v uv &>/dev/null; then
    echo "Error: 'uv' is required to validate Python AST references (::Symbol)." >&2
    echo "Install uv (https://docs.astral.sh/uv/) or use --no-ast to skip symbol validation." >&2
    exit 1
  else
    ast_missing=$(uv run "$script_dir/check-ast.py" "${ast_checks[@]}")
    missing=$((missing + ast_missing))
  fi
fi

if [[ $missing -gt 0 ]]; then
  echo "$missing source path(s) not found." >&2
  exit 1
fi
