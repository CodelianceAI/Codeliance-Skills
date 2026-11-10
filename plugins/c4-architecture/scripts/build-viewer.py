#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Build an interactive, collapsible viewer from Structurizr workspace JSON exports.

Usage:
  build-viewer.py --out DIR [--title TEXT] [--views LABEL=REGEX ...] LABEL=EXPORT.json [LABEL=EXPORT.json ...]

Each export is one dataset in the page's view selector, under its label. --views keeps only the
views of that dataset whose key matches REGEX in full (say, only an extending workspace's own
views). DIR receives index.html, viewer-core.js and vendor/ verbatim from the plugin, and model.js,
the only file a model change rewrites. The page opens offline from disk.

Produce an export with: structurizr-cli export -workspace workspace.dsl -format json -output DIR
"""

import argparse
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path

VIEWER = Path(__file__).resolve().parent.parent / "viewer"
# View kinds in C4 zoom order; the page lists views in this order.
KINDS = ["systemLandscape", "systemContext", "container", "component", "dynamic", "deployment", "custom"]
UNSUPPORTED = ["filteredViews", "imageViews"]


def split_tags(s):
    return [t.strip() for t in (s or "").split(",") if t.strip()]


def walk_model(model):
    """Flatten the model into {id: element} with parentId, and {id: relationship}."""
    els, rels = {}, {}

    def add(e, kind, parent=None, **extra):
        els[e["id"]] = {
            "id": e["id"],
            "kind": kind,
            "name": e.get("name") or "",
            "technology": e.get("technology") or "",
            "description": e.get("description") or "",
            "tags": split_tags(e.get("tags")),
            "source": (e.get("properties") or {}).get("source", ""),
            "parentId": parent,
            **extra,
        }
        for r in e.get("relationships") or []:
            rels[r["id"]] = {
                "id": r["id"],
                "sourceId": r["sourceId"],
                "destinationId": r["destinationId"],
                "description": r.get("description") or "",
                "technology": r.get("technology") or "",
                "tags": split_tags(r.get("tags")),
            }

    for p in model.get("people") or []:
        add(p, "Person")
    for s in model.get("softwareSystems") or []:
        add(s, "SoftwareSystem")
        for c in s.get("containers") or []:
            add(c, "Container", s["id"])
            for k in c.get("components") or []:
                add(k, "Component", c["id"])
    for e in model.get("customElements") or []:
        add(e, "CustomElement")

    def deployment_node(n, parent):
        add(n, "DeploymentNode", parent)
        for c in n.get("children") or []:
            deployment_node(c, n["id"])
        for i in n.get("infrastructureNodes") or []:
            add(i, "InfrastructureNode", n["id"])
        for i in n.get("containerInstances") or []:
            add(i, "ContainerInstance", n["id"], instanceOf=i["containerId"])
        for i in n.get("softwareSystemInstances") or []:
            add(i, "SoftwareSystemInstance", n["id"], instanceOf=i["softwareSystemId"])

    for n in model.get("deploymentNodes") or []:
        deployment_node(n, None)

    # An instance has no name, technology or description of its own: it shows its container's.
    for e in els.values():
        src = els.get(e.get("instanceOf"))
        if src:
            e["name"], e["technology"], e["description"] = src["name"], src["technology"], src["description"]
            e["source"] = e["source"] or src["source"]
            e["tags"] += [t for t in src["tags"] if t not in e["tags"]]
    return els, rels


def views_of(ws, keep):
    out = []
    for kind in KINDS:
        for v in ws["views"].get(kind + "Views") or []:
            if not keep.fullmatch(v["key"]):
                continue
            elements = [e["id"] for e in v.get("elements") or []]
            relationships = [r["id"] for r in v.get("relationships") or []]
            out.append({
                "key": v["key"],
                "kind": kind,
                "title": v.get("title") or v.get("name") or v["key"],
                # The boundary a container, component or scoped dynamic view draws its elements inside.
                "scopeId": v.get("softwareSystemId") if kind == "container"
                else v.get("containerId") if kind == "component"
                else v.get("elementId") if kind == "dynamic" else None,
                "elementIds": elements,
                "relationshipIds": relationships,
                # Counted apart from the ID lists the page draws from: see viewer-core.js.
                "expectedElements": len(v.get("elements") or []),
                "expectedRelationships": len(v.get("relationships") or []),
            })
    return out


def styles_of(ws):
    st = (ws["views"].get("configuration") or {}).get("styles") or {}
    keys = ("stroke", "color", "background", "strokeWidth", "shape", "icon")
    return {e["tag"]: {k: e[k] for k in keys if e.get(k) is not None} for e in st.get("elements") or []}


def dataset(label, path, keep):
    ws = json.loads(Path(path).read_text())
    model, views = ws.get("model") or {}, ws.get("views") or {}
    els, rels = walk_model(model)
    if not els:
        sys.exit(f"build-viewer: {label}: {path} has no elements in its model; is it a Structurizr JSON export?")
    ws["views"] = views
    skipped = [f"{len(views[k])} {k}" for k in UNSUPPORTED if views.get(k)]
    if skipped:
        print(f"build-viewer: {label}: not shown (unsupported view kinds): {', '.join(skipped)}", file=sys.stderr)
    vs = views_of(ws, keep)
    if not vs:
        sys.exit(f"build-viewer: {label}: no views in {path} match {keep.pattern!r}; refusing to build an empty viewer")
    return {"label": label, "name": ws.get("name") or "", "elements": els, "relationships": rels,
            "views": vs, "styles": styles_of(ws)}


def pair(s, what):
    label, sep, value = s.partition("=")
    if not sep or not label or not value:
        sys.exit(f"build-viewer: expected LABEL={what}, got {s!r}")
    return label, value


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("exports", nargs="+", metavar="LABEL=EXPORT.json")
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--title", default="")
    ap.add_argument("--views", action="append", default=[], metavar="LABEL=REGEX")
    a = ap.parse_args()

    exports = [pair(s, "EXPORT.json") for s in a.exports]
    labels = [label for label, _ in exports]
    if len(set(labels)) != len(labels):
        sys.exit(f"build-viewer: labels must be distinct: {labels}")
    filters = dict(pair(s, "REGEX") for s in a.views)
    unknown = set(filters) - set(labels)
    if unknown:
        sys.exit(f"build-viewer: --views names labels with no export: {sorted(unknown)}")
    model = {"title": a.title, "datasets": [
        dataset(label, path, re.compile(filters.get(label, ".*"))) for label, path in exports]}

    # The output directory belongs to the viewer: it is replaced whole, so a file a later version
    # drops does not linger. Refuse to replace a directory that is not a viewer.
    out = a.out
    if out.exists() and not (out / "model.js").is_file():
        sys.exit(f"build-viewer: {out} exists and is not a viewer (no model.js); refusing to replace it")
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=out.parent) as tmp:
        staged = Path(tmp) / "viewer"
        shutil.copytree(VIEWER, staged)
        blob = json.dumps(model, indent=1, ensure_ascii=False)
        (staged / "model.js").write_text(
            "// Generated by build-viewer.py from Structurizr JSON exports. Do not edit.\n"
            f"window.C4_VIEWER_MODEL = {blob};\n")
        if out.exists():
            shutil.rmtree(out)
        staged.rename(out)

    for d in model["datasets"]:
        print(f"{d['label']}: " + ", ".join(
            f"{v['key']} ({v['expectedElements']} elements, {v['expectedRelationships']} relationships)" for v in d["views"]))


if __name__ == "__main__":
    main()
