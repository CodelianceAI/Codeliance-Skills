#!/usr/bin/env node
// check-viewer.js: check a viewer built by build-viewer.py.
//
// Usage: check-viewer.js <viewer-dir> [<viewer-dir> ...]
//
// Runs the directory's own viewer-core.js in the directory's own Cytoscape, headless, so the check
// exercises the code the page runs. For every view, collapsed as the page first shows it and fully
// expanded, the closing identity must hold: every relationship drawn individually or on a merged
// edge or badge, every element a box or counted inside a collapsed one, against the export's
// counts; fully expanded, the boxes must equal the export's element count.
//
// Then it mutates each view's data (drops one relationship from the model, then one element) and
// requires the identity to fail. A check that cannot see a dropped relationship would pass anything,
// so a mutation that survives fails the check.
//
// Also fails when the directory's index.html, viewer-core.js or vendor/ differ from this plugin's:
// the viewer was built by another version, so rebuild it.
//
// Exit codes: 0 all views hold and every mutation is caught; 1 a check failed; 2 usage error.
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const PLUGIN_VIEWER = path.join(__dirname, "..", "viewer");

function filesUnder(dir, rel = "") {
  return fs.readdirSync(path.join(dir, rel), { withFileTypes: true }).flatMap(d =>
    d.isDirectory() ? filesUnder(dir, path.join(rel, d.name)) : [path.join(rel, d.name)]);
}

function load(dir) {
  const ctx = { console };
  ctx.window = ctx;
  vm.createContext(ctx);
  for (const f of ["vendor/cytoscape.min.js", "viewer-core.js", "model.js"]) {
    vm.runInContext(fs.readFileSync(path.join(dir, f), "utf8"), ctx, { filename: path.join(dir, f) });
  }
  if (typeof ctx.cytoscape !== "function") throw new Error("vendor/cytoscape.min.js did not define cytoscape");
  if (!ctx.C4ViewerCore) throw new Error("viewer-core.js did not define C4ViewerCore");
  if (!ctx.C4_VIEWER_MODEL) throw new Error("model.js did not define C4_VIEWER_MODEL");
  return ctx;
}

// One view in one collapse state: build it, hand it to Cytoscape, count what Cytoscape holds.
function measure(ctx, ds, view, state) {
  const core = ctx.C4ViewerCore;
  const m = core.viewModel(ds, view);
  const expanded = state === "expanded" ? core.allExpanded(m) : core.glance(m);
  const built = core.build(ds, view, m, expanded);
  // Options built inside the context: Cytoscape rejects an object whose Object is another realm's.
  const cy = vm.runInContext("cytoscape({ headless: true, styleEnabled: false })", ctx);
  cy.add(built.nodes);
  cy.add(built.edges);
  const x = core.identity(cy, view, m);
  const problems = [];
  if (!x.relationshipsOk) problems.push(`relationships ${x.individual} + ${x.merged} != ${x.expectedRelationships}`);
  if (!x.elementsOk) problems.push(`elements ${x.boxes} + ${x.inside} != ${x.expectedElements}`);
  if (built.notDrawn.length) problems.push(`not drawn: relationship ${built.notDrawn.join(", ")}`);
  if (m.missingElements.length) problems.push(`missing from the model: element ${m.missingElements.join(", ")}`);
  if (state === "expanded" && x.boxes !== x.expectedElements) problems.push(`expanded boxes ${x.boxes} != ${x.expectedElements}`);
  if (state === "expanded" && x.inside !== 0) problems.push(`expanded yet ${x.inside} inside collapsed boxes`);
  return { x, problems };
}

function checkDir(dir) {
  const failures = [];
  const missing = ["index.html", "viewer-core.js", "model.js", "vendor/cytoscape.min.js"]
    .filter(f => !fs.existsSync(path.join(dir, f)));
  if (missing.length) return [`${dir}: not a viewer (missing ${missing.join(", ")})`];

  const want = filesUnder(PLUGIN_VIEWER).sort();
  const have = filesUnder(dir).filter(f => f !== "model.js").sort();
  const stale = want.filter(f => !have.includes(f) || !fs.readFileSync(path.join(dir, f)).equals(fs.readFileSync(path.join(PLUGIN_VIEWER, f))));
  const extra = have.filter(f => !want.includes(f));
  if (stale.length || extra.length) {
    failures.push(`${dir}: built by a different version of build-viewer.py; rebuild it` +
      (stale.length ? `\n    differs or missing: ${stale.join(", ")}` : "") +
      (extra.length ? `\n    not part of the viewer: ${extra.join(", ")}` : ""));
  }

  let ctx;
  try { ctx = load(dir); } catch (e) { return failures.concat(`${dir}: ${e.message}`); }
  const datasets = ctx.C4_VIEWER_MODEL.datasets || [];
  const views = datasets.flatMap(ds => ds.views.map(v => [ds, v]));
  if (!views.length) return failures.concat(`${dir}: model.js holds no views`);

  let caught = 0, mutations = 0, holding = 0;
  for (const [ds, view] of views) {
    const name = `${ds.label}/${view.key}`;
    const line = [];
    let held = true;
    for (const state of ["collapsed", "expanded"]) {
      const { x, problems } = measure(ctx, ds, view, state);
      line.push(`${state} ${x.boxes} boxes + ${x.inside} inside of ${x.expectedElements} elements, ` +
                `${x.individual} + ${x.merged} merged of ${x.expectedRelationships} relationships`);
      for (const p of problems) failures.push(`${dir}: ${name} (${state}): ${p}`);
      if (problems.length) held = false;
    }
    if (held) holding++;
    console.log(`  ${name}: ${line.join("; ")}`);

    // Mutations: the same view over a copy of the dataset with one relationship, then one element,
    // taken out of the model. Each must fail the identity in both states.
    const drops = [];
    if (view.relationshipIds.length) drops.push(["relationship", view.relationshipIds[0]]);
    if (view.elementIds.length) drops.push(["element", view.elementIds[view.elementIds.length - 1]]);
    for (const [what, id] of drops) {
      const mutated = JSON.parse(JSON.stringify(ds));
      delete mutated[what === "relationship" ? "relationships" : "elements"][id];
      for (const state of ["collapsed", "expanded"]) {
        mutations++;
        // The identity itself must fail, not only the not-drawn or missing report beside it.
        const { x } = measure(ctx, mutated, view, state);
        if (what === "relationship" ? !x.relationshipsOk : !x.elementsOk) caught++;
        else failures.push(`${dir}: ${name} (${state}): self-test: dropping ${what} ${id} still passed the identity`);
      }
    }
  }
  console.log(`  ${holding} of ${views.length} views hold, collapsed and expanded; ` +
              `self-test: ${caught} of ${mutations} mutations caught`);
  if (!mutations) failures.push(`${dir}: self-test ran no mutations`);
  return failures;
}

const dirs = process.argv.slice(2);
if (!dirs.length) {
  console.error("Usage: check-viewer.js <viewer-dir> [<viewer-dir> ...]");
  process.exit(2);
}
let failures = [];
for (const dir of dirs) {
  console.log(`${dir}:`);
  failures = failures.concat(checkDir(dir));
}
for (const f of failures) console.error(`FAIL: ${f}`);
process.exit(failures.length ? 1 : 0);
