#!/usr/bin/env node
// Removes unused imports from a UI repo's specs and test-utils, the bookkeeping fix behind verify.sh's
// "unused imports or locals" NOTE (orchestration/RULES.md, Process). Uses the repo's own TypeScript and
// tsconfig.spec.json with noUnusedLocals. Only import specifiers and whole import declarations are removed;
// an unused local is listed for the writer, never touched, and side-effect imports (`import 'x';`) are
// never unused. Shared helpers under src/app/test-utils are left alone (they are synced from the standard).
//
//   node fix-unused-imports.js [--write] <repo>
//
// Without --write it prints what it would remove.
'use strict';
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const write = args.includes('--write');
const repoArg = args.find((a) => !a.startsWith('--'));
if (!repoArg) { console.error('usage: fix-unused-imports.js [--write] <repo>'); process.exit(2); }
const repo = path.resolve(repoArg);
let ts;
try { ts = require(path.join(repo, 'node_modules/typescript')); } catch { console.error('no node_modules/typescript in the repo (npm ci first)'); process.exit(1); }
const SHARED = new Set(['render-component', 'unstubbed', 'api-stub', 'record-emissions', 'unhandled-rx-errors', 'fake-hub-connection', 'activated-route', 'dialog-refs', 'file-list']
  .map((n) => path.join(repo, 'src/app/test-utils', `${n}.ts`)));
const configFile = path.join(repo, 'tsconfig.spec.json');
const config = ts.readConfigFile(configFile, ts.sys.readFile);
const parsed = ts.parseJsonConfigFileContent(config.config, ts.sys, repo, { noUnusedLocals: true, noEmit: true }, configFile);
const program = ts.createProgram(parsed.fileNames, parsed.options);
const UNUSED = new Set([6133, 6138, 6192, 6196, 6198]);
const ours = (f) => (/\.spec\.ts$/.test(f) || f.includes(`${path.sep}src${path.sep}app${path.sep}test-utils${path.sep}`)) && !SHARED.has(f);
const byFile = new Map();
for (const d of program.getSemanticDiagnostics()) {
  if (!d.file || !UNUSED.has(d.code) || !ours(path.resolve(d.file.fileName))) continue;
  if (!byFile.has(d.file)) byFile.set(d.file, []);
  byFile.get(d.file).push(d);
}
let removed = 0;
const left = [];
for (const [sf, diags] of byFile) {
  const rel = path.relative(repo, sf.fileName);
  const cuts = []; // [from, to]
  const whole = new Set();
  const dropSpec = new Map(); // ImportDeclaration -> Set(ImportSpecifier | 'default')
  for (const d of diags) {
    let n = findNode(sf, d.start);
    while (n && !ts.isImportDeclaration(n) && !ts.isImportSpecifier(n) && !ts.isImportClause(n) && !ts.isSourceFile(n)) n = n.parent;
    if (!n || ts.isSourceFile(n)) {
      const { line } = sf.getLineAndCharacterOfPosition(d.start);
      left.push(`${rel}:${line + 1} ${ts.flattenDiagnosticMessageText(d.messageText, ' ')}`);
      continue;
    }
    if (ts.isImportDeclaration(n)) whole.add(n);
    else if (ts.isImportSpecifier(n)) {
      const decl = n.parent.parent.parent;
      if (!dropSpec.has(decl)) dropSpec.set(decl, new Set());
      dropSpec.get(decl).add(n);
    } else if (ts.isImportClause(n)) {
      const decl = n.parent;
      if (!dropSpec.has(decl)) dropSpec.set(decl, new Set());
      dropSpec.get(decl).add('default');
    }
  }
  for (const [decl, drop] of dropSpec) {
    if (whole.has(decl)) continue;
    const clause = decl.importClause;
    const named = clause.namedBindings && ts.isNamedImports(clause.namedBindings) ? clause.namedBindings.elements : [];
    const keepDefault = clause.name && !drop.has('default');
    const keep = named.filter((e) => !drop.has(e));
    if (!keepDefault && !keep.length) { whole.add(decl); continue; }
    const text = sf.text;
    const head = text.slice(decl.getStart(sf), clause.getStart(sf));
    const tail = text.slice(clause.getEnd(), decl.getEnd());
    const parts = [];
    if (keepDefault) parts.push(clause.name.text);
    if (keep.length) parts.push(`{ ${keep.map((e) => e.getText(sf)).join(', ')} }`);
    cuts.push([decl.getStart(sf), decl.getEnd(), `${head}${parts.join(', ')}${tail}`]);
    removed += drop.size;
  }
  for (const decl of whole) {
    let end = decl.getEnd();
    if (sf.text[end] === '\n') end++;
    cuts.push([decl.getStart(sf), end, '']);
    removed++;
  }
  if (!cuts.length) continue;
  cuts.sort((a, b) => b[0] - a[0]);
  let out = sf.text;
  for (const [from, to, by] of cuts) out = out.slice(0, from) + by + out.slice(to);
  console.log(`${write ? 'fixed' : 'would fix'}  ${rel}: ${cuts.length} import declaration(s)`);
  if (write) fs.writeFileSync(sf.fileName, out);
}
for (const l of left) console.log(`left       ${l} (an unused local: the writer removes or uses it)`);
console.log(`${removed} unused import(s) ${write ? 'removed' : 'to remove'}${left.length ? `; ${left.length} unused local(s) left` : ''}`);

function findNode(sf, pos) {
  let found = sf;
  (function visit(n) {
    if (pos >= n.getStart(sf) && pos < n.getEnd()) { found = n; ts.forEachChild(n, visit); }
  })(sf);
  return found;
}
