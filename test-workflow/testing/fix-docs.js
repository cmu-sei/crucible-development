#!/usr/bin/env node
// Bookkeeping fixes for the workspace test docs, so no agent run is spent on them (orchestration/RULES.md,
// Process). Plain Node, no dependencies; reads the worktrees with read-only git, writes only under
// agent-docs/{api,ui}-test-bugs. Idempotent: a second run changes nothing.
//
//   node fix-docs.js [--write] [--app <app>]... [--worktrees <dir>]
//
//   --write      apply the changes (without it, print what would change)
//   --app        only these apps (default: every app with a defect document or an accounting file)
//   --worktrees  where the worktrees are (default /mnt/data/crucible/.worktrees), for the fixes that read a
//                repo: following a rename, expanding a renamed-in-place appendix
//
// Defect documents (agent-docs/{api,ui}-test-bugs/<app>.md; format in testing/README.md):
//   - `Test: `<file>:<line>`` and the UI's `Spec: `<file>:<line>`` become `Test: `<file>` `<test name>``
//     (the name from the entry's heading; a UI typing note keeps the file only);
//   - an entry whose test no longer exists, where the app's accounting has an A line from that name to one
//     test that does, follows the rename (heading and Test: line);
//   - UI: `## Found without a spec` and `## API gaps noticed` become `## Found without a test` and
//     `## Gaps noticed`; an entry under a spec section whose description starts "Needs a decision." moves
//     to `## Needs a decision`;
//   - API: the intro's "N entries." and the summary table's Entries, Cross-repo, Latent and Recipe rows are
//     recounted from the entries.
// Removed-test accountings (agent-docs/{api,ui}-test-bugs/<app>.removed-tests-<date>.md; same README):
//   - a rename map (`` `Old` -> `New`; ``, the vm.api addendum) becomes A lines;
//   - an "Appendix: renamed-in-place methods" whose writer claimed every rename that kept its [Fact] line
//     (blueprint.api, 2026-10-08) is expanded into A lines for the removals it covers: the old signature and
//     the new one at the same place in the same diff hunk;
//   - `-> D <reason>` becomes `-> D -> <reason>`;
//   - UI: a B line naming "`it.each` (first case) in `X`" names that it.each's title; "into the same test"
//     names the previous row's test.
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

// The workspace docs (defect docs, allow-lists, test-work/): on the /mnt/data volume, never in the checkout
// this script runs from. CRUCIBLE_ROOT overrides /mnt/data/crucible.
const DOCS = path.join(process.env.CRUCIBLE_ROOT || '/mnt/data/crucible', 'agent-docs');
const argv = process.argv.slice(2);
const opts = { write: false, apps: [], worktrees: '/mnt/data/crucible/.worktrees' };
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--write') opts.write = true;
  else if (a === '--app') opts.apps.push(argv[++i]);
  else if (a.startsWith('--app=')) opts.apps.push(a.slice(6));
  else if (a === '--worktrees') opts.worktrees = argv[++i];
  else if (a === '-h' || a === '--help') { console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(1, 33).join('\n')); process.exit(0); }
  else { console.error(`fix-docs.js: unknown argument ${a}`); process.exit(2); }
}

const read = (f) => fs.readFileSync(f, 'utf8');
const span = (s) => (s.includes('`') ? `\`\` ${s} \`\`` : `\`${s}\``);
const changes = [];
const save = (file, before, after, what) => {
  if (before === after) return;
  changes.push(`${path.relative(DOCS, file)}: ${what.join('; ')}`);
  if (opts.write) fs.writeFileSync(file, after);
};
const worktree = (app) => {
  const w = path.join(opts.worktrees, app);
  return fs.existsSync(path.join(w, '.git')) ? w : null;
};
const git = (w, ...a) => execFileSync('git', ['-C', w, ...a], { encoding: 'utf8', maxBuffer: 1 << 28, stdio: ['ignore', 'pipe', 'ignore'] });

function appsOf(stack) {
  const dir = path.join(DOCS, `${stack}-test-bugs`);
  const out = new Set();
  for (const f of fs.readdirSync(dir)) {
    const m = /^([a-z]+\.(?:api|ui))\.(?:md|removed-tests.*\.md)$/.exec(f);
    if (m) out.add(m[1]);
  }
  return [...out].filter((a) => !opts.apps.length || opts.apps.includes(a)).sort();
}

// A lines of the app's accounting files: old name -> new name (the first test named after the letter).
function renames(stack, app) {
  const dir = path.join(DOCS, `${stack}-test-bugs`);
  const map = new Map();
  for (const f of fs.readdirSync(dir).filter((n) => n.startsWith(`${app}.removed-tests`) && n.endsWith('.md'))) {
    for (const line of read(path.join(dir, f)).split('\n')) {
      const m = /`([^`]+)`[^`]*?->\s*\**A\**\s*->\s*(?:[^`]*?)`([^`]+)`/.exec(line);
      if (!m) continue;
      const last = (s) => s.trim().split(' > ').pop().replace(/^.*\./, (x) => (stack === 'api' ? '' : x));
      map.set(stack === 'api' ? m[1].replace(/^.*\./, '') : m[1], stack === 'api' ? m[2].replace(/^.*[ /]/, '').replace(/^.*\./, '') : last(m[2]));
    }
  }
  return map;
}

// Does the test file hold a test of this name? A text search: the check-repo.js `defects` and `specs` modes
// are the real check.
function hasTest(stack, w, file, name) {
  const abs = path.join(w, file);
  if (!fs.existsSync(abs)) return false;
  const text = read(abs);
  if (stack === 'api') return new RegExp(`\\b${name.replace(/\W/g, '\\$&')}\\s*\\(`).test(text);
  return [`'${name}'`, `"${name}"`, `\`${name}\``].some((q) => text.includes(q)) || text.includes(`'${name.replace(/'/g, "\\'")}'`);
}

function fixDefectDoc(stack, app) {
  const file = path.join(DOCS, `${stack}-test-bugs`, `${app}.md`);
  if (!fs.existsSync(file)) return;
  const before = read(file);
  const what = [];
  let lines = before.split('\n');
  const w = worktree(app);
  const ren = renames(stack, app);
  // Sections renamed to the shared names (UI).
  if (stack === 'ui') {
    const map = { 'Found without a spec': 'Found without a test', 'API gaps noticed': 'Gaps noticed' };
    lines = lines.map((l) => {
      const m = /^## (.+?)\s*$/.exec(l);
      if (m && map[m[1]]) { what.push(`'## ${m[1]}' -> '## ${map[m[1]]}'`); return `## ${map[m[1]]}`; }
      return l;
    });
  }
  // Test: lines.
  let section = null;
  let heading = null;
  let converted = 0;
  let followed = 0;
  for (let i = 0; i < lines.length; i++) {
    const h2 = /^## (.+?)\s*$/.exec(lines[i]);
    if (h2) { section = h2[1]; heading = null; continue; }
    const h3 = /^### (.+?)\s*$/.exec(lines[i]);
    if (h3) { heading = { name: h3[1], line: i }; continue; }
    const t = /^(Test|Spec):\s*`([^`]+?):(\d+)(?:-\d+)?`(.*)$/.exec(lines[i]);
    if (!t || !heading) continue;
    const [, , testFile, , rest] = t;
    const typing = /^\(typing note on /.test(heading.name);
    let name = heading.name;
    if (!typing && w && !hasTest(stack, w, testFile, name) && ren.has(name) && hasTest(stack, w, testFile, ren.get(name))) {
      name = ren.get(name);
      lines[heading.line] = `### ${name}`;
      followed++;
    }
    lines[i] = `Test: ${span(testFile)}${typing ? '' : ` ${span(name)}`}${rest}`;
    converted++;
  }
  if (converted) what.push(`${converted} Test: lines name the test instead of a line`);
  if (followed) what.push(`${followed} entries follow a rename`);
  // UI: an entry whose description starts "Needs a decision." moves to ## Needs a decision.
  if (stack === 'ui') {
    const blocks = [];
    let sec = null;
    for (let i = 0; i < lines.length; i++) {
      const h2 = /^## (.+?)\s*$/.exec(lines[i]);
      if (h2) { sec = h2[1]; continue; }
      if (!/^### /.test(lines[i]) || !/\.spec\.ts$/.test(sec || '')) continue;
      let end = i + 1;
      while (end < lines.length && !/^##+ /.test(lines[end])) end++;
      const body = lines.slice(i + 1, end);
      const first = body.find((l) => l.trim() && !/^Test:/.test(l));
      if (first && /^\**Needs a decision\.?\**/.test(first.trim())) blocks.push([i, end]);
    }
    if (blocks.length) {
      const moved = [];
      for (const [a, b] of [...blocks].reverse()) moved.unshift(...lines.splice(a, b - a));
      let at = lines.findIndex((l) => /^## Needs a decision\s*$/.test(l));
      if (at < 0) {
        at = lines.findIndex((l) => /^## (Found without a test|Gaps noticed)\s*$/.test(l));
        if (at < 0) at = lines.length;
        lines.splice(at, 0, '## Needs a decision', '');
        at += 2;
      } else {
        at++;
        while (at < lines.length && !/^## /.test(lines[at])) at++;
      }
      lines.splice(at, 0, ...moved);
      what.push(`${blocks.length} "Needs a decision." entries moved to ## Needs a decision`);
    }
  }
  // API: recount the intro and the summary table.
  if (stack === 'api') {
    const entries = [];
    let sec2 = null;
    let cur = null;
    for (const l of lines) {
      const h2 = /^## (.+?)\s*$/.exec(l);
      if (h2) { sec2 = h2[1]; cur = null; continue; }
      const h3 = /^### (.+?)\s*$/.exec(l);
      if (h3) { cur = /\.cs$/.test(sec2 || '') ? { text: '' } : null; if (cur) entries.push(cur); continue; }
      if (cur) cur.text += `${l}\n`;
    }
    const cross = entries.filter((e) => /^\*\*Fix:\*\*\s*Cross-repo;/m.test(e.text)).length;
    const latent = entries.filter((e) => /\(latent: (?:no caller|unreachable input)\)/.test(e.text)).length;
    const recipes = new Map();
    for (const e of entries) {
      const fix = e.text.indexOf('**Fix:**');
      if (fix < 0) continue;
      const flip = e.text.indexOf('**Test to flip:**');
      for (const r of new Set([...e.text.slice(fix, flip > fix ? flip : undefined).matchAll(/\bRecipe ([A-Z])\b/g)].map((x) => x[1]))) recipes.set(r, (recipes.get(r) || 0) + 1);
    }
    const recount = (l) => {
      const m = /^(\|\s*([^|]+?)\s*\|\s*)(\d+)(\s*\|.*)$/.exec(l);
      if (!m) return l;
      const label = m[2];
      const want = /^Entries$/.test(label) ? entries.length : /^Cross-repo entries\b/.test(label) ? cross : /^Latent entries\b/.test(label) ? latent
        : /^Recipe ([A-Z])\b/.test(label) ? recipes.get(/^Recipe ([A-Z])\b/.exec(label)[1]) || 0 : null;
      if (want === null || want === Number(m[3])) return l;
      what.push(`summary '${label}' ${m[3]} -> ${want}`);
      return `${m[1]}${want}${m[4]}`;
    };
    lines = lines.map((l) => {
      const intro = /^(.*\b)(\d+)( entr(?:y|ies)\.\s*)$/.exec(l);
      if (intro && !/^\|/.test(l) && Number(intro[2]) !== entries.length) {
        what.push(`intro ${intro[2]} -> ${entries.length} entries`);
        return `${intro[1]}${entries.length} ${entries.length === 1 ? 'entry.' : 'entries.'}`;
      }
      return recount(l);
    });
  }
  save(file, before, lines.join('\n'), what);
}

// The removals `check-repo.js removed` reports unaccounted in an API worktree, each paired with the method
// whose signature replaced its own at the same place in the same hunk of the diff (the attribute line
// kept): [file, Class.Old, New]. A removal with no such partner is left for judgement.
function inPlacePairs(w, app) {
  const check = path.join(__dirname, '..', 'api-testing', 'check-repo.js');
  let out = '';
  try { out = execFileSync('node', [check, 'removed', w, app, '--no-write'], { encoding: 'utf8', maxBuffer: 1 << 28 }); } catch (e) { out = e.stdout || ''; }
  const base = git(w, 'merge-base', 'HEAD', 'origin/main').trim();
  const renamedTo = new Map();
  for (const l of git(w, 'diff', '-M', '--name-status', base).split('\n')) {
    const r = /^R\d*\t(.+)\t(.+)$/.exec(l);
    if (r) renamedTo.set(r[1], r[2]);
  }
  const hunksOf = new Map();
  const pairs = [];
  const unpaired = [];
  for (const l of out.split('\n')) {
    const m = /^  REMOVED  (\S+?):\d+ (\w+)\.(\w+) has no line/.exec(l);
    if (!m) continue;
    const [, file, cls, old] = m;
    if (!hunksOf.has(file)) hunksOf.set(file, git(w, 'diff', '-M', '-U0', base, '--', file, renamedTo.get(file) || file).split(/\n(?=@@ )/));
    for (const hunk of hunksOf.get(file)) {
      const minus = [...hunk.matchAll(/^-\s*public\s+(?:async\s+)?\S+\s+(\w+)\s*\(/gm)].map((x) => x[1]);
      const plus = [...hunk.matchAll(/^\+\s*public\s+(?:async\s+)?\S+\s+(\w+)\s*\(/gm)].map((x) => x[1]);
      const k = minus.indexOf(old);
      if (k >= 0 && minus.length === plus.length) { pairs.push([file, `${cls}.${old}`, plus[k]]); break; }
    }
    if (!pairs.some((p) => p[1] === `${cls}.${old}`)) unpaired.push([file, cls, old]);
  }
  return { pairs, unpaired };
}

// The appendix's table, `| Old name (file) | Kept half | Dropped half now asserted by |`: old names with
// `{A,B}` groups and class lists (`A` / `B.Name`), each paired with the successor the row names (the
// dropped half's test, or the kept half when nothing was dropped), where that test exists.
function appendixTable(lines, w) {
  const out = new Map();
  const expand = (s) => {
    const b = /^(.*)\{([^{}]+)\}(.*)$/.exec(s);
    return b ? b[2].split(',').map((v) => `${b[1]}${v.trim()}${b[3]}`) : [s];
  };
  const exists = (name) => { try { execFileSync('git', ['-C', w, 'grep', '-qE', `\\b${name}\\s*\\(`, '--', '*.cs'], { stdio: 'ignore' }); return true; } catch { return false; } };
  let inTable = false;
  for (const l of lines) {
    if (/^\|\s*Old name/.test(l)) { inTable = true; continue; }
    if (!/^\|/.test(l)) { inTable = false; continue; }
    if (!inTable || /^\|\s*-/.test(l)) continue;
    const cells = l.split('|').slice(1, -1).map((c) => c.trim());
    const spans = (c) => [...(c || '').matchAll(/`([^`]+)`/g)].map((m) => m[1]);
    const olds = [];
    let classes = [];
    for (const s of spans(cells[0])) {
      if (!s.includes('.')) { classes.push(s); continue; }
      const [cls, rest] = [s.slice(0, s.indexOf('.')), s.slice(s.indexOf('.') + 1)];
      for (const c of [...classes, cls]) expand(rest).forEach((n, i) => olds.push({ cls: c, name: n, i }));
      classes = [];
    }
    const succ = (c) => spans(c).flatMap((s) => expand(s.replace(/^.*[/.](?=\w+$)/, ''))).filter((n) => /^\w+$/.test(n) && exists(n));
    const dropped = succ(cells[2]);
    const kept = succ(cells[1]);
    for (const o of olds) {
      const to = dropped.length > 1 ? dropped[o.i] : dropped[0] || (kept.length > 1 ? kept[o.i] : kept[0]);
      if (to) out.set(`${o.cls}.${o.name}`, to);
    }
  }
  return out;
}

function fixAccounting(stack, app) {
  const dir = path.join(DOCS, `${stack}-test-bugs`);
  const w = worktree(app);
  for (const f of fs.readdirSync(dir).filter((n) => n.startsWith(`${app}.removed-tests`) && n.endsWith('.md') && !n.endsWith('.removed-tests-matched.md')).sort()) {
    const file = path.join(dir, f);
    const before = read(file);
    const what = [];
    let lines = before.split('\n');
    // A rename map: `Old` -> `New`; (no letter) under a "renamed in place" heading.
    let inMap = false;
    let mapped = 0;
    lines = lines.map((l) => {
      if (/^#+ /.test(l)) inMap = /renamed in place/i.test(l) && !/appendix/i.test(l);
      const m = /^`(\w+)`\s*->\s*`(\w+)`[;.]?\s*$/.exec(l);
      if (inMap && m) { mapped++; return `- \`${m[1]}\` -> A -> \`${m[2]}\` (renamed in place)`; }
      return l;
    });
    if (mapped) what.push(`${mapped} rename-map lines -> A lines`);
    // D lines without the second arrow.
    let dfix = 0;
    lines = lines.map((l) => {
      const m = /^(\s*-\s+`[^`]+`.*?->\s*\**D\**)\s+(?!->)(\S.*)$/.exec(l);
      if (m) { dfix++; return `${m[1]} -> ${m[2]}`; }
      return l;
    });
    if (dfix) what.push(`${dfix} D lines take the -> D -> form`);
    // UI: B lines that name an it.each by its position, or "the same test".
    if (stack === 'ui' && w) {
      let named = 0;
      let lastTarget = null;
      lines = lines.map((l) => {
        let out = l;
        const m = /`it\.each`\s*\(first case\)\s*in\s*`(\w+)`/.exec(l);
        if (m) {
          const title = firstEachTitle(w, m[1]);
          if (title) { out = l.replace(m[0], `${span(title)} (the first case of its it.each, in \`${m[1]}\`)`); named++; }
        }
        if (/\*\*B\*\*\s*into the same test/.test(out) && lastTarget) {
          out = out.replace(/into the same test/, `into ${lastTarget}`);
          named++;
        }
        const t = /\*\*[ABC]\*\*\s*(?:->|into)\s*(`[^`]+`(?:\s*`[^`]+`)?)/.exec(out);
        if (t) lastTarget = t[1];
        return out;
      });
      if (named) what.push(`${named} B lines name their test`);
    }
    // API: a renamed-in-place appendix that claims every rename keeping its [Fact] line.
    if (stack === 'api' && w && lines.some((l) => /^##\s+Appendix: renamed-in-place methods/i.test(l)) && !lines.some((l) => /^## Renamed in place, expanded/.test(l))) {
      const { pairs: add, unpaired } = inPlacePairs(w, app);
      const table = appendixTable(lines, w);
      for (const [file, cls, old] of unpaired) {
        const to = table.get(`${cls}.${old}`);
        if (to) add.push([file, `${cls}.${old}`, to, 'named in the appendix table']);
      }
      if (add.length) {
        const byFile = new Map();
        for (const [f, o, n, why] of add) byFile.set(f, [...(byFile.get(f) || []), `- \`${o}\` -> A -> \`${n}\` (${why || 'renamed in place'})`]);
        lines.push('', '## Renamed in place, expanded from the appendix (testing/fix-docs.js, 2026-10-12)', '',
          'The appendix above accounts for every method the diff renamed without touching its `[Fact]`/`[Theory]` line. These lines name each one: the old signature and the new one at the same place in the same hunk of `git diff -M -U0` against the merge base with origin/main, or, where the hunks do not pair them, the successor the appendix table names.', '',
          ...[...byFile].flatMap(([f, ls]) => [`### \`${f}\``, '', ...ls, '']));
        what.push(`${add.length} renamed-in-place lines expanded from the appendix`);
      }
    }
    save(file, before, lines.join('\n'), what);
  }
}

// The title of the first it.each in the spec of a component class.
function firstEachTitle(w, cls) {
  const files = execFileSync('grep', ['-rlE', `export class ${cls}\\b`, path.join(w, 'src/app'), '--include=*.ts'], { encoding: 'utf8' }).split('\n').filter((f) => f && !f.endsWith('.spec.ts'));
  for (const f of files) {
    const spec = f.replace(/\.ts$/, '.spec.ts');
    if (!fs.existsSync(spec)) continue;
    const m = /\bit\.each\s*\([\s\S]*?\)\s*\(\s*(['"`])((?:(?!\1)[^\\]|\\.)*)\1/.exec(read(spec));
    if (m) return m[2];
  }
  return null;
}


for (const stack of ['api', 'ui']) {
  for (const app of appsOf(stack)) {
    fixAccounting(stack, app); // accounting first: the defect fixes follow its A lines
    fixDefectDoc(stack, app);
  }
}
for (const c of changes) console.log(`${opts.write ? 'changed' : 'would change'}  ${c}`);
console.log(`${changes.length} file(s) ${opts.write ? 'changed' : 'to change'}${opts.write ? '' : ' (pass --write to apply)'}`);
