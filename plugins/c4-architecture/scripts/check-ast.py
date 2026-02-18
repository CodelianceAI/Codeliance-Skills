# /// script
# requires-python = ">=3.9"
# ///
"""Validate that symbols exist in Python source files.

Takes arguments in the form: /path/to/file.py::SymbolName
Supports dotted paths: /path/to/file.py::ClassName.method

Prints missing symbols to stderr, prints total missing count to stdout.
"""
import ast
import sys


def find_symbol(node, parts):
    """Walk one level of the AST looking for the next name in the chain."""
    target = parts[0]
    rest = parts[1:]
    for child in ast.iter_child_nodes(node):
        if isinstance(child, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            if child.name == target:
                if not rest:
                    return True
                return find_symbol(child, rest)
    return False


missing = 0
for arg in sys.argv[1:]:
    file_path, symbol = arg.rsplit("::", 1)
    parts = symbol.split(".")

    try:
        with open(file_path) as f:
            tree = ast.parse(f.read(), filename=file_path)
    except (OSError, SyntaxError) as exc:
        print(f"Cannot parse {file_path}: {exc}", file=sys.stderr)
        missing += 1
        continue

    if not find_symbol(tree, parts):
        print(f"Missing symbol: {symbol} in {file_path}", file=sys.stderr)
        missing += 1

print(missing)
