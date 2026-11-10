// Collapse, merge and the closing identity, shared by the page (index.html) and the pre-commit
// check (scripts/check-viewer.js), so the check exercises the code the page runs.
//
// A dataset is one workspace export as build-viewer.py flattens it: {elements, relationships,
// views, styles}. A view lists the element and relationship IDs it includes, plus the export's own
// counts of each (expectedElements, expectedRelationships), kept apart from the ID lists so that a
// list which loses an entry anywhere on the way fails the identity.
(function (root) {
  "use strict";

  const C4_FILL = { Person: "#08427b", SoftwareSystem: "#1168bd", Container: "#438dd5", Component: "#85bbf0" };
  const SHAPES = { Cylinder: "barrel", Circle: "ellipse", Ellipse: "ellipse", Hexagon: "hexagon", Diamond: "diamond" };

  function wrap(text, n) {
    const out = [];
    let line = "";
    for (const w of String(text).split(/\s+/)) {
      if (line && (line + " " + w).length > n) { out.push(line); line = w; } else line = line ? line + " " + w : w;
    }
    if (line) out.push(line);
    return out;
  }

  function styleFor(ds, tags) {
    const s = {};
    for (const t of tags) Object.assign(s, ds.styles[t] || {});
    return s;
  }

  // The view's structure: which elements it holds and each one's nearest ancestor in the view. A
  // container or component view draws its scope as a boundary; that box is synthetic and is not
  // counted as an element.
  function viewModel(ds, view) {
    const E = ds.elements;
    const inView = new Set(view.elementIds.filter(id => E[id]));
    const missingElements = view.elementIds.filter(id => !E[id]);
    const synthetic = new Set();
    if (view.scopeId && E[view.scopeId] && !inView.has(view.scopeId)) synthetic.add(view.scopeId);
    const all = new Set([...inView, ...synthetic]);
    const parentOf = {}, children = {};
    for (const id of all) {
      let p = E[id].parentId;
      while (p && !all.has(p)) p = E[p] && E[p].parentId;
      parentOf[id] = p || null;
      if (p) (children[p] = children[p] || []).push(id);
    }
    const descendants = id => (children[id] || []).reduce((n, c) => n + 1 + descendants(c), 0);
    return { all, inView, synthetic, parentOf, children, descendants, missingElements };
  }

  // Everything collapsed, except the view's own boundary (its contents are what the view is for) and
  // a box alone at its level: a single closed box says nothing at a glance (a deployment view often
  // sits inside one region).
  function glance(vm) {
    const expanded = new Set(vm.synthetic);
    let level = [...vm.all].filter(id => !vm.parentOf[id]);
    while (level.length === 1 && (vm.children[level[0]] || []).length) {
      expanded.add(level[0]);
      level = vm.children[level[0]];
    }
    return expanded;
  }

  function allExpanded(vm) {
    return new Set(Object.keys(vm.children));
  }

  // The box an element is drawn as: itself, or its outermost collapsed ancestor.
  function rep(vm, expanded, id) {
    let r = id, p = vm.parentOf[id];
    while (p) { if (!expanded.has(p)) r = p; p = vm.parentOf[p]; }
    return r;
  }

  function nodeData(ds, vm, expanded, id, inner) {
    const e = ds.elements[id];
    const kids = vm.children[id] || [];
    const isOpen = kids.length > 0 && expanded.has(id);
    const st = styleFor(ds, e.tags);
    const lines = [...wrap(e.name, 30)];
    if (e.technology) lines.push(...wrap("[" + e.technology + "]", 34));
    if (kids.length && !isOpen) lines.push("+ " + vm.descendants(id) + " inside");
    // Relationships with both ends inside this collapsed box are carried by a badge on the box: a
    // self-loop edge is not drawable once its ends are the same compound.
    if (inner.length) lines.push("⟲ " + inner.length + " relationship" + (inner.length === 1 ? "" : "s") + " inside");
    const maxLen = Math.max(...lines.map(l => l.length));
    const d = {
      id, label: lines.join("\n"), parent: vm.parentOf[id] || undefined, innerRels: inner,
      w: Math.min(250, Math.max(110, maxLen * 6.4 + 26)), h: lines.length * 14 + 20 + (st.icon ? 26 : 0),
    };
    const external = e.tags.includes("External");
    const fill = st.background || (C4_FILL[e.kind] && !external ? C4_FILL[e.kind] : external ? "#999999" : null);
    if (fill) { d.fill = fill; d.textColor = st.color || (e.kind === "Component" && !st.background ? "#000" : "#fff"); }
    else if (st.color) d.tcolor = st.color;
    if (st.stroke) d.stroke = st.stroke;
    if (st.strokeWidth) d.strokeWidth = st.strokeWidth;
    if (st.shape && SHAPES[st.shape]) d.shape = SHAPES[st.shape];
    if (st.icon && st.icon.startsWith("data:")) d.icon = st.icon;
    const classes = [kids.length && !isOpen ? "collapsedBox" : "", vm.synthetic.has(id) ? "synthetic" : ""];
    return { data: d, classes: classes.filter(Boolean).join(" ") };
  }

  // Cytoscape elements for the view in its current collapse state. Every relationship in the view is
  // drawn: on its own edge, on a merged edge between two boxes, or on a collapsed box's badge.
  // notDrawn lists any that could not be, which the identity then fails on.
  function build(ds, view, vm, expanded) {
    const shown = new Set([...vm.all].filter(id => rep(vm, expanded, id) === id));
    const groups = new Map(), inner = {}, notDrawn = [];
    for (const rid of view.relationshipIds) {
      const r = ds.relationships[rid];
      if (!r || !vm.inView.has(r.sourceId) || !vm.inView.has(r.destinationId)) { notDrawn.push(rid); continue; }
      const s = rep(vm, expanded, r.sourceId), t = rep(vm, expanded, r.destinationId);
      if (s === t) { (inner[s] = inner[s] || []).push(rid); continue; }
      const k = s + "->" + t;
      if (!groups.has(k)) groups.set(k, { s, t, rels: [] });
      groups.get(k).rels.push(rid);
    }
    const nodes = [...shown].map(id => nodeData(ds, vm, expanded, id, inner[id] || []));
    let i = 0;
    const edges = [...groups.values()].map(g => {
      const one = g.rels.length === 1 ? ds.relationships[g.rels[0]] : null;
      const label = one ? one.description + (one.technology ? "\n[" + one.technology + "]" : "")
                        : g.rels.length + " relationships";
      return { data: { id: "e" + (i++), source: g.s, target: g.t, rels: g.rels, label }, classes: one ? "" : "merged" };
    });
    return { nodes, edges, notDrawn };
  }

  function countInside(vm, id) {
    return (vm.children[id] || []).reduce((n, c) => n + (vm.synthetic.has(c) ? 0 : 1) + countInside(vm, c), 0);
  }

  // The closing identity, counted from what Cytoscape actually holds, against the export's counts.
  function identity(cy, view, vm) {
    let individual = 0, mergedEdgeRels = 0, mergedEdges = 0, badgeRels = 0, badges = 0;
    cy.edges().forEach(e => {
      const n = e.data("rels").length;
      if (n === 1) individual++; else { mergedEdgeRels += n; mergedEdges++; }
    });
    cy.nodes().forEach(n => { const k = (n.data("innerRels") || []).length; if (k) { badgeRels += k; badges++; } });
    const merged = mergedEdgeRels + badgeRels;
    let boxes = 0, inside = 0;
    cy.nodes().forEach(n => { if (!n.hasClass("synthetic")) boxes++; });
    cy.nodes(".collapsedBox").forEach(n => { inside += countInside(vm, n.id()); });
    return {
      expectedRelationships: view.expectedRelationships, individual, merged, mergedEdges, mergedEdgeRels, badges, badgeRels,
      expectedElements: view.expectedElements, boxes, inside,
      relationshipsOk: individual + merged === view.expectedRelationships,
      elementsOk: boxes + inside === view.expectedElements,
    };
  }

  const api = { viewModel, glance, allExpanded, rep, build, identity, countInside, wrap, styleFor };
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.C4ViewerCore = api;
})(typeof globalThis !== "undefined" ? globalThis : this);
