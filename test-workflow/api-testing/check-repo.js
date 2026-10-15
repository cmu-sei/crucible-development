#!/usr/bin/env node
// Structural checks of one Crucible API repo against the test standard, run by sync.sh (harness) and
// verify.sh (tests, defects, gates, removed). Plain Node, no dependencies.
//
//   node check-repo.js harness <repo> [<test.csproj relative to repo>]
//       pinned test packages, test project settings, template-derived files, the run-wide factory
//   node check-repo.js tests <repo> [<test.csproj relative to repo>]
//       defect notes in test comments, skipped tests, EF InMemory or SQLite in tests, an inline
//       NewContext() read (never disposed), harness self-tests; NOTE lines for the reviewer: a denial
//       asserted for an actor seeded with no grant (unless the actor's id goes into a seeded row or the
//       method carries a `// Data-row gate: ...` comment), a dynamic skip, prose that reads like a defect note
//   node check-repo.js defects <repo> [<app>] [<test.csproj relative to repo>]
//       agent-docs/api-test-bugs/<app>.md against the tests it names (testing/README.md, "Defect documents"):
//       each entry's test exists by file and test name (NOTE when not), and a test an entry names keeps at
//       most a one-line summary (a failure: no defect text in code); the document's own format, its counts
//       and the `// Same case as ...` comments are NOTE lines; <app> defaults to the repo directory's name
//   node check-repo.js gates <repo> [<app>] [<test.csproj relative to repo>] [--covered]
//       every authorization call site in the application (CONVENTIONS.md section 4, "The gates check")
//       against the tests: an allowed case that is not Root holding the gate's permission, and a near-miss
//       denied case; agent-docs/api-test-gaps/<app>.txt lists, with a reason, what the harness cannot
//       reach (<app> as for defects; an in-repo <Tests>/untested-gates.txt fails). `GATE missing:` lines
//       fail; `WARN provisional:` lines are gates a check tightened in this standard version (GLOSSARY.md);
//       --covered also prints the tests credited for each covered gate, LISTED lines for allow-listed
//       gates the check credits anyway, and the near miss per tier of a two-tier call site
//   node check-repo.js removed <repo> [<app>] [<test.csproj>] [--base <ref>] [--no-write] [--d-lines]
//       every [Fact]/[Theory] method and [InlineData] row the merge base with <ref> (origin/main) had and
//       the tree has not, against the removed-test accounting (testing/README.md): the removals it matches
//       mechanically (moved, renamed with an identical body, theory rows merged into an identical theory) it
//       accounts itself, and without --base writes them to
//       agent-docs/api-test-bugs/<app>.removed-tests-matched.md (unless --no-write); every other removal
//       needs a valid line in agent-docs/api-test-bugs/<app>.removed-tests-<date>.md, or it fails;
//       --d-lines prints the D line that accounts for each dropped test (deliver.sh quotes them)
//
// Prints one line per problem and exits 1 if there are any. WARN lines (provisional gates) and NOTE lines
// (bookkeeping and reviewer input) are printed after them; NOTE lines never change the exit code, WARN
// lines only with --strict.
'use strict';
// The standard version this script belongs to (testing/CHANGELOG.md). A check tightened in this version
// marks what it newly refuses as provisional (GLOSSARY.md); what an earlier version marked is missing now.
const STANDARD_VERSION = '2026-10-12';
// The version whose gates-check tightenings are provisional (warn) now. 2026-10-12 tightened nothing in
// the gates check, so the 2026-10-09 markers are missing gates.
const PROVISIONAL_SINCE = '2026-10-09';
const fs = require('fs');
const path = require('path');

const APPS = ['alloy.api', 'blueprint.api', 'caster.api', 'cite.api', 'gallery.api', 'steamfitter.api', 'player.api', 'vm.api'];
const [mode, repoArg, ...argv] = process.argv.slice(2);
// `--app <app>` and `--base <ref>` (or `--app=`, `--base=`) take a value; other `--` arguments are flags.
const args = [];
let baseArg = null;
let appFlag = null;
for (let k = 0; k < argv.length; k++) {
  const a = argv[k];
  const v = /^--(app|base)(?:=(.*))?$/.exec(a);
  if (!v) { args.push(a); continue; }
  const value = v[2] !== undefined ? v[2] : argv[++k];
  if (v[1] === 'app') appFlag = value; else baseArg = value;
}
const flags = args.filter((a) => a.startsWith('--'));
const rest = args.filter((a) => !a.startsWith('--'));
if (!['harness', 'tests', 'defects', 'gates', 'removed'].includes(mode) || !repoArg) {
  console.error('usage: check-repo.js harness|tests <repo> [<test.csproj>]\n       check-repo.js defects|gates <repo> [<app>] [<test.csproj>] [--covered] [--strict]\n       check-repo.js removed <repo> [<app>] [<test.csproj>] [--base <ref>] [--no-write]\n  <test.csproj> is relative to <repo> or absolute; <app> may also be given as --app <app>');
  process.exit(2);
}
const projArg = rest.find((a) => a.endsWith('.csproj'));
const appArg = appFlag || rest.find((a) => !a.endsWith('.csproj'));
// --strict: WARN lines (provisional gates) fail too. NOTE lines never do.
const strict = flags.includes('--strict');
const repo = path.resolve(repoArg);
const standard = __dirname;
// The workspace docs (defect docs, allow-lists, test-work/): on the /mnt/data volume, never in the checkout
// this script runs from. CRUCIBLE_ROOT overrides /mnt/data/crucible.
const AGENT_DOCS = path.join(process.env.CRUCIBLE_ROOT || '/mnt/data/crucible', 'agent-docs');
const problems = [];
const warnings = [];
// NOTE lines: bookkeeping and reviewer input, which never block (orchestration/RULES.md, Process).
const notes = [];
const read = (f) => fs.readFileSync(f, 'utf8');
const rel = (f) => path.relative(repo, f);
const files = (dir, keep, out = []) => {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (!['bin', 'obj', 'node_modules', '.git', '.worktrees', 'TestResults'].includes(e.name)) files(p, keep, out);
    } else if (keep(p)) out.push(p);
  }
  return out;
};

let proj = projArg && path.resolve(repo, projArg);
if (!proj) {
  const found = files(repo, (p) => p.endsWith('.Tests.csproj'));
  if (found.length !== 1) {
    console.log(`  MISSING  exactly one *.Tests.csproj (found ${found.length})`);
    process.exit(1);
  }
  proj = found[0];
}
const testDir = path.dirname(proj);
const csproj = read(proj);
const sources = files(testDir, (p) => p.endsWith('.cs'));
const shared = path.join(testDir, 'Support', 'Shared') + path.sep;

// Pinned packages test-packages.props marks Optional="true": checked for their version only where referenced.
const optionalPackages = new Set();

// Attribute value of an element like <PackageReference Include="X" Version="1" /> or <PackageVersion ...>.
function items(xml, tag) {
  const out = new Map();
  const re = new RegExp(`<${tag}\\b([^>]*?)(/>|>([\\s\\S]*?)</${tag}>)`, 'g');
  for (const m of xml.matchAll(re)) {
    const attrs = m[1];
    const include = /\bInclude="([^"]+)"/.exec(attrs);
    if (!include) continue;
    const version = /\bVersion="([^"]+)"/.exec(attrs) || (m[3] && /<Version>([^<]+)<\/Version>/.exec(m[3]));
    out.set(include[1], version ? version[1] : null);
    if (/\bOptional="true"/i.test(attrs)) optionalPackages.add(include[1]);
  }
  return out;
}

function checkHarness() {
  // Pinned packages: Directory.Packages.props when the repo uses central package management, the test
  // project otherwise.
  const pinned = items(read(path.join(standard, 'test-packages.props')), 'PackageVersion');
  const refs = items(csproj, 'PackageReference');
  const cpmFile = path.join(repo, 'Directory.Packages.props');
  const cpm = fs.existsSync(cpmFile) ? items(read(cpmFile), 'PackageVersion') : null;
  for (const [name, version] of pinned) {
    if (!refs.has(name)) {
      if (!optionalPackages.has(name)) problems.push(`  MISSING  ${rel(proj)} has no PackageReference to ${name}`);
      continue;
    }
    const have = cpm ? cpm.get(name) : refs.get(name);
    const where = cpm ? 'Directory.Packages.props' : rel(proj);
    if (have !== version) {
      problems.push(`  DRIFT    ${where}: ${name} is ${have ?? 'unversioned'}, the standard pins ${version}`);
    }
  }
  for (const banned of ['xunit', 'xunit.abstractions', 'xunit.extensibility.core', 'Microsoft.EntityFrameworkCore.InMemory', 'Microsoft.EntityFrameworkCore.Sqlite', 'Microsoft.Data.Sqlite']) {
    if (refs.has(banned)) {
      problems.push(`  STALE    ${rel(proj)} references ${banned} (xUnit v3 and the PostgreSQL harness replace it)`);
    }
  }
  const settings = [
    [/<OutputType>\s*Exe\s*<\/OutputType>/, '<OutputType>Exe</OutputType> (xUnit v3 test projects host themselves)'],
    [/<RunSettingsFilePath>[^<]*coverlet\.runsettings\s*<\/RunSettingsFilePath>/, '<RunSettingsFilePath> naming coverlet.runsettings'],
    [/<Content\s+Include="xunit\.runner\.json"/, '<Content Include="xunit.runner.json" CopyToOutputDirectory=...>'],
    [/<Using\s+Include="Crucible\.Api\.Testing"/, '<Using Include="Crucible.Api.Testing" />'],
  ];
  for (const [re, what] of settings) {
    if (!re.test(csproj)) problems.push(`  DRIFT    ${rel(proj)} lacks ${what}`);
  }
  if (/TreatWarningsAsErrors>\s*false/i.test(csproj)) {
    problems.push(`  DRIFT    ${rel(proj)} turns TreatWarningsAsErrors off`);
  }

  // Template-derived files keep no template instructions.
  for (const f of sources) {
    if (f.startsWith(shared)) continue;
    const text = read(f);
    if (/TEMPLATE INSTRUCTIONS/.test(text)) {
      problems.push(`  TEMPLATE ${rel(f)} still has its TEMPLATE INSTRUCTIONS paragraph`);
    }
    const placeholder = /\bUNIQUE_(SET|MOTHER|COLUMN)\b/.exec(text);
    if (placeholder) problems.push(`  TEMPLATE ${rel(f)} still has the placeholder ${placeholder[0]} (substitute a uniquely indexed column)`);
  }
  if (/TEMPLATE INSTRUCTIONS/.test(csproj)) problems.push(`  TEMPLATE ${rel(proj)} still has its TEMPLATE INSTRUCTIONS comment`);

  // No local copies of the shared types.
  const sharedTypes = ['PostgresTestDatabase', 'TestDatabaseScope', 'TestAuthHandler', 'HubRecorder', 'HubHarness',
    'StubHttpMessageHandler', 'StubHttpClientFactory', 'RecordingLogger', 'Waits'];
  for (const f of sources) {
    if (f.startsWith(shared)) continue;
    const text = read(f);
    for (const t of sharedTypes) {
      if (new RegExp(`\\b(class|record|interface)\\s+${t}\\b`).test(text)) {
        problems.push(`  STALE    ${rel(f)} declares its own ${t} (use the shared one in Support/Shared)`);
      }
    }
  }

  const fixture = path.join(testDir, 'Support', 'DatabaseFixture.cs');
  if (fs.existsSync(fixture) && !/PostgresTestDatabase</.test(read(fixture))) {
    problems.push(`  DRIFT    ${rel(fixture)} does not use the shared PostgresTestDatabase<TContext>`);
  }

  // A factory declared as an assembly fixture is one instance for the whole run, so nothing registered in
  // it may be a substitute a test asserts on (README, "The recorder rule").
  const assembly = path.join(testDir, 'AssemblyFixtures.cs');
  if (fs.existsSync(assembly)) {
    const text = read(assembly);
    if (!/AssemblyFixture\(typeof\(DatabaseFixture\)\)/.test(text)) {
      problems.push(`  DRIFT    ${rel(assembly)} does not declare [assembly: AssemblyFixture(typeof(DatabaseFixture))]`);
    }
    for (const m of text.matchAll(/AssemblyFixture\(typeof\((\w+)\)\)/g)) {
      if (m[1] === 'DatabaseFixture') continue;
      const decl = sources.find((f) => new RegExp(`\\bclass\\s+${m[1]}\\b`).test(read(f)));
      if (decl && /Substitute\.For\b/.test(read(decl))) {
        problems.push(`  SHARED   ${rel(decl)}: ${m[1]} is a run-wide assembly fixture and registers a Substitute.For (use a recorder, or the per-class factory)`);
      }
    }
  }
}

// The comment text on one line of C#, with its markers stripped, or null when the line has no comment.
// `state.inBlock` carries a /* ... */ comment across lines. String and char literals are skipped, so a
// url in a string is not read as a comment. One-line strings only: a multi-line raw string is rare in a
// test and at worst hides a comment.
function commentOf(line, state) {
  let out = null;
  const add = (t) => { out = (out === null ? '' : out + ' ') + t; };
  let i = 0;
  while (i < line.length) {
    if (state.inBlock) {
      const close = line.indexOf('*/', i);
      add(line.slice(i, close < 0 ? line.length : close).replace(/^\s*\*+(?!\/)/, ''));
      if (close < 0) return out;
      state.inBlock = false;
      i = close + 2;
      continue;
    }
    const c = line[i];
    const next = line[i + 1];
    if (c === '/' && next === '/') { add(line.slice(i).replace(/^\/+/, '')); return out; }
    if (c === '/' && next === '*') { state.inBlock = true; i += 2; continue; }
    if (c === '"') {
      if (line.startsWith('"""', i)) {
        const close = line.indexOf('"""', i + 3);
        if (close < 0) return out;
        i = close + 3;
        continue;
      }
      const verbatim = line[i - 1] === '@' || (line[i - 1] === '$' && line[i - 2] === '@');
      i++;
      while (i < line.length) {
        if (!verbatim && line[i] === '\\') { i += 2; continue; }
        if (line[i] === '"') {
          if (verbatim && line[i + 1] === '"') { i += 2; continue; }
          break;
        }
        i++;
      }
      i++;
      continue;
    }
    if (c === "'") {
      const close = line.indexOf("'", next === '\\' ? i + 3 : i + 2);
      i = close < 0 ? line.length : close + 1;
      continue;
    }
    i++;
  }
  return out;
}

// Phrases that only a defect note uses. Matched against each run of consecutive comment lines joined into
// one text, so a phrase wrapped across two `///` lines is found. The capitalized defect tag and FIXME are
// case-sensitive words; the rest match in any case.
const DEFECT_PHRASES = [
  /\bturns?\s+red\b/gi,
  /\bgo(?:es)?\s+red\b/gi,
  /\bflips?\s+to\b/gi,
  /\bcharacteri[sz]es\s+(?:the\s+)?current\s+behaviou?r\b/gi,
  /\bever\s+fixed\b/gi,
  /\b(?:once|when|if|until)\s+(?:this|it|that)\s+(?:is|gets)\s+(?:ever\s+)?fixed\b/gi,
  /\bB[U]G\b/g,
  /\bFIXME\b/g,
];

// Phrases a defect note often uses but other prose does too ("a rename turns this red"): WARN lines, for
// the reviewer to read.
const DEFECT_PHRASES_WARN = [
  /\b(?:turns?|makes?|turning|making)\b[^.]{0,40}?\b(?:red|green)\b/g,
];

function checkTests() {
  const app = path.basename(repo);
  for (const f of sources) {
    if (f.startsWith(shared)) continue;
    const lines = read(f).split('\n');
    // Runs of consecutive lines that carry a comment: { start, text, offsets[] } where offsets[k] is where
    // line start + k begins in text.
    const runs = [];
    const state = { inBlock: false };
    let run = null;
    lines.forEach((line, i) => {
      const comment = commentOf(line, state);
      if (comment === null) { run = null; return; }
      if (!run) { run = { start: i, text: '', offsets: [] }; runs.push(run); }
      if (run.text) run.text += ' ';
      run.offsets.push(run.text.length);
      run.text += comment.trim();
    });
    const lineAt = (r, pos) => {
      let k = 0;
      while (k + 1 < r.offsets.length && r.offsets[k + 1] <= pos) k++;
      return r.start + k + 1;
    };
    for (const r of runs) {
      const hits = [];
      for (const re of DEFECT_PHRASES) {
        for (const m of r.text.matchAll(re)) {
          const from = lineAt(r, m.index);
          const to = lineAt(r, m.index + m[0].length - 1);
          hits.push(`"${m[0].replace(/\s+/g, ' ')}" at ${from === to ? from : `${from}-${to}`}`);
        }
      }
      const maybe = [];
      for (const re of DEFECT_PHRASES_WARN) {
        for (const m of r.text.matchAll(re)) {
          if (DEFECT_PHRASES.some((d) => new RegExp(d.source, d.flags.replace('g', '')).test(m[0]))) continue;
          maybe.push(`"${m[0].replace(/\s+/g, ' ')}" at ${lineAt(r, m.index)}`);
        }
      }
      if (maybe.length) notes.push(`  NOTE     prose: ${rel(f)}:${r.start + 1} reads like a defect note (${maybe.join('; ')}); if it describes a defect, move it to agent-docs/api-test-bugs/${app}.md (CONVENTIONS.md section 3)`);
      if (hits.length) {
        problems.push(`  PIN      ${rel(f)}:${r.start + 1} defect note in a test comment (${hits.join('; ')}): describe the defect in agent-docs/api-test-bugs/${app}.md and keep at most a neutral one-line summary (CONVENTIONS.md section 3)`);
      }
    }
    lines.forEach((line, i) => {
      if (/^\s*\/\//.test(line)) return;
      if (/\[\s*(Fact|Theory)\s*\([^)\]]*\bSkip\s*=/.test(line)) {
        problems.push(`  SKIP     ${rel(f)}:${i + 1} a skipped test reports nothing (characterize the current behaviour instead)`);
      }
      if (/\bAssert\s*\.\s*Skip(?:When|Unless)?\s*\(/.test(line)) {
        notes.push(`  NOTE     skip: ${rel(f)}:${i + 1} a dynamic skip (Assert.Skip/SkipWhen/SkipUnless): the reviewer confirms its condition can turn false without editing the test, and that the reason it prints says why (CONVENTIONS.md section 1)`);
      }
      if (/\.UseInMemoryDatabase\s*\(|\.UseSqlite\s*\(/.test(line)) {
        problems.push(`  STALE    ${rel(f)}:${i + 1} EF InMemory or SQLite in a test (use the PostgreSQL harness)`);
      }
      if (/\bNewContext\(\s*\)\s*\./.test(line)) {
        problems.push(`  LEAK     ${rel(f)}:${i + 1} NewContext() read inline is never disposed and keeps its pooled connection: use ReadBack(db => ...) or await using (CONVENTIONS.md section 1)`);
      }
    });
  }
  emptyGrantDenials();
  for (const cls of ['DatabaseHarnessTests', 'HttpHarnessTests', 'TestActorTests']) {
    if (!sources.some((f) => new RegExp(`\\bclass\\s+${cls}\\b`).test(read(f)))) {
      problems.push(`  MISSING  harness self-test class ${cls}`);
    }
  }
}

// A denied test whose caller holds nothing (CONVENTIONS.md section 4): a [Fact]/[Theory] that asserts
// HttpStatusCode.Forbidden or ForbiddenException, and whose client is an actor seeded as
// Actor().SeedAsync() with nothing between but WithId/WithName, which grant nothing. A heuristic over the
// method's text (full-line comments dropped), so it is a NOTE for the reviewer; the gates check never credits
// such a denial as a near miss. Support/ is exempt: the
// harness self-tests deliberately seed an empty actor to prove the transformer derives nothing.
function emptyGrantDenials() {
  const support = path.join(testDir, 'Support') + path.sep;
  const steps = String.raw`((?:\s*\.With(?:Id|Name)\((?:[^()]|\([^()]*\))*\))*)\s*\.SeedAsync\(\s*\)`;
  const seeded = new RegExp(String.raw`\bvar\s+(\w+)\s*=\s*await\s+Actor\(\)` + steps, 'g');
  const inline = new RegExp(String.raw`\bClient\(\s*await\s+Actor\(\)` + steps, 'g');
  const denial = /\bHttpStatusCode\.Forbidden\b|\bForbiddenException\b/;
  for (const f of sources) {
    if (f.startsWith(support)) continue;
    const lines = read(f).split('\n');
    const names = new Set();
    for (const line of lines) {
      const m = /^\s*public\s+(?:async\s+)?(?:Task|ValueTask|void)\s+(\w+)\s*\(/.exec(line);
      if (m) names.add(m[1]);
    }
    for (const name of names) {
      for (const t of testMethods(lines, name)) {
        const body = lines.slice(t.sig - 1, t.end).map((l) => (/^\s*\/\//.test(l) ? '' : l)).join('\n');
        if (!denial.test(body)) continue;
        const at = (index) => t.sig + body.slice(0, index).split('\n').length - 1;
        // A denial about a grant seeded outside the builder is not an empty grant: the actor's id written
        // into a row (`CreatedBy = actor.Id`, `createdBy: actor.Id`, `TestData.UnitUser(actor.Id, ...)`,
        // `SeedCatalog(..., actor.Id)`), or the method says so with a `// Data-row gate: <the row>`
        // comment (CONVENTIONS.md section 4).
        const raw = lines.slice(t.sig - 1, t.end).join('\n');
        if (/\/\/\s*Data-row gate:\s*\S/i.test(raw)) continue;
        const intoARow = (v) => new RegExp(
          String.raw`(?:=|\b\w+:)\s*${v}\.Id\b|\b(?:TestData\.\w+|Seed\w*)\((?:[^;]|\n)*?\b${v}\.Id\b`).test(body);
        const found = [];
        for (const m of body.matchAll(seeded)) {
          if (new RegExp(String.raw`\bClient\(\s*${m[1]}\s*\)`).test(body) && !intoARow(m[1])) found.push(at(m.index));
        }
        for (const m of body.matchAll(inline)) found.push(at(m.index));
        if (found.length) {
          notes.push(`  NOTE     empty grant: ${rel(f)}:${t.sig} ${name} asserts a denial for an actor seeded with no grant (Actor().SeedAsync() at ${found.join(', ')}): make the denied actor a near miss (CONVENTIONS.md section 4)`);
        }
      }
    }
  }
}

// The [Fact]/[Theory] methods called `name` in one test file: { sig, end, doc[], docStart } with 1-based
// lines (docStart is the first `///` line above the attributes).
// Formatting is assumed (dotnet format): a braced body closes on a `}` at the signature's indentation,
// an expression body at the first line ending in `;`. xUnit test methods are public.
function testMethods(lines, name) {
  const out = [];
  const decl = new RegExp(`^(\\s*)public\\s+(?:[\\w<>\\[\\],.?]+\\s+)*${name}\\s*\\(`);
  lines.forEach((line, i) => {
    const m = decl.exec(line);
    if (!m) return;
    const indent = m[1];
    let a = i - 1;
    const attrs = [];
    while (a >= 0 && lines[a].trim() && !/^\s*\/\/\//.test(lines[a]) && !/^\s*[{}]\s*$/.test(lines[a]) && !/;\s*$/.test(lines[a])) {
      attrs.unshift(lines[a]);
      a--;
    }
    if (!/\[\s*(Fact|Theory)\b/.test(attrs.join('\n'))) return;
    const doc = [];
    while (a >= 0 && /^\s*\/\/\//.test(lines[a])) { doc.unshift(lines[a]); a--; }
    let end = -1;
    let braced = /\{\s*$/.test(line) && !/=>/.test(line);
    for (let k = i; k < lines.length && end < 0; k++) {
      if (!braced && k > i && new RegExp(`^${indent}\\{\\s*$`).test(lines[k])) { braced = true; continue; }
      if (braced) {
        if (k > i && new RegExp(`^${indent}\\}\\s*$`).test(lines[k])) end = k;
      } else if (/=>/.test(lines.slice(i, k + 1).join('\n')) && /;\s*$/.test(lines[k])) {
        end = k;
      }
    }
    out.push({ sig: i + 1, end: end < 0 ? lines.length : end + 1, doc, docStart: a + 2 });
  });
  return out;
}

// The `Test:` line of a defect entry, `Test: `<test file>` `<test name>`` (testing/README.md, "Defect
// documents"); a code span may use more backticks when the name holds one. The old form, `<file>:<line>`
// with the name only in the heading, is read too (`legacy`), for testing/fix-docs.js to rewrite.
function parseTestLine(line) {
  const spans = [...line.replace(/^Test:\s*/, '').matchAll(/(`+)\s?(.+?)\s?\1(?!`)/g)].map((m) => m[2].trim());
  if (!spans.length) return null;
  const legacy = /^(.+?):(\d+)(?:-(\d+))?$/.exec(spans[0]);
  return { file: legacy ? legacy[1] : spans[0], name: legacy ? null : spans[1] || null, legacy: !!legacy };
}

// agent-docs/api-test-bugs/<app>.md (testing/README.md, "Defect documents"). Each entry names the test
// that characterizes it by test file and test name, and the check confirms that test exists. The
// document's own shape (sections, their order, the Fix and Test to flip lines, the summary counts, the
// `// Same case as` comments) is bookkeeping: NOTE lines that never block (orchestration/RULES.md,
// Process), most of which testing/fix-docs.js rewrites. One failure stays, because it is defect text in
// code: a test an entry names carries at most a one-line `/// <summary>` and no `<remarks>`.
function checkDefects() {
  const app = appArg || path.basename(repo);
  if (!APPS.includes(app)) {
    problems.push(`  USAGE    cannot tell the app from '${path.basename(repo)}'; pass it: check-repo.js defects <repo> <app> (one of ${APPS.join(', ')})`);
    return;
  }
  const docFile = path.join(AGENT_DOCS, 'api-test-bugs', `${app}.md`);
  const docName = `agent-docs/api-test-bugs/${app}.md`;
  if (!fs.existsSync(docFile)) {
    console.log(`  (no ${docName}: no defect entries to check)`);
    return;
  }
  const doc = read(docFile).split('\n');
  const where = (i) => `${docName}:${i + 1}`;
  const note = (i, msg) => notes.push(`  NOTE     defects: ${where(i)} ${msg}`);

  // Sections and entries.
  const CLOSING = ['Needs a decision', 'Found without a test', 'Gaps noticed'];
  const sections = []; // { title, line, kind: 'file'|'recipes'|'decision'|'other'|'unknown', entries: [] }
  let section = null;
  let entry = null;
  doc.forEach((line, i) => {
    let m;
    if ((m = /^## (.+?)\s*$/.exec(line))) {
      const title = m[1];
      const kind = title === 'Shared fix recipes' ? 'recipes'
        : title === 'Needs a decision' ? 'decision'
          : CLOSING.includes(title) ? 'other'
            : /\.cs$/.test(title) ? 'file' : 'unknown';
      section = { title, line: i, kind, entries: [] };
      sections.push(section);
      entry = null;
      if (kind === 'unknown') note(i, `'## ${title}' is neither a test file path nor one of the sections testing/README.md allows`);
    } else if ((m = /^### (.+?)\s*$/.exec(line)) && section) {
      entry = { name: m[1], line: i, body: [] };
      section.entries.push(entry);
    } else if (/^# /.test(line)) {
      section = null;
      entry = null;
    } else if (entry) {
      entry.body.push({ line, i });
    }
  });

  const fileSections = sections.filter((s) => s.kind === 'file');
  const counted = fileSections.flatMap((s) => s.entries);
  const checked = sections.filter((s) => s.kind === 'file' || s.kind === 'decision');
  const recipesUsed = new Map();
  let crossRepo = 0;
  let latent = 0;
  let unnamed = 0;

  const sorted = fileSections.map((s) => s.title);
  const inOrder = [...sorted].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  if (sorted.join('\n') !== inOrder.join('\n')) note(fileSections[0].line, 'test file sections are not in path order');

  for (const s of checked) {
    let lastSig = 0;
    for (const e of s.entries) {
      const text = e.body.map((b) => b.line).join('\n');
      const testLine = e.body.find((b) => /^Test:/.test(b.line));
      const fix = e.body.find((b) => /^\*\*Fix:\*\*/.test(b.line));
      const flip = e.body.find((b) => /^\*\*Test to flip:\*\*/.test(b.line));
      if (!fix) note(e.line, `${e.name}: no **Fix:** line`);
      if (!flip) note(e.line, `${e.name}: no **Test to flip:** line`);
      if (s.kind === 'decision' && fix && !/^\*\*Fix:\*\*\s*Decision needed:/.test(fix.line)) {
        note(fix.i, `${e.name}: a "Needs a decision" item's **Fix:** starts with "Decision needed:" and names the options`);
      }
      if (s.kind === 'file' && flip && !flip.line.includes(e.name) && !/\.cs\b/.test(flip.line)) {
        note(flip.i, `${e.name}: **Test to flip:** names the test that flips (this entry's own, or another with its file)`);
      }
      if (s.kind === 'file' && testLine) {
        const description = e.body.slice(e.body.indexOf(testLine) + 1).find((b) => b.line.trim());
        if (description && /^[a-z]/.test(description.line.trim()) && !/^[a-z][\w.-]*\//.test(description.line.trim()) && !/^[a-z][\w.-]*\.(?:cs|json|md|ya?ml)\b/.test(description.line.trim())) {
          note(description.i, `${e.name}: the description starts lowercase; it is a sentence`);
        }
      }
      if (s.kind === 'file') {
        if (fix && /^\*\*Fix:\*\*\s*Cross-repo;/.test(fix.line)) crossRepo++;
        if (/\(latent: (?:no caller|unreachable input)\)/.test(text)) latent++;
        if (fix) {
          const fixText = text.slice(text.indexOf('**Fix:**'), flip ? text.indexOf('**Test to flip:**') : undefined);
          for (const m of new Set([...fixText.matchAll(/\bRecipe ([A-Z])\b/g)].map((x) => x[1]))) {
            recipesUsed.set(m, (recipesUsed.get(m) || 0) + 1);
          }
        }
      }
      const t = testLine ? parseTestLine(testLine.line) : null;
      if (!testLine) note(e.line, `${e.name}: no 'Test:' line naming its test file and test name`);
      else if (!t) note(testLine.i, `${e.name}: 'Test:' is \`<test file>\` \`<test name>\``);
      else if (t.legacy) note(testLine.i, `${e.name}: 'Test:' carries a line number; it names the test file and the test name (testing/fix-docs.js rewrites it)`);
      const file = (t && t.file) || (s.kind === 'file' ? s.title : null);
      if (!file) continue;
      if (s.kind === 'file' && file !== s.title) note(testLine.i, `${e.name}: 'Test:' names ${file}, but the entry is under ## ${s.title}`);
      const name = (t && t.name) || e.name;
      if (t && t.name && t.name !== e.name) note(testLine.i, `'Test:' names ${t.name}, the heading ${e.name}`);
      const abs = path.join(repo, file);
      if (!fs.existsSync(abs)) { unnamed++; note(testLine ? testLine.i : e.line, `${name}: ${file} does not exist in the repo (moved? update the entry)`); continue; }
      const lines = read(abs).split('\n');
      const methods = testMethods(lines, name.replace(/[^\w]/g, (c) => `\\${c}`));
      if (methods.length !== 1) {
        unnamed++;
        note(e.line, methods.length === 0
          ? `${name}: no [Fact]/[Theory] of that name in ${file} (renamed or removed? update the entry; testing/fix-docs.js follows a removed-test A line)`
          : `${name}: ${methods.length} [Fact]/[Theory] methods of that name in ${file}`);
        continue;
      }
      const [method] = methods;
      if (s.kind === 'file' && method.sig < lastSig) note(e.line, `${e.name}: entries under ## ${s.title} are not in file order`);
      lastSig = Math.max(lastSig, method.sig);
      const docText = method.doc.join('\n');
      const oneLine = method.doc.length === 1 && /^\s*\/\/\/\s*<summary>.*<\/summary>\s*$/.test(method.doc[0]);
      if (/<remarks>/.test(docText) || (method.doc.length && !oneLine)) {
        problems.push(`  PIN      ${file}:${method.docStart} ${name} carries ${/<remarks>/.test(docText) ? 'a <remarks> block' : `a ${method.doc.length}-line doc comment`}; a test with a defect entry keeps at most a one-line /// <summary> (CONVENTIONS.md section 3)`);
      }
    }
  }

  // "Found without a test": each item a ### heading with a Reason: line, and none of them a test the
  // repo has (an item with a test is an entry).
  const testNames = new Set();
  for (const f of sources) {
    if (f.startsWith(shared)) continue;
    const lines = read(f).split('\n');
    for (const line of lines) {
      const m = /^\s*public\s+(?:async\s+)?(?:Task|ValueTask|void)\s+(\w+)\s*\(/.exec(line);
      if (m && !testNames.has(m[1]) && testMethods(lines, m[1]).length) testNames.add(m[1]);
    }
  }
  for (const s of sections.filter((x) => x.title === 'Found without a test')) {
    const end = sections[sections.indexOf(s) + 1]?.line ?? doc.length;
    const firstItem = s.entries.length ? s.entries[0].line : end;
    for (let i = s.line + 1; i < firstItem; i++) {
      if (/^\s*[-*] /.test(doc[i])) { note(i, 'a "Found without a test" item is a ### heading with a Reason: line, not a bullet'); break; }
    }
    for (const e of s.entries) {
      if (testNames.has(e.name.replace(/`/g, ''))) note(e.line, `${e.name}: is a test in this repo, so it is an entry under its test file, not "Found without a test"`);
      if (!e.body.some((b) => /^Reason:\s*\S/.test(b.line))) note(e.line, `${e.name}: no 'Reason:' line saying why the harness cannot characterize it`);
    }
  }

  // "Same case as" comments name a test that has an entry or a "Needs a decision" item.
  const named = new Set(checked.flatMap((x) => x.entries).map((e) => e.name));
  for (const f of sources) {
    if (f.startsWith(shared)) continue;
    read(f).split('\n').forEach((line, i) => {
      if (!/^\s*\/\/\s*Same case as\b/.test(line)) return;
      const m = /^\s*\/\/\s*Same case as ((?:[A-Za-z_]\w*\.)?([A-Za-z_]\w*))\.\s*$/.exec(line);
      if (!m) notes.push(`  NOTE     defects: ${rel(f)}:${i + 1} a Same-case comment is exactly '// Same case as <Test>.' or '// Same case as <Class>.<Test>.'`);
      else if (!named.has(m[2])) notes.push(`  NOTE     defects: ${rel(f)}:${i + 1} '${m[1]}' has no entry or "Needs a decision" item in ${docName}`);
    });
  }

  // The summary table and the intro line against the entries (testing/fix-docs.js recounts them).
  const rows = new Map();
  doc.forEach((line, i) => {
    const m = /^\|\s*([^|]+?)\s*\|\s*(\d+)\s*\|/.exec(line);
    if (m) rows.set(m[1], { count: Number(m[2]), i });
  });
  const row = (re) => [...rows.entries()].find(([label]) => re.test(label));
  const expectRow = (re, label, actual) => {
    const r = row(re);
    if (!r) notes.push(`  NOTE     defects: ${docName} summary table has no '${label}' row`);
    else if (r[1].count !== actual) note(r[1].i, `summary table '${r[0]}' says ${r[1].count}, the document has ${actual}`);
  };
  expectRow(/^Entries\b/, 'Entries', counted.length);
  expectRow(/^Cross-repo\b/, 'Cross-repo entries', crossRepo);
  expectRow(/^Latent\b/, 'Latent entries', latent);
  const intro = doc.findIndex((l) => /\b\d+ entr(y|ies)\.\s*$/.test(l));
  if (intro < 0) notes.push(`  NOTE     defects: ${docName} intro line does not end with the number of entries ('N entries.')`);
  else {
    const n = Number(/\b(\d+) entr(?:y|ies)\.\s*$/.exec(doc[intro])[1]);
    if (n !== counted.length) note(intro, `intro says ${n} entries, the document has ${counted.length}`);
  }
  const recipeSections = new Set((sections.find((s) => s.kind === 'recipes')?.entries || [])
    .map((e) => /^Recipe ([A-Z])\b/.exec(e.name)?.[1]).filter(Boolean));
  const recipeRows = new Set([...rows.keys()].map((l) => /^Recipe ([A-Z])\b/.exec(l)?.[1]).filter(Boolean));
  for (const r of new Set([...recipeSections, ...recipeRows, ...recipesUsed.keys()])) {
    if (!recipeSections.has(r)) notes.push(`  NOTE     defects: ${docName} Recipe ${r} is used or counted but has no '### Recipe ${r}:' under ## Shared fix recipes`);
    if (!recipeRows.has(r)) notes.push(`  NOTE     defects: ${docName} summary table has no 'Recipe ${r}' row`);
    else expectRow(new RegExp(`^Recipe ${r}\\b`), `Recipe ${r}`, recipesUsed.get(r) || 0);
  }
  const decisions = checked.filter((s) => s.kind === 'decision').flatMap((s) => s.entries).length;
  console.log(`  (${docName}: ${counted.length} entries, ${decisions} needing a decision, ${unnamed} naming a test that does not exist)`);
}

// Lines printed after the problems and warnings (the gates summary).
const trailer = [];
// ---------------------------------------------------------------------------------------------------------
// gates: every authorization call site in the application against the tests (CONVENTIONS.md section 4,
// "The gates check"). A text reader, not a compiler: the shapes it knows are listed in CONVENTIONS.md, and
// what it cannot link a writer links with a `// Gate: <id>` line in the test, or names in
// agent-docs/api-test-gaps/<app>.txt with the reason the harness cannot reach it.

// Two copies of a C# source with the same offsets: `a` has comments blanked, `b` has comments and the
// contents of string and char literals blanked too (the quotes stay). Newlines are kept, so offsets and
// line numbers agree with the file.
function scrub(text) {
  const a = text.split('');
  const b = text.split('');
  const blank = (arr, from, to) => { for (let k = from; k < to; k++) if (arr[k] !== '\n') arr[k] = ' '; };
  let i = 0;
  const n = text.length;
  while (i < n) {
    const c = text[i];
    const d = text[i + 1];
    if (c === '/' && d === '/') {
      let e = text.indexOf('\n', i);
      if (e < 0) e = n;
      blank(a, i, e); blank(b, i, e); i = e; continue;
    }
    if (c === '/' && d === '*') {
      let e = text.indexOf('*/', i + 2);
      e = e < 0 ? n : e + 2;
      blank(a, i, e); blank(b, i, e); i = e; continue;
    }
    if (c === "'") {
      let e = i + 1;
      while (e < n && text[e] !== "'" && text[e] !== '\n') e += text[e] === '\\' ? 2 : 1;
      blank(b, i + 1, e); i = e + 1; continue;
    }
    if (c === '"' || ((c === '$' || c === '@') && /^[$@]*"/.test(text.slice(i, i + 4)))) {
      let s = i;
      while (text[s] === '$' || text[s] === '@') s++;
      const prefix = text.slice(i, s);
      const verbatim = prefix.includes('@');
      if (text.startsWith('"""', s)) {
        let q = s;
        while (text[q] === '"') q++;
        const fence = text.slice(s, q);
        let e = text.indexOf(fence, q);
        e = e < 0 ? n : e;
        blank(b, q, e); i = e + fence.length; continue;
      }
      let e = s + 1;
      while (e < n) {
        if (!verbatim && text[e] === '\\') { e += 2; continue; }
        if (text[e] === '"') {
          if (verbatim && text[e + 1] === '"') { e += 2; continue; }
          break;
        }
        if (!verbatim && text[e] === '\n') break;
        e++;
      }
      blank(b, s + 1, e); i = e + 1; continue;
    }
    i++;
  }
  return { a: a.join(''), b: b.join('') };
}

const KEYWORDS = new Set(['if', 'for', 'foreach', 'while', 'switch', 'catch', 'using', 'lock', 'fixed', 'return',
  'else', 'try', 'finally', 'do', 'new', 'get', 'set', 'init', 'add', 'remove', 'when', 'checked', 'unchecked', 'nameof', 'typeof', 'base', 'this']);

// Types and members of one C# file, from braces and `=>` on the scrubbed copy. Formatting is not assumed.
function parseCs(src) {
  const { a, b } = scrub(src);
  const lineStarts = [0];
  for (let k = 0; k < src.length; k++) if (src[k] === '\n') lineStarts.push(k + 1);
  const lineOf = (off) => {
    let lo = 0;
    let hi = lineStarts.length - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (lineStarts[mid] <= off) lo = mid; else hi = mid - 1;
    }
    return lo + 1;
  };
  const types = [];
  const members = [];
  const stack = [];
  let namespace = '';
  let seg = 0;
  const top = () => stack[stack.length - 1];
  const enclosingType = () => [...stack].reverse().find((s) => s.kind === 'type');
  const classify = (header, at) => {
    const h = header.trim();
    let m;
    if ((m = /\bnamespace\s+([\w.]+)\s*$/.exec(h))) return { kind: 'namespace', name: m[1] };
    if ((m = /\b(class|record|struct|interface|enum)\s+(\w+)/.exec(h)) && !/\bnew\b[^(]*$/.test(h.slice(0, m.index))) {
      return { kind: m[1] === 'enum' ? 'block' : 'type', name: m[2], typeKind: m[1] };
    }
    const flat = h.replace(/\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\)/g, '()');
    const t = top();
    if (!t || t.kind === 'namespace' || t.kind === 'type') {
      if (/=/.test(flat.replace(/=>/g, ''))) return { kind: 'block' };
      if ((m = /(\w+)\s*(?:<[^<>{}()]*(?:<[^<>{}()]*>[^<>{}()]*)*>)?\s*\(\)\s*(?::\s*(?:base|this)\s*\(\))?\s*(?:where\b[^{}]*)?$/.exec(flat)) && !KEYWORDS.has(m[1])) {
        return { kind: 'member', name: m[1] };
      }
      if ((m = /(\w+)\s*$/.exec(flat)) && !KEYWORDS.has(m[1])) return { kind: 'member', name: m[1], property: true };
    }
    return { kind: 'block' };
  };
  const open = (info, headerFrom, at, expr) => {
    const t = enclosingType();
    const entry = { ...info, start: at, headerFrom, header: a.slice(headerFrom, at), raw: src.slice(headerFrom, at), expr: !!expr, parent: t || null, namespace };
    if (info.kind === 'type') { entry.members = []; entry.outer = t || null; types.push(entry); }
    if (info.kind === 'member') {
      if (stack.some((s) => s.kind === 'member')) entry.kind = 'block';
      else if (t) { members.push(entry); t.members.push(entry); }
    }
    if (info.kind === 'namespace') namespace = info.name;
    stack.push(entry);
    return entry;
  };
  const close = (at) => {
    const e = stack.pop();
    if (!e) return;
    e.end = at;
    e.body = a.slice(e.start, at);
    e.rawBody = src.slice(e.start, at);
    e.line = lineOf(e.start);
  };
  for (let i = 0; i < b.length; i++) {
    const c = b[i];
    if (c === '{') {
      const info = classify(b.slice(seg, i), i);
      open(info, seg, i, false);
      seg = i + 1;
    } else if (c === '}') {
      while (top() && top().expr) close(i);
      close(i + 1);
      seg = i + 1;
    } else if (c === ';') {
      const h = b.slice(seg, i);
      const fileNs = /\bnamespace\s+([\w.]+)\s*$/.exec(h.trim());
      if (fileNs && !stack.length) namespace = fileNs[1];
      if (top() && top().expr) close(i + 1);
      seg = i + 1;
    } else if (c === '=' && b[i + 1] === '>') {
      const t = top();
      if (t && t.kind === 'type') {
        const info = classify(b.slice(seg, i), i);
        if (info.kind === 'member') open(info, seg, i, true);
      }
      i++;
    }
  }
  while (stack.length) close(src.length);
  for (const m of members) m.attrs = m.header;
  return { types, members, lineOf, a, b, src };
}

// Matching parentheses from `from` (the index of an opening parenthesis) in the blanked copy.
function closeParen(b, from) {
  let depth = 0;
  for (let k = from; k < b.length; k++) {
    if (b[k] === '(') depth++;
    else if (b[k] === ')') { depth--; if (depth === 0) return k; }
  }
  return b.length;
}

// Top-level comma split of an argument list (text without the outer parentheses).
function splitArgs(text) {
  const out = [];
  let depth = 0;
  let cur = '';
  let inStr = null;
  for (let k = 0; k < text.length; k++) {
    const c = text[k];
    if (inStr) {
      cur += c;
      if (c === '\\' && inStr === '"') { cur += text[++k] || ''; continue; }
      if (c === inStr) inStr = null;
      continue;
    }
    if (c === '"' || c === "'") { inStr = c; cur += c; continue; }
    if ('([{<'.includes(c)) depth++;
    if (')]}>'.includes(c)) depth--;
    if (c === ',' && depth === 0) { out.push(cur.trim()); cur = ''; continue; }
    cur += c;
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}

const VERBS = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'];
const normRoute = (r) => r.replace(/^https?:\/\/[^/]+/i, '').replace(/[?#].*$/, '').replace(/^~?\/+/, '').replace(/\/+$/, '')
  .replace(/\{[^}]*\}/g, '{}').replace(/\/{2,}/g, '/').toLowerCase();
const joinRoute = (base, tmpl) => {
  if (tmpl && /^~?\//.test(tmpl)) return normRoute(tmpl);
  return normRoute([base || '', tmpl || ''].filter(Boolean).join('/'));
};
const singular = (w) => w.replace(/ies$/, 'y').replace(/(ss)$/, '$1').replace(/s$/, '');
const stemOf = (name) => name.replace(/^I(?=[A-Z])/, '').replace(/(Controller|Service|Hub|Handler)$/, '');
const opOf = (name) => name.replace(/Async$/, '');

const PERMISSION_TOKEN = /\b(\w*Permission)s?\s*\.\s*([A-Z]\w*)/g;
const GATE_NAMES = /^(?:Authorize|AuthorizeAsync|HasSpecificPermission|IsMet|Can[A-Z]\w*|Can)$/;
// A membership step that names the role it grants (`InGroup(group.Id, GroupMembershipRole.Manager)`,
// `OnMsel(msel, MselRole.Owner)`): the role stands for the resource permissions it carries.
const MEMBERSHIP_ROLE = /\.(?:On|In)[A-Z]\w*\s*\([^;]*?\b\w*Roles?\s*\.\s*[A-Z]\w*/;
const SELECTORS = /^SpecificPermission$/;
const NOT_GATES = /^(?:CanConvert|CanRead|CanWrite|CanSeek|CanTimeout|CanBeCanceled|CanHandle)$/;

function checkGates() {
  const apiRoot = repo;
  const authDir = /(^|\/)Authorization\//;
  const prodFiles = files(apiRoot, (p) => p.endsWith('.cs')).filter((f) => !f.startsWith(testDir + path.sep)
    && !/\/(Migrations[^/]*|[^/]*\.Client|[^/]*ApiClient)\//.test(rel(f)) && !/\.Migrations\.|\/Migrations\//.test(rel(f))
    && !/\.(Designer|g)\.cs$/.test(f));
  const parsed = prodFiles.map((f) => ({ file: f, rel: rel(f), ...parseCs(read(f)) }));
  const allTypes = parsed.flatMap((p) => p.types.map((t) => Object.assign(t, { pf: p })));
  // Types by name, every declaration kept: two features may each have a `BaseHandler` (vm.api's Vsphere
  // and Proxmox), so a name is resolved from where it is written (same namespace, an imported namespace,
  // an enclosing namespace) and gates are keyed by file, type and member.
  const typesByName = new Map();
  for (const t of allTypes) {
    if (t.kind !== 'type') continue;
    if (!typesByName.has(t.name)) typesByName.set(t.name, []);
    typesByName.get(t.name).push(t);
  }
  const usingCache = new Map();
  const usingsOf = (pf) => {
    if (!usingCache.has(pf)) usingCache.set(pf, new Set([...pf.a.matchAll(/^\s*(?:global\s+)?using\s+(?!static\b)(?:\w+\s*=\s*)?([\w.]+)\s*;/gm)].map((x) => x[1])));
    return usingCache.get(pf);
  };
  const resolveType = (name, from) => {
    const qual = /^(.*)\.(\w+)$/.exec(name || '');
    const simple = qual ? qual[2] : name;
    const all = typesByName.get(simple) || [];
    if (all.length <= 1 || !from) return all[0];
    if (qual) {
      const q = all.filter((c) => c.namespace === qual[1] || c.namespace.endsWith('.' + qual[1]));
      if (q.length) return q[0];
    }
    const ns = from.namespace || '';
    return all.find((c) => c.namespace === ns) || all.find((c) => from.pf && usingsOf(from.pf).has(c.namespace))
      || all.find((c) => ns.startsWith(c.namespace + '.')) || all[0];
  };
  const baseNames = (t) => {
    const m = /\)?\s*:\s*([^{]*)$/.exec(t.header.replace(/\((?:[^()]|\([^()]*\))*\)/g, ''));
    return m ? m[1].split(',').map((x) => x.trim().replace(/<.*$/, '')).filter(Boolean) : [];
  };
  const shortName = (n) => n.replace(/^.*\./, '');
  const derives = (t, re, depth = 0) => {
    if (!t || depth > 5) return false;
    return baseNames(t).some((n) => re.test(shortName(n)) || derives(resolveType(n, t), re, depth + 1));
  };
  const derivesType = (t, target, depth = 0) => {
    if (!t || !target || depth > 5) return false;
    return baseNames(t).some((n) => { const b = resolveType(n, t); return b === target || derivesType(b, target, depth + 1); });
  };
  const isController = (t) => /Controller$/.test(t.name) || derives(t, /^(Controller|ControllerBase)$/);
  const isHub = (t) => derives(t, /^Hub$/);
  const isHandler = (t) => /Handler$/.test(t.name) && !derives(t, /^AuthorizationHandler$/) && (/BaseHandler|IRequestHandler/.test(t.header) || derives(t, /BaseHandler|IRequestHandler/));
  const inAuthInfra = (pf, t) => authDir.test(pf.rel) || /(AuthorizationService|Requirement|AuthorizationHandler|ClaimsTransformer|ClaimsService)$/.test(t ? t.name : '')
    || (t && /\b(?:IValueResolver|IMemberValueResolver|IMappingAction|Profile)\b/.test(t.header));
  const REFUSAL = /\bForbiddenException\b|\bForbid\s*\(|\bUnauthorizedAccessException\b|Status403|HttpStatusCode\.Forbidden|\bUnauthorized\s*\(|\bChallenge\s*\(/;
  const SERVICE_AUTH_CALL = /\b\w*[Ss]ervice\s*\.\s*(?:Authorize|AuthorizeAsync|HasSpecificPermission|Can[A-Z]?\w*|Get\w*WithPermission\w*)\s*(?:<[^<>()]*>)?\s*\(/;

  // Gate helpers: methods outside the authorization infrastructure that take permission arrays, so their
  // callers pass the permissions (vm.api's Proxmox BaseHandler.GetVm, PlayerService.Can).
  const helpers = new Set();
  const helperTypes = new Map();
  const throwingHelpers = new Set();
  // Before 2026-10-09 the parameters were read from the whole header, attributes included, so an action
  // with [ProducesResponseType(typeof(IEnumerable<SystemPermission>))] made every member of its name a
  // "helper" (blueprint.api's GetMine actions vanished); the gates that hid are PROVISIONAL for one round.
  const legacyHelpers = new Set();
  const PERMISSION_LIST = /\b\w*Permission\s*\[\]|IEnumerable<\s*\w*Permission\s*>|List<\s*\w*Permission\s*>/;
  const paramsOf = (m) => {
    const h = m.header.replace(/=>[\s\S]*$/, '');
    let at = -1;
    for (const x of h.matchAll(new RegExp(String.raw`\b${m.name}\s*(?:<(?:[^<>]|<[^<>]*>)*>)?\s*\(`, 'g'))) at = x.index + x[0].length - 1;
    return at < 0 ? '' : h.slice(at + 1, closeParen(h, at));
  };
  for (const p of parsed) {
    for (const m of p.members) {
      if (inAuthInfra(p, m.parent)) continue;
      const whole = /\(([\s\S]*)\)\s*(?:where[\s\S]*)?$/.exec(m.header.replace(/=>[\s\S]*$/, ''));
      if (whole && PERMISSION_LIST.test(whole[1])) legacyHelpers.add(m.name);
      if (PERMISSION_LIST.test(paramsOf(m))) {
        helpers.add(m.name);
        if (/\bForbiddenException\b|\bForbid\s*\(/.test(m.body || '')) throwingHelpers.add(m.name);
        if (!helperTypes.has(m.name)) helperTypes.set(m.name, new Set());
        if (m.parent) helperTypes.get(m.name).add(m.parent);
      }
    }
  }
  const isGateDefinition = (m) => (GATE_NAMES.test(m.name) || helpers.has(m.name)) && !(m.parent && isHandler(m.parent) && /^Authorize$/.test(m.name));

  // A class's own `Can*` helper that asks the authorization service (vm.api's VmService.CanViewMapAsync,
  // caster.api's FileCommandHandler.CanLock): a call to it without a receiver, or on this/base, from the
  // same type or a type deriving from it, is a call site of its caller. A domain method (caster.api's
  // File.CanLock, which compares ids) asks no service and is not one.
  const canHelpers = new Map();
  for (let pass = 0; pass < 2; pass++) {
    for (const p of parsed) {
      for (const m of p.members) {
        if (!m.parent || inAuthInfra(p, m.parent) || !/^Can[A-Z]\w*$/.test(m.name) || NOT_GATES.test(m.name)) continue;
        const body = p.b.slice(m.start, m.end);
        const viaHelper = [...canHelpers.keys()].some((n) => n !== m.name && new RegExp(String.raw`(?:^|[^.\w])${n}\s*\(`).test(body));
        if (!SERVICE_AUTH_CALL.test(body) && !viaHelper) continue;
        if (!canHelpers.has(m.name)) canHelpers.set(m.name, []);
        if (canHelpers.get(m.name).some((h) => h.member === m)) continue;
        const calls = (body.match(new RegExp(SERVICE_AUTH_CALL.source, 'g')) || []).length;
        const tokens = calls === 1 ? [...new Set([...p.a.slice(m.start, m.end).matchAll(PERMISSION_TOKEN)].filter((y) => !SELECTORS.test(y[1])).map((y) => y[2]))] : [];
        const found = calls === 1 ? [...p.a.slice(m.start, m.end).matchAll(PERMISSION_TOKEN)].filter((y) => !SELECTORS.test(y[1])) : [];
        canHelpers.get(m.name).push({ member: m, type: m.parent, tokens, found });
      }
    }
  }

  // Selector helpers: a gate definition dispatching on a selector argument (cite.api's
  // SubmissionService.HasSpecificPermission(..., SpecificPermission, ...)). Its own authorization calls are
  // sub-gates, reached by the call sites that pass a selector value leading to them.
  const selectorValues = new Map();
  for (const p of parsed) {
    for (const x of p.b.matchAll(/\benum\s+(\w+)\s*\{([^}]*)\}/g)) if (SELECTORS.test(x[1])) selectorValues.set(x[1], x[2].split(',').map((v) => v.replace(/=.*$/, '').trim()).filter(Boolean));
  }

  // Hubs, as mapped (`MapHub<T>("/hubs/x", ...)`, optionally `.RequireAuthorization()`), resolved from
  // the mapping file's namespaces: a hub class nothing maps is not reachable.
  const hubMaps = [];
  for (const p of parsed) {
    for (const x of p.a.matchAll(/\bMapHub<\s*([\w.]+)\s*>\s*\(\s*"([^"]*)"/g)) {
      const open = p.b.indexOf('(', x.index + x[0].indexOf('>'));
      const close = closeParen(p.b, open);
      const chain = /^(?:\s*\.\s*\w+\s*\((?:[^()]|\([^()]*\))*\))*/.exec(p.b.slice(close + 1))[0];
      const from = p.types.filter((t) => t.kind === 'type' && t.start <= x.index && x.index < t.end).pop();
      const t = resolveType(x[1], from || { namespace: '', pf: p });
      hubMaps.push({ t, name: shortName(x[1]), path: x[2], requireAuth: /\.\s*RequireAuthorization\s*\(/.test(chain), anonymous: /\.\s*AllowAnonymous\s*\(/.test(chain), rel: p.rel, line: p.lineOf(x.index) });
    }
  }
  const mappedHubs = new Set(hubMaps.map((h) => h.t).filter(Boolean));
  const hubPathsByType = new Map();
  for (const h of hubMaps) if (h.t && !hubPathsByType.has(h.t)) hubPathsByType.set(h.t, h.path);

  // Minimal-API group prefix (player.api's MapGroup("/api/")).
  const groups = parsed.flatMap((p) => [...p.a.matchAll(/\bMapGroup\(\s*\$?"([^"]*)"/g)].map((x) => x[1]));
  const groupPrefix = groups.length === 1 ? groups[0] : '';

  const routeAttr = (text) => {
    const out = [];
    for (const x of text.matchAll(/\bRoute\(\s*"([^"]*)"/g)) out.push(x[1]);
    return out;
  };
  const controllerBase = (t) => {
    for (let cur = t, d = 0; cur && d < 6; d++) {
      const r = routeAttr(cur.header);
      if (r.length) return r[0].replace(/\[controller\]/gi, stemOf(t.name));
      cur = resolveType(baseNames(cur)[0], cur);
    }
    return '';
  };
  const actionRoutes = (t, m) => {
    const base = controllerBase(t);
    const out = [];
    const attrs = m.header;
    const own = routeAttr(attrs.replace(/\bHttp\w+\s*\([^)]*\)/g, ''));
    for (const x of attrs.matchAll(/\bHttp(Get|Post|Put|Delete|Patch)\b\s*(?:\(\s*(?:"([^"]*)")?[^)]*\))?/g)) {
      const tmpl = x[2] !== undefined ? x[2] : (own[0] || '');
      out.push({ verb: x[1].toUpperCase(), route: joinRoute(base, tmpl) });
    }
    return out;
  };

  // Who reaches a member, as routes (verb, route) and names (for tests that call it without HTTP), and
  // the members on the way (`via`), whose gates run first.
  function reach(p, m, depth = 0, seen = new Set()) {
    const key = `${p.rel}#${m.parent ? m.parent.name : ''}.${m.name}@${m.start}`;
    const out = { routes: [], ops: new Set(), stems: new Set(), calls: new Set(), hubs: new Set(), callers: 0, via: new Set() };
    if (seen.has(key) || depth > 3) return out;
    seen.add(key);
    const t = m.parent;
    const add = (o, viaMember) => {
      out.routes.push(...o.routes);
      out.callers += o.callers || 0;
      for (const k of ['ops', 'stems', 'calls', 'hubs', 'via']) for (const v of o[k]) out[k].add(v);
      if (viaMember) out.via.add(viaMember);
    };
    if (t && isController(t) && actionRoutes(t, m).length) {
      out.routes.push(...actionRoutes(t, m));
      out.ops.add(opOf(m.name));
      out.stems.add(stemOf(t.name));
      return out;
    }
    if (t && isHub(t) && /\bpublic\b/.test(m.header)) {
      out.ops.add(opOf(m.name));
      out.stems.add(t.name);
      out.stems.add(stemOf(t.name));
      out.calls.add(m.name);
      out.hubs.add(t.name);
      return out;
    }
    if (t && isHandler(t) && t.outer && t.outer.kind === 'type') {
      const req = t.outer;
      out.ops.add(req.name);
      out.stems.add(req.name);
      const feature = /(?:^|\/)Features\/([^/]+)\//.exec(p.rel);
      if (feature) { out.stems.add(feature[1]); out.stems.add(singular(feature[1])); }
      // minimal API endpoint in the same request class
      for (const x of req.body.matchAll(/\.Map(Get|Post|Put|Delete|Patch)\(\s*\$?"([^"]*)"/g)) {
        out.routes.push({ verb: x[1].toUpperCase(), route: joinRoute(groupPrefix, x[2]) });
      }
      for (const x of req.body.matchAll(/\.WithName\(\s*"(\w+)"/g)) out.ops.add(x[1][0].toUpperCase() + x[1].slice(1));
      // controller actions in the same namespace that send it
      const ref = new RegExp(String.raw`\b${req.name}\s*\.\s*\w+\b`);
      for (const q of parsed) {
        for (const ct of q.types) {
          if (ct.kind !== 'type' || ct === t || ct === req || (ct.namespace !== req.namespace && !new RegExp(String.raw`\busing\s+${req.namespace.replace(/\./g, '\\.')}\s*;`).test(q.a))) continue;
          for (const am of ct.members) if ((ref.test(am.header) || ref.test(am.body)) && (isController(ct) || /\.\s*(?:Send|Publish)\s*(?:<[^<>()]*>)?\s*\(/.test(am.body))) { out.callers = (out.callers || 0) + 1; add(reach(q, am, depth + 1, seen), am); }
        }
      }
      return out;
    }
    // A service (or a base handler) method: whoever calls it.
    if (!t) return out;
    out.ops.add(opOf(m.name));
    out.stems.add(stemOf(t.name));
    out.stems.add(t.name);
    out.calls.add(m.name);
    const typeNames = [t.name, ...allTypes.filter((x) => x.kind === 'type' && x.typeKind === 'interface' && t.header.includes(x.name)).map((x) => x.name)];
    const stem = stemOf(t.name).toLowerCase();
    const callRe = new RegExp(String.raw`(?:\b(\w+)\s*\.\s*)?\b${m.name}\s*(?:<[^<>()]*>)?\s*\(`, 'g');
    for (const q of parsed) {
      if (!callRe.test(q.b)) continue;
      callRe.lastIndex = 0;
      const mentions = typeNames.some((n) => new RegExp(String.raw`\b${n}\b`).test(q.b));
      for (const cm of q.members) {
        if (cm === m || isGateDefinition(cm)) continue;
        const body = q.b.slice(cm.start, cm.end);
        for (const x of body.matchAll(callRe)) {
          const recv = (x[1] || '').toLowerCase();
          const sameType = !recv || recv === 'this' || recv === 'base';
          const related = sameType ? (cm.parent === t || (cm.parent && derivesType(cm.parent, t)))
            : (recv.replace(/^_/, '').includes(stem) || (/^_?service$/.test(recv) && mentions));
          if (related) { out.callers = (out.callers || 0) + 1; add(reach(q, cm, depth + 1, seen), cm); break; }
        }
      }
    }
    return out;
  }

  // How a call site's verdict is used. `refuses`: it decides a refusal (a throw, a Forbid, a handler's
  // Authorize override, a returned verdict); `branch`: it also, or only, picks what an admitted caller
  // gets (passed to a service, joined into an `if` that refuses nobody, combined into a flag).
  const ifAround = (b, at, lo) => {
    let best = null;
    const re = /\bif\s*\(/g;
    re.lastIndex = lo;
    for (let x; (x = re.exec(b)) && x.index < at;) {
      const open = x.index + x[0].length - 1;
      const close = closeParen(b, open);
      if (open < at && at < close) best = { open, close };
    }
    if (!best) return null;
    const then = stmtAt(b, best.close + 1);
    const e = /^\s*else\b/.exec(b.slice(then.to));
    const otherwise = e ? stmtAt(b, then.to + e[0].length) : null;
    return { ...best, then, otherwise };
  };
  const refusesIn = (b, ctl) => REFUSAL.test(b.slice(ctl.then.from, ctl.then.to)) || (ctl.otherwise && REFUSAL.test(b.slice(ctl.otherwise.from, ctl.otherwise.to)));
  const loopAround = (b, at, lo) => {
    const re = /\b(?:foreach|for|while)\s*\(/g;
    re.lastIndex = lo;
    for (let x; (x = re.exec(b)) && x.index < at;) {
      const open = x.index + x[0].length - 1;
      const close = closeParen(b, open);
      const body = stmtAt(b, close + 1);
      if (at > close && at < body.to) return true;
    }
    return false;
  };
  function useOf(p, m, at) {
    const b = p.b;
    const lo = m.start;
    const stmtFrom = Math.max(b.lastIndexOf(';', at), b.lastIndexOf('{', at), b.lastIndexOf('}', at)) + 1;
    const before = b.slice(stmtFrom, at);
    const ctl = ifAround(b, at, lo);
    const out = { refuses: false, branch: false, vars: new Set(), solo: false, stmtFrom, inLoop: loopAround(b, at, lo), ctl };
    if (ctl) {
      if (refusesIn(b, ctl)) { out.refuses = true; out.refusesHere = true; } else out.branch = true;
      return out;
    }
    const assign = /(?:^|[\s(,])(?:var\s+|bool\s+)?([A-Za-z_]\w*)\s*=(?![=>])[^;]*$/.exec(before);
    if (!assign) { out.refuses = true; out.refusesHere = true; return out; }
    const follow = (name, depth, from, combined) => {
      if (depth > 2) return;
      out.vars.add(name);
      const re = new RegExp(String.raw`\b${name}\b(?!\s*=(?![=>]))`, 'g');
      re.lastIndex = from;
      for (let x; (x = re.exec(b)) && x.index < m.end;) {
        if (b[x.index - 1] === '.') continue;
        const c = ifAround(b, x.index, lo);
        const sFrom = Math.max(b.lastIndexOf(';', x.index), b.lastIndexOf('{', x.index), b.lastIndexOf('}', x.index)) + 1;
        if (c && c.open >= sFrom - 1) {
          if (refusesIn(b, c)) { out.refuses = true; out.refusesHere = true; } else out.branch = true;
          const cond = b.slice(c.open + 1, c.close);
          if (!combined && !/&&|\|\|/.test(cond)) out.solo = true;
          continue;
        }
        const s = b.slice(sFrom, b.indexOf(';', x.index) < 0 ? m.end : b.indexOf(';', x.index));
        if (/^\s*return\b/.test(s)) { out.refuses = true; out.refusesHere = true; if (!combined) out.solo = true; continue; }
        const w = /^\s*(?:var\s+|bool\s+)?([A-Za-z_]\w*)\s*=(?![=>])/.exec(s);
        // Passed to a call (`GetForScoringModelAsync(id, viewAsAdmin, ct)`): the callee picks a branch.
        const upTo = b.slice(sFrom, x.index);
        let depth = 0;
        let callArg = false;
        for (let k = upTo.length - 1; k >= 0; k--) {
          if (upTo[k] === ')') depth++;
          else if (upTo[k] === '(') { if (depth === 0) { callArg = /[\w>]\s*$/.test(upTo.slice(0, k)) && !/\b(?:if|while|return)\s*$/.test(upTo.slice(0, k)); break; } depth--; }
        }
        // The callee may refuse on it as well (blueprint.api's services take `hasSystemPermission`).
        if (callArg) { out.branch = true; out.refuses = true; out.passedOn = true; if (!combined) out.solo = true; continue; }
        if (w && w[1] !== name) {
          const joins = /&&|\|\|/.test(s);
          if (!combined && !joins) out.solo = true;
          follow(w[1], depth + 1, sFrom + s.length, combined || joins);
          continue;
        }
        out.branch = true;
        if (!combined) out.solo = true;
      }
    };
    follow(assign[1], 0, b.indexOf(';', at) < 0 ? at : b.indexOf(';', at), false);
    if (!out.refuses && !out.branch) { out.refuses = true; out.refusesHere = true; }
    return out;
  }
  function stmtAt(b, from) {
    let i = from;
    while (i < b.length && /\s/.test(b[i])) i++;
    if (b[i] === '{') {
      let d = 0;
      for (let k = i; k < b.length; k++) { if (b[k] === '{') d++; else if (b[k] === '}' && --d === 0) return { from: i, to: k + 1 }; }
      return { from: i, to: b.length };
    }
    const kw = /^(if|foreach|for|while|using|lock)\s*\(/.exec(b.slice(i, i + 12));
    if (kw) {
      const open = b.indexOf('(', i);
      const inner = stmtAt(b, closeParen(b, open) + 1);
      let to = inner.to;
      if (kw[1] === 'if') { const e = /^\s*else\b/.exec(b.slice(to)); if (e) to = stmtAt(b, to + e[0].length).to; }
      return { from: i, to };
    }
    const semi = b.indexOf(';', i);
    return { from: i, to: semi < 0 ? b.length : semi + 1 };
  }

  // Inventory.
  const gates = [];
  const memberGate = new Map();
  const callRe = /(?:\b(\w+)\s*\.\s*)?\b([A-Z]\w*)\s*(?:<(?:[^<>()]|<[^<>()]*>)*>)?\s*\(/g;
  const siteFrom = (p, t, m, x, extra = {}) => {
    const name = x[2];
    const recv = x[1] || '';
    const at = m.start + x.index;
    const parenAt = m.start + x.index + x[0].length - 1;
    const args = p.a.slice(parenAt + 1, closeParen(p.b, parenAt));
    // cite.api's SpecificPermission (View, Submit, Score) selects which team permission
    // SubmissionService.HasSpecificPermission asks for; it is not a claim a test grants.
    let found = [...args.matchAll(PERMISSION_TOKEN)].filter((y) => !SELECTORS.test(y[1]));
    if (!found.length && extra.helper) found = extra.helper.found;
    const tokens = [...new Set(found.map((y) => y[2]))];
    const resourceTokens = [...new Set(found.filter((y) => !/System/.test(y[1])).map((y) => y[2]))];
    const resourceEnums = [...new Set(found.filter((y) => !/System/.test(y[1])).map((y) => y[1]))];
    const enums = [...new Set(found.map((y) => y[1]))];
    const systemTokens = [...new Set(found.filter((y) => /System/.test(y[1])).map((y) => y[2]))];
    const body = p.b.slice(m.start, m.end);
    // The check before 2026-10-09: a gate whose verdict picks a branch (all events, or only the caller's)
    // rather than refusing: no negation before the call and no refusal anywhere in the member.
    const before = p.b.slice(Math.max(p.b.lastIndexOf(';', at), p.b.lastIndexOf('{', at), p.b.lastIndexOf('}', at)) + 1, at);
    const legacyBranch = !(isHandler(t) && m.name === 'Authorize') && !throwingHelpers.has(name) && !/!\s*\(?\s*(?:await\s+)?$/.test(before)
      && /(?:\bif\s*\(|[^=!<>]=|\?|&&|\|\|)\s*\(?\s*(?:await\s+)?$/.test(before)
      && !/\bForbiddenException\b|\bForbid\s*\(|\bUnauthorizedAccessException\b|Status403|HttpStatusCode\.Forbidden/.test(body);
    let use;
    if ((isHandler(t) && m.name === 'Authorize') || throwingHelpers.has(name)) use = { refuses: true, refusesHere: true, branch: false, vars: new Set(), solo: true, stmtFrom: at, inLoop: loopAround(p.b, at, m.start), ctl: ifAround(p.b, at, m.start) };
    else use = useOf(p, m, at);
    return { line: p.lineOf(at), at, before, call: `${recv ? recv + '.' : ''}${name}`, tokens, resourceTokens, resourceEnums, enums, systemTokens, args, legacyBranch, use, ...extra };
  };
  for (const p of parsed) {
    for (const m of p.members) {
      const t = m.parent;
      if (!t || inAuthInfra(p, t)) continue;
      const selectorParam = isGateDefinition(m) && /\(([\s\S]*)\)/.test(m.header) && [...selectorValues.keys()].some((s) => new RegExp(String.raw`\b${s}\s+\w+`).test(m.header.replace(/=>[\s\S]*$/, '')));
      if (isGateDefinition(m) && !selectorParam) continue;
      const hiddenBefore = legacyHelpers.has(m.name) && !helpers.has(m.name) && !GATE_NAMES.test(m.name);
      const body = p.b.slice(m.start, m.end);
      const sites = [];
      for (const x of body.matchAll(callRe)) {
        const name = x[2];
        const recv = x[1] || '';
        let ok = false;
        let helper = null;
        if (/^(Authorize|AuthorizeAsync)$/.test(name)) ok = /service$/i.test(recv);
        else if (name === 'HasSpecificPermission') ok = !selectorParam && (!recv || /service$/i.test(recv));
        else if (name === 'IsMet') ok = /Requirement$/.test(recv);
        else if (/^Can([A-Z]\w*)?$/.test(name) && !NOT_GATES.test(name)) {
          ok = /service$/i.test(recv);
          if (!ok && !selectorParam && (!recv || recv === 'this' || recv === 'base') && canHelpers.has(name)) {
            helper = canHelpers.get(name).find((h) => h.type === t || derivesType(t, h.type));
            ok = !!helper && helper.member !== m;
          }
        } else if (helpers.has(name) && !selectorParam) {
          // A helper is called on its own type (or a subclass), or on a service field named for it.
          const owners = [...helperTypes.get(name)];
          ok = (!recv || recv === 'this' || recv === 'base')
            ? owners.some((o) => o === t || derivesType(t, o))
            : /service$/i.test(recv) && owners.some((o) => recv.toLowerCase().replace(/^_/, '').includes(stemOf(o.name).toLowerCase()));
        }
        if (!ok) continue;
        sites.push(siteFrom(p, t, m, x, helper ? { helper, provisional: `a call to ${t.name}'s own helper ${name}` } : selectorParam ? { provisional: `a sub-gate of the selector helper ${t.name}.${m.name}` }
          : hiddenBefore ? { provisional: `a member the check mistook for gate machinery until now (an attribute naming a permission list)` } : {}));
      }
      if (!sites.length) {
        if (isHandler(t) && m.name === 'Authorize' && /\b(?:Task\.FromResult\(\s*true\s*\)|=>\s*true\b|return\s+true\s*;)/.test(m.body) && !/\breturn\s+(?!true)/.test(m.body.replace(/return\s+true\s*;/g, ''))) {
          notes.push(`  NOTE     open: ${p.rel}:${m.line} ${t.outer ? t.outer.name + '.' : ''}${t.name}.Authorize allows every caller`);
        } else if (!isGateDefinition(m) && /\bthrow\s+new\s+(?:ForbiddenException|UnauthorizedAccessException)\b/.test(body) && !/(?:^|[^.\w]|\bthis\s*\.\s*)Authorize\s*\(/.test(body)) {
          notes.push(`  NOTE     uninventoried: ${p.rel}:${m.line} ${t.outer && t.outer.kind === 'type' ? t.outer.name + '.' : ''}${t.name}.${m.name} refuses without a call the check inventories (a data or claims gate); read it by hand`);
        }
        continue;
      }
      // Selector sub-gates: which selector values reach each site.
      if (selectorParam) {
        const sel = [...selectorValues.keys()].find((s) => new RegExp(String.raw`\b${s}\s+\w+`).test(m.header));
        const all = selectorValues.get(sel);
        for (const s of sites) {
          let allowedVals = new Set(all);
          const re = /\bif\s*\(/g;
          re.lastIndex = m.start;
          for (let x; (x = re.exec(p.b)) && x.index < s.at;) {
            const open = x.index + x[0].length - 1;
            const close = closeParen(p.b, open);
            const cond = p.b.slice(open + 1, close);
            const v = new RegExp(String.raw`\b\w+\s*(==|!=)\s*${sel}\s*\.\s*(\w+)`).exec(cond);
            if (!v) continue;
            const then = stmtAt(p.b, close + 1);
            const e = /^\s*else\b/.exec(p.b.slice(then.to));
            const otherwise = e ? stmtAt(p.b, then.to + e[0].length) : null;
            const inThen = s.at > then.from && s.at < then.to;
            const inElse = otherwise && s.at > otherwise.from && s.at < otherwise.to;
            if (!inThen && !inElse) continue;
            const yes = (v[1] === '==') === inThen;
            allowedVals = new Set([...allowedVals].filter((val) => (val === v[2]) === yes));
          }
          const cases = [...p.b.slice(m.start, s.at).matchAll(new RegExp(String.raw`\bcase\s+${sel}\s*\.\s*(\w+)\s*:`, 'g'))];
          const sw = p.b.lastIndexOf('switch', s.at);
          if (cases.length && sw > m.start && m.start + cases[cases.length - 1].index > sw) allowedVals = new Set([...allowedVals].filter((val) => val === cases[cases.length - 1][1]));
          s.selector = { name: sel, values: allowedVals };
        }
      }
      const same = t.members.filter((x) => x.name === m.name && !x.property);
      const overload = same.length > 1 ? `@${same.indexOf(m) + 1}` : '';
      const base = `${p.rel}#${t.outer && t.outer.kind === 'type' && isHandler(t) ? t.outer.name + '.' : ''}${t.name}.${m.name}${overload}`;
      const kind = isHub(t) ? 'hub method' : sites.every((s) => !s.tokens.length) ? 'requirement' : 'permission';
      const member = { id: base, rel: p.rel, line: m.line, name: m.name, type: t.name, typeObj: t, m, p, reach: null, sites: [], selector: selectorParam };
      sites.forEach((s, k) => member.sites.push({ ...s, id: sites.length > 1 ? `${base}:${k + 1}` : base, k, member, kind: kind === 'hub method' ? kind : s.tokens.length ? 'permission' : 'requirement' }));
      gates.push(member);
      memberGate.set(m, member);
    }
    // The default policy's and the MVC filter's scope requirement (every Crucible API requires the
    // configured scopes of every token): one gate per member that builds it, refused by a token without a
    // scope (`TestAuthHandler.ScopeHeader`).
    for (const m of p.members) {
      const t = m.parent;
      if (!t || /\bRequireScope\s*\(\s*this\b/.test(m.header)) continue;
      const body = p.b.slice(m.start, m.end);
      const scopeAt = /\bRequireClaim\s*\(\s*"scope"|\.\s*RequireScope\s*\(/.exec(p.a.slice(m.start, m.end));
      if (!scopeAt) continue;
      const filter = /\bnew\s+AuthorizeFilter\s*\(/.test(body);
      const id = `${p.rel}#${t.name}.${m.name}[scope]`;
      const line = p.lineOf(m.start + scopeAt.index);
      gates.push({ id, rel: p.rel, line, name: m.name, type: t.name, scope: filter ? 'filter' : 'policy', sites: [{ id, line, call: filter ? 'AuthorizeFilter scope' : 'default policy scope', tokens: [], kind: filter ? 'scope filter' : 'scope policy', provisional: 'the scope requirement' }] });
    }
  }
  // Hubs: the connection gate is the hub class's [Authorize], or `.RequireAuthorization()` on its mapping;
  // a hub class nothing maps is unreachable.
  for (const t of allTypes) {
    if (t.kind !== 'type' || !isHub(t)) continue;
    const attr = /\[\s*Authorize\b/.test(t.header) && !/\[\s*AllowAnonymous\b/.test(t.header);
    const map = hubMaps.find((h) => h.t === t);
    if (hubMaps.length && !map) {
      if (attr) notes.push(`  NOTE     unrouted: ${t.pf.rel}#${t.name}[Authorize] (line ${t.line}): no MapHub maps this hub class, so it is not counted`);
      continue;
    }
    if (!attr && !(map && map.requireAuth)) continue;
    const id = `${t.pf.rel}#${t.name}${attr ? '[Authorize]' : '[RequireAuthorization]'}`;
    gates.push({ id, rel: t.pf.rel, line: attr ? t.line : map.line, name: '[Authorize]', type: t.name, typeObj: t, hubConnection: true, path: map ? map.path : undefined, sites: [{ id, line: attr ? t.line : map.line, call: attr ? '[Authorize]' : `MapHub<${t.name}>().RequireAuthorization()`, tokens: [], kind: 'hub connection', provisional: attr ? undefined : 'a hub gated by its mapping' }] });
  }
  for (const p of parsed) {
    for (const t of p.types) {
      if (t.kind !== 'type' || !isController(t)) continue;
      const classAnon = /\[\s*AllowAnonymous\b/.test(t.header);
      for (const m of t.members) {
        if (classAnon || /\[\s*AllowAnonymous\b/.test(m.header)) {
          for (const r of actionRoutes(t, m)) notes.push(`  NOTE     anonymous: ${r.verb} ${r.route} (${p.rel}:${m.line} ${t.name}.${m.name})`);
        }
      }
    }
  }
  // Reach, now that every gate member is known (a selector sub-gate is reached by the call sites that
  // pass a value leading to it).
  for (const g of gates) {
    if (g.hubConnection || g.scope) continue;
    if (!g.selector) { g.reach = reach(g.p, g.m); continue; }
    g.reach = { routes: [], ops: new Set(), stems: new Set(), calls: new Set(), hubs: new Set(), callers: 0, via: new Set() };
    g.siteReach = new Map();
    for (const s of g.sites) {
      const r = { routes: [], ops: new Set(), stems: new Set(), calls: new Set(), hubs: new Set(), callers: 0, via: new Set() };
      const callSel = new RegExp(String.raw`\b${g.name}\s*(?:<[^<>()]*>)?\s*\(([^;]*?)\b${s.selector.name}\s*\.\s*(\w+)`, 'g');
      for (const q of parsed) {
        for (const cm of q.members) {
          if (!cm.parent || cm === g.m || isGateDefinition(cm)) continue;
          for (const x of q.b.slice(cm.start, cm.end).matchAll(callSel)) {
            if (!s.selector.values.has(x[2])) continue;
            const o = reach(q, cm);
            r.routes.push(...o.routes);
            r.callers += 1 + (o.callers || 0);
            for (const k of ['ops', 'stems', 'calls', 'hubs', 'via']) for (const v of o[k]) r[k].add(v);
            r.via.add(cm);
            break;
          }
        }
      }
      g.siteReach.set(s, r);
      g.reach.routes.push(...r.routes);
      g.reach.callers += r.callers;
      for (const k of ['ops', 'stems', 'calls', 'hubs', 'via']) for (const v of r[k]) g.reach[k].add(v);
    }
  }

  // The tests: one case per [Fact], one per [InlineData] row of a [Theory].
  const testSources = sources.filter((f) => !f.startsWith(path.join(testDir, 'Support') + path.sep));
  const cases = [];
  for (const f of testSources) {
    const p = parseCs(read(f));
    for (const t of p.types) {
      if (t.kind !== 'type') continue;
      const consts = new Map();
      for (const x of t.body.matchAll(/\b(?:const|static\s+readonly)\s+string\s+(\w+)\s*=\s*(\$?@?"[^"\n]*")/g)) if (!consts.has(x[1])) consts.set(x[1], x[2]);
      const helperBodies = new Map();
      const helperExprs = new Map();
      for (const m of t.members) {
        if (/\[\s*(Fact|Theory)\b/.test(m.header)) continue;
        helperBodies.set(m.name, (helperBodies.get(m.name) || '') + '\n' + m.body + '\n' + m.rawBody);
        const e = /^\s*=>\s*(\$?@?"[^"\n]*")\s*;?\s*$/.exec(m.body);
        if (e) { helperExprs.set(m.name, e[1]); continue; }
        // A helper or property whose body holds one route literal (built by concatenation, with a query,
        // or from a local const) resolves to it.
        const routes = [...new Set([...m.body.matchAll(/(\$?@?"\/?(?:api|hubs)\/[^"\n]*")/g)].map((x) => x[1]))];
        if (routes.length === 1) helperExprs.set(m.name, routes[0]);
      }
      for (const m of t.members) {
        if (!/\[\s*(Fact|Theory)\b/.test(m.header)) continue;
        // Inline the class's own helpers the test calls (three levels), so a grant or a request made in a
        // private helper counts.
        let text = m.body;
        let raw = m.rawBody;
        const inlined = new Set();
        for (let depth = 0; depth < 3; depth++) {
          let grew = false;
          for (const [name, hb] of helperBodies) {
            if (inlined.has(name) || name === m.name) continue;
            if (new RegExp(String.raw`\b${name}\s*(?:<[^<>()]*>)?\s*\(`).test(text)) { text += '\n' + hb; raw += '\n' + hb; inlined.add(name); grew = true; }
          }
          if (!grew) break;
        }
        const params = (() => {
          const x = /\(([^()]*(?:\([^()]*\)[^()]*)*)\)\s*$/.exec(m.header.replace(/=>[\s\S]*$/, '').trim());
          return x ? splitArgs(x[1]).map((s) => s.split(/\s+/).pop()) : [];
        })();
        const rows = [...m.header.matchAll(/\[\s*InlineData\s*\(/g)].map((x) => {
          const from = x.index + x[0].length - 1;
          return splitArgs(m.header.slice(from + 1, closeParen(m.header, from)));
        });
        // [MemberData(nameof(Routes))] over a TheoryData table of string rows (blueprint.api's
        // RouteAuthorizationTests): each `{ "GET", "api/...", ... }` or `Add("GET", ...)` is a row.
        for (const md of m.header.matchAll(/\[\s*MemberData\s*\(\s*(?:nameof\(\s*(\w+)\s*\)|"(\w+)")/g)) {
          const name = md[1] || md[2];
          const decl = new RegExp(String.raw`\b${name}\b\s*(?:=>|=|\{\s*get)`).exec(t.body);
          if (!decl) continue;
          const open = t.body.indexOf('{', decl.index + decl[0].length - 1);
          if (open < 0) continue;
          let depth = 0;
          let close = open;
          for (; close < t.body.length; close++) {
            if (t.body[close] === '{') depth++;
            else if (t.body[close] === '}' && --depth === 0) break;
          }
          // Rows are found on the blanked copy (a raw-string body holds braces) and read from the real one.
          const blanked = p.b.slice(t.start, t.end);
          const region = blanked.slice(open + 1, close);
          const before = rows.length;
          for (const x of region.matchAll(/\{\s*("[^"]*"[^{}]*)\}|\bAdd\(\s*("[^"]*"[^;]*?)\)\s*;/g)) {
            const from = open + 1 + x.index + x[0].indexOf(x[1] || x[2]);
            rows.push(splitArgs(t.body.slice(from, from + (x[1] || x[2]).length)));
          }
          // A one-column table, `new() { VmHubPath, ProgressHubPath }`: each entry is a row.
          if (rows.length === before && !/[{}();]/.test(region)) for (const v of splitArgs(t.body.slice(open + 1, close))) rows.push([v]);
        }
        const links = [...raw.matchAll(/\/\/\s*Gate:\s*(\S+)/g)].map((x) => x[1]);
        const dataRow = /\/\/\s*Data-row gate:\s*\S/.test(raw);
        const base = { file: rel(f), line: p.lineOf(m.start), cls: t.name, name: m.name, links, dataRow };
        if (rows.length) rows.forEach((row, k) => cases.push(makeCase(base, text, row, params, consts, helperExprs, k + 1)));
        else cases.push(makeCase(base, text, null, params, consts, helperExprs, 0));
      }
    }
  }

  // A literal, a concatenation of literals and other parts (each a hole), a constant, a theory parameter
  // or a helper the case's class declares, resolved to a route the gates' routes can match.
  function resolveUrl(expr, params, row, consts, helperExprs) {
    let e = expr.trim().replace(/\.Replace\s*\((?:[^()]|\([^()]*\))*\)/g, '');
    for (let k = 0; k < 3; k++) {
      let x;
      if ((x = /^string\.Format\(\s*([\s\S]*)\)$/.exec(e))) { e = splitArgs(x[1])[0] || ''; continue; }
      const parts = splitPlus(e);
      if (parts.length > 1) {
        e = '"' + parts.map((part) => {
          const v = resolveUrlPart(part, params, row, consts, helperExprs);
          return v === null ? '{}' : v;
        }).join('') + '"';
        continue;
      }
      if ((x = /^([A-Za-z_]\w*)$/.exec(e))) {
        const pi = params.indexOf(x[1]);
        if (row && pi >= 0 && row[pi] !== undefined) { e = row[pi]; continue; }
        if (consts.has(x[1])) { e = consts.get(x[1]); continue; }
        if (helperExprs.has(x[1])) { e = helperExprs.get(x[1]); continue; }
        return null;
      }
      if ((x = /^([A-Za-z_]\w*)\s*\(/.exec(e)) && helperExprs.has(x[1])) { e = helperExprs.get(x[1]); continue; }
      break;
    }
    const lit = /^\$?@?"([^"]*)"/.exec(e);
    if (!lit) return null;
    // Holes the case can fill: a constant, a theory parameter (from the row), a helper that returns a
    // literal (`$"{Route(id)}{suffix}"`). Anything else stays a hole.
    const fill = (all, inner) => {
      const id = inner.trim();
      if (consts.has(id)) return (/"([^"]*)"/.exec(consts.get(id)) || [, all])[1];
      const pi = params.indexOf(id);
      if (row && pi >= 0 && /^"[^"]*"$/.test(row[pi] || '')) return row[pi].slice(1, -1);
      const call = /^([A-Za-z_]\w*)\s*(\(|$)/.exec(id);
      if (call && helperExprs.has(call[1])) { const h = /"([^"]*)"/.exec(helperExprs.get(call[1])); if (h) return h[1]; }
      return all;
    };
    let s = lit[1].replace(/\{((?:[^{}]|\{[^{}]*\})*)\}/g, fill);
    s = s.replace(/\{((?:[^{}]|\{[^{}]*\})*)\}/g, fill);
    s = s.replace(/\{[^}]*\}/g, '{}');
    return /^\/?api\//i.test(s) || /^\/?hubs\//i.test(s) ? normRoute(s) : null;
  }
  function resolveUrlPart(part, params, row, consts, helperExprs) {
    const p = part.trim();
    const lit = /^\$?@?"([^"]*)"$/.exec(p);
    if (lit) return lit[1];
    let x;
    if ((x = /^([A-Za-z_]\w*)$/.exec(p))) {
      const pi = params.indexOf(x[1]);
      if (row && pi >= 0 && /^"[^"]*"$/.test(row[pi] || '')) return row[pi].slice(1, -1);
      if (consts.has(x[1])) return (/"([^"]*)"/.exec(consts.get(x[1])) || [])[1] ?? null;
      if (helperExprs.has(x[1])) return (/"([^"]*)"/.exec(helperExprs.get(x[1])) || [])[1] ?? null;
    }
    if ((x = /^([A-Za-z_]\w*)\s*\(/.exec(p)) && helperExprs.has(x[1])) return (/"([^"]*)"/.exec(helperExprs.get(x[1])) || [])[1] ?? null;
    return null;
  }
  function splitPlus(e) {
    const out = [];
    let depth = 0;
    let cur = '';
    let inStr = false;
    for (let k = 0; k < e.length; k++) {
      const c = e[k];
      if (inStr) { cur += c; if (c === '\\') { cur += e[++k] || ''; continue; } if (c === '"') inStr = false; continue; }
      if (c === '"') { inStr = true; cur += c; continue; }
      if ('([{'.includes(c)) depth++;
      if (')]}'.includes(c)) depth--;
      if (c === '+' && depth === 0) { out.push(cur); cur = ''; continue; }
      cur += c;
    }
    out.push(cur);
    return out.filter((x) => x.trim());
  }

  function makeCase(base, body, row, params, consts, helperExprs, k) {
    const text = body + (row ? '\n' + row.join(', ') : '');
    const calls = [];
    const unresolved = new Set();
    const verbOfRow = row ? row.map((v) => /^"([A-Za-z]+)"$/.exec(v)).filter((v) => v && VERBS.includes(v[1].toUpperCase())).map((v) => v[1].toUpperCase())[0] : null;
    for (const x of text.matchAll(/\.(Get|Post|Put|Delete|Patch)(?:AsJson|FromJson|StringAsync)?(?:Async)?\s*(?:<[^<>()]*>)?\s*\(/g)) {
      const from = x.index + x[0].length - 1;
      const first = splitArgs(text.slice(from + 1, closeParen(text, from)))[0] || '';
      const url = resolveUrl(first, params, row, consts, helperExprs);
      if (url) calls.push({ verb: x[1].toUpperCase(), url, at: x.index });
      else if (/^[A-Za-z_]\w*$/.test(first.trim())) unresolved.add(x[1].toUpperCase());
    }
    for (const x of text.matchAll(/new\s+HttpRequestMessage\s*\(/g)) {
      const from = x.index + x[0].length - 1;
      const [verbExpr, urlExpr] = splitArgs(text.slice(from + 1, closeParen(text, from)));
      if (!urlExpr) continue;
      let verb = (/HttpMethod\.(\w+)/.exec(verbExpr || '') || [])[1];
      if (!verb) {
        const lit = /"([A-Za-z]+)"/.exec(verbExpr || '');
        if (lit) verb = lit[1];
        else { const pi = params.indexOf((/\(\s*(\w+)\s*\)/.exec(verbExpr || '') || [])[1]); if (row && pi >= 0) verb = (row[pi] || '').replace(/"/g, ''); }
      }
      const url = resolveUrl(urlExpr, params, row, consts, helperExprs);
      if (url) calls.push({ verb: (verb || verbOfRow || '*').toUpperCase(), url, at: x.index });
    }
    // A url handed through a helper's parameter (`GetUsers(client) => GetUsers(client, Users)`): every
    // route-like literal and route constant the case mentions, with the verb of the call that took it.
    if (unresolved.size && !calls.length) {
      const urls = new Set();
      for (const x of text.matchAll(/\$?@?"(\/?api\/[^"]*)"/g)) urls.add(normRoute(x[1].replace(/\{[^}]*\}/g, '{}')));
      for (const [name] of consts) if (new RegExp(String.raw`\b${name}\b`).test(text)) { const u = resolveUrl(name, [], null, consts, helperExprs); if (u) urls.add(u); }
      for (const [name] of helperExprs) if (new RegExp(String.raw`\b${name}\s*\(`).test(text)) { const u = resolveUrl(`${name}()`, [], null, consts, helperExprs); if (u) urls.add(u); }
      for (const verb of unresolved) for (const url of urls) calls.push({ verb, url, at: -1 });
    }
    if (row && verbOfRow && !calls.length) {
      for (const v of row) { const url = resolveUrl(v, [], null, consts, helperExprs); if (url) calls.push({ verb: verbOfRow, url, at: -1 }); }
    }
    const denialRe = /\bHttpStatusCode\.Forbidden\b|\bForbiddenException\b|\bStatus403Forbidden\b|\bForbid\(\)|\b(?:AssertStatus|AssertProblem|AssertJsonError)\w*\s*(?:<[^<>()]*>)?\(\s*403\b/;
    const asserted = (x) => x.replace(/\bNotEqual\s*\(\s*HttpStatusCode\.\w+/g, '');
    const bodyDenies = denialRe.test(asserted(body));
    const rowDenies = row ? denialRe.test(row.join(',')) : false;
    const rowAllows = row ? /\bHttpStatusCode\.(OK|Created|NoContent|Accepted)\b|\btrue\b/.test(row.join(',')) : false;
    const legacyHubDenial = /DidNotReceive\(\)\s*\.\s*AddToGroupAsync|Assert\.(?:Empty|DoesNotContain)\([^;]*JoinedGroups/.test(body);
    // A Leave method joins nothing whoever calls it, so its tests are never denials by what they join.
    const hubDenial = legacyHubDenial && !/^Leave/i.test(base.name);
    const nameDenies = /(?:^|_)(?:leaves_out|does_not_join|does_not_add|is_not_added|excludes)(?:_|$)/.test(base.name) || /forbidden|Is403|_403(?:_|$)|(?:^|_)(?:is_)?denied(?:_|$)|(?:refuses|refused|denies|does_not_let|is_not_allowed_for)_(?:\w+?_){0,3}?(?:caller|member|user|actor|stranger|guest|observer|someone|anyone)s?(?:_|$)/i.test(base.name);
    // A `_does_not_let_a_caller_` test that asserts the caller was let in (`Assert.True(n.WasSuccess)`)
    // is about a sibling gate; it is not a denial (player.api's JoinTeam posting test).
    const admits = /\bAssert\.True\s*\([^;]*\b(?:WasSuccess|Succeeded|IsSuccess(?:StatusCode)?|Success)\b/.test(body);
    const legacyNamedDenial = !row && !calls.length && (legacyHubDenial || nameDenies);
    const namedDenial = !row && !calls.length && (hubDenial || (nameDenies && !admits));
    const statusDenial = rowDenies || (bodyDenies && !(row && rowAllows && !/\bHttpStatusCode\.Forbidden\b[\s\S]*\bHttpStatusCode\.Forbidden\b/.test(body) && !/Assert\w*\(\s*HttpStatusCode\.Forbidden/.test(body)));
    const denial = namedDenial || statusDenial;
    const legacyDenial = legacyNamedDenial || statusDenial;
    // A hub test refused only in what it joins or leaves: a near miss for a site whose permission the
    // caller does not hold.
    const hubOnlyDenial = namedDenial && hubDenial && !nameDenies;
    // A case that answers 5xx: never an allowed case, and never the other branch of a branch gate
    // (CONVENTIONS.md section 4: a characterized 500 leaves the gate to its allow-list line).
    const fiveRe = /\bHttpStatusCode\.InternalServerError\b|\bStatus500InternalServerError\b|\b(?:AssertStatus|AssertProblem|AssertJsonError)\w*\s*(?:<[^<>()]*>)?\(\s*500\b|\(HttpStatusCode\)\s*500\b/;
    const serverError = row
      ? fiveRe.test(row.join(',')) || (fiveRe.test(asserted(body)) && !/\bHttpStatusCode\.(?!InternalServerError\b)\w+/.test(row.join(',')))
      : fiveRe.test(asserted(body)) || /(?:^|_)(?:server_error|Is500|500)(?:_|$)|ServerError/.test(base.name);
    // Which request the denial is about: the statement asserting Forbidden that holds the call, or names
    // the variable the call's response went into. A denial test's control request is not denied; when no
    // statement can be told apart, every request of a denying case is.
    for (const call of calls) {
      if (call.at < 0) continue;
      const from = Math.max(text.lastIndexOf(';', call.at), text.lastIndexOf('{', call.at), text.lastIndexOf('}', call.at)) + 1;
      const end = text.indexOf(';', call.at);
      const stmt = text.slice(from, end < 0 ? text.length : end);
      if (denialRe.test(asserted(stmt))) { call.denied = true; continue; }
      const v = /^\s*(?:var|HttpResponseMessage)\s+(\w+)\s*=/.exec(stmt);
      if (v) {
        const rest = text.slice(end + 1);
        for (const st of rest.split(';')) if (new RegExp(String.raw`\b${v[1]}\b`).test(st) && denialRe.test(asserted(st))) { call.denied = true; break; }
      }
    }
    if (!calls.some((c) => c.denied)) for (const call of calls) call.denied = denial;
    // The caller: an identity the test names in its own body (an actor's client, a principal it builds, a
    // grant), or Root, including a helper that falls back to Root (`Service()` over `HostFor(user ?? Root)`)
    // and an actor holding every system permission that the test's requests all use.
    const own = body + (row ? '\n' + row.join(', ') : '');
    const otherIdentity = /\bClient\(\s*(?:await\s+)?(?!Root\b)[A-Za-z_]/.test(own) || /ClaimsPrincipalBuilder|\.Holding\(|\bGrant\(|\bHostFor\(\s*(?!Root\b)\w|\b(?:Service|Hub|Host|Harness)\(\s*(?!Root\b)[a-z_]\w*\s*[,)]/.test(own)
      || /\b(?:Allow|Grant)\w*\(/.test(own);
    const rootRe = /\bRootClient\b|\bClient\(\s*Root\s*\)|\bWithAllSystemPermissions\(\s*\)|\bRootHost\b|\?\?\s*Root\b|\bHostFor\(\s*Root\s*\)/;
    const legacyRoot = rootRe.test(text) && !otherIdentity;
    const allPermVars = new Set([...text.matchAll(/\b(?:var\s+)?(\w+)\s*=\s*await\s+Actor\(\)[^;]*\bWithAllSystemPermissions\(\s*\)/g)].map((x) => x[1]));
    const clientArgs = [...own.matchAll(/\bClient\(\s*(?:await\s+)?([A-Za-z_]\w*)/g)].map((x) => x[1]);
    const root = legacyRoot || (allPermVars.size > 0 && clientArgs.length > 0 && clientArgs.every((a) => a === 'Root' || allPermVars.has(a)));
    // A grant the case writes; a seeded id (`TestData.Permissions.CreateViews`) is not one.
    const grantText = text.replace(/\bHttpStatusCode\.\w+/g, '');
    const legacyGrant = /\b\w*(?:Permission|Role)s?\s*\.\s*[A-Z]\w*/.test(grantText) || /\.(?:On|In)[A-Z]\w*\s*\(|\.WithRole\s*\(|\.With\w*Permissions?\s*\(|\.Holding\s*\(|\bGrant\s*\(/.test(text)
      || (/\bClaimsPrincipalBuilder\b/.test(text) && /\.With(?!(?:Id|Name|UserId|Url|Database|Email|Scopes?|Issuer|Claim|Sub|AllSystemPermissions)\s*\()[A-Z]\w*\s*\(/.test(text));
    const grant = /\b\w*(?:Permission|Role)s?\s*\.\s*[A-Z]\w*/.test(grantText.replace(/\bTestData\s*\.\s*\w+\s*\.\s*\w+/g, '')) || /\.(?:On|In)[A-Z]\w*\s*\(|\.WithRole\s*\(|\.With\w*Permissions?\s*\(|\.Holding\s*\(|\bGrant\s*\(/.test(text)
      || (/\bClaimsPrincipalBuilder\b/.test(text) && /\.With(?!(?:Id|Name|UserId|Url|Database|Email|Scopes?|Issuer|Claim|Sub|AllSystemPermissions)\s*\()[A-Z]\w*\s*\(/.test(text));
    const permCount = new Set([...text.matchAll(PERMISSION_TOKEN)].map((y) => `${y[1]}.${y[2]}`)).size;
    const scope = /\bScopeHeader\b|X-Test-Scope/.test(text);
    const hubConnection = /\bHubConnectionBuilder\b/.test(text);
    const hubRefused = hubConnection && /\bThrows\w*Async\b|HttpStatusCode\.Unauthorized|\b401\b/.test(text) || (/negotiate/i.test(text) && /HttpStatusCode\.Unauthorized|\b401\b/.test(text));
    const hubPaths = [...text.matchAll(/"(\/?hubs\/[\w/-]+)"/gi)].map((x) => normRoute(x[1]));
    for (const [name, value] of consts) {
      const hub = /^\$?@?"(\/?hubs\/[\w/-]+)"$/i.exec(value);
      if (hub && new RegExp(String.raw`\b${name}\b`).test(text)) hubPaths.push(normRoute(hub[1]));
    }
    const mentionsApi = calls.some((x) => /^api\//.test(x.url)) || /"\/?api\//.test(text) || [...consts].some(([n, v]) => /^\$?@?"\/?api\//.test(v) && new RegExp(String.raw`\b${n}\b`).test(text));
    return { ...base, row: k, text, calls, unresolved, mentionsApi, denial, legacyDenial, hubOnlyDenial, serverError, admits, root, legacyRoot, grant, legacyGrant, permCount, scope, otherIdentity, anonymous: /\bClient\(\s*\)/.test(own) && !otherIdentity && !/\bUserHeader\b|X-Test-User/.test(text), hubConnection, hubRefused, hubPaths };
  }

  // Which cases reach a gate.
  const routeMatch = (call, route) => {
    if (call.verb !== '*' && call.verb !== route.verb) return -1;
    const cs = call.url.split('/');
    const rs = route.route.split('/');
    if (cs.length !== rs.length) return -1;
    let score = 0;
    for (let k = 0; k < cs.length; k++) {
      if (rs[k] === '{}') continue;
      if (cs[k] === rs[k]) { score++; continue; }
      // A test segment with a hole in it (`move-{direction}`) matches a literal it can produce.
      if (cs[k] !== '{}' && cs[k].includes('{}') && new RegExp(`^${cs[k].split('{}').map((x) => x.replace(/[.*+?^$()|[\]\\]/g, '\\$&')).join('.+')}$`).test(rs[k])) { score++; continue; }
      return -1;
    }
    return score;
  };
  const allRoutes = gates.filter((g) => g.reach).flatMap((g) => g.reach.routes.map((r) => ({ ...r, g })));
  // Routes with no gate still compete for a test's url, so `api/permissions/mine` is not read as
  // `api/permissions/{id}`.
  for (const p of parsed) {
    for (const t of p.types) {
      if (t.kind === 'type' && isController(t)) for (const m of t.members) for (const r of actionRoutes(t, m)) allRoutes.push({ ...r, g: null });
    }
    for (const x of p.a.matchAll(/\.Map(Get|Post|Put|Delete|Patch)\(\s*\$?"([^"]*)"/g)) allRoutes.push({ verb: x[1].toUpperCase(), route: joinRoute(groupPrefix, x[2]), g: null });
  }
  const routeHits = new Map();
  for (const c of cases) {
    c.routed = false;
    c.routedTo = [];
    for (const call of c.calls) {
      let best = -1;
      let hits = [];
      for (const r of allRoutes) {
        const s = routeMatch(call, r);
        if (s > best) { best = s; hits = [r]; } else if (s === best && s >= 0) hits.push(r);
      }
      if (best >= 0) { c.routed = true; c.routedTo.push(...hits); }
      for (const r of best >= 0 ? hits.filter((h) => h.g) : []) {
        if (!routeHits.has(r.g)) routeHits.set(r.g, new Map());
        const key = `${c.file}:${c.line}:${c.row}:${call.denied ? 'D' : 'A'}`;
        if (!routeHits.get(r.g).has(key)) routeHits.get(r.g).set(key, Object.assign(Object.create(c), { denial: call.denied, legacyDenial: call.denied || (c.legacyDenial && !c.calls.some((x) => x.denied)), how: 'route', route: r }));
      }
    }
  }
  const startsWithWord = (s, w) => s.toLowerCase().startsWith(w.toLowerCase()) && (s.length === w.length || s[w.length] === '_');
  const classMatches = (cls, stems) => [...stems].some((st) => st && cls.startsWith(st) && (cls.length === st.length || /[A-Z]/.test(cls[st.length])));
  function casesFor(g) {
    const out = new Map();
    for (const [k, c] of routeHits.has(g) ? routeHits.get(g) : []) out.set(k, c);
    for (const c of cases) {
      const key = `${c.file}:${c.line}:${c.row}`;
      const linked = c.links.filter((l) => l === g.id || g.sites.some((s) => s.id === l));
      if (linked.length) { out.set(key + ':L', Object.assign(Object.create(c), { how: 'link', linkedTo: linked })); continue; }
      if (g.hubConnection) {
        const p = g.path ? normRoute(g.path) : null;
        if ((c.hubConnection || /negotiate/i.test(c.text)) && ((p && c.hubPaths.includes(p)) || classMatches(c.cls, new Set([g.type])))) out.set(key, Object.assign(Object.create(c), { how: 'hub' }));
        continue;
      }
      // A case whose requests all resolved to routes is linked by them; one with a request the check
      // could not resolve is linked by name as well.
      if ((c.routed && !c.unresolved.size) || !g.reach) continue;
      const r = g.reach;
      if (!classMatches(c.cls, r.stems)) continue;
      const op = [...r.ops].some((o) => startsWithWord(c.name, o));
      // A call to the member; one named like an HttpClient method (`GetAsync`) counts only on a receiver
      // that is not a client.
      const call = [...r.calls].some((n) => (/^(?:Get|Post|Put|Delete|Patch|Send)Async$/.test(n)
        ? new RegExp(String.raw`(?<!\bClient\([^()]*\)|\b\w*[Cc]lient)\s*\.\s*${n}\s*(?:<[^<>()]*>)?\s*\(`).test(c.text) && !new RegExp(String.raw`\b(?:\w*[Cc]lient(?:\([^()]*\))?)\s*\.\s*${n}\s*\(`).test(c.text)
        : new RegExp(String.raw`\b${n}\s*(?:<[^<>()]*>)?\s*\(`).test(c.text)));
      if ((op || call) && !(c.routed && !c.unresolved.size)) out.set(key + ':N', Object.assign(Object.create(c), { how: 'name' }));
    }
    return [...out.values()];
  }

  const actorFile = path.join(testDir, 'Support', 'TestActor.cs');
  const builderEnums = new Set(fs.existsSync(actorFile) ? [...read(actorFile).matchAll(/\b(\w*Permission)\b/g)].map((x) => x[1]) : []);
  // The tests the defect document names (entries and "Needs a decision" items): an allow-list reason that
  // names one takes precedence over a credit, and a credit prefers a test no entry names.
  const app = appArg || path.basename(repo);
  const bugsFile = path.join(AGENT_DOCS, 'api-test-bugs', `${app}.md`);
  const entryNames = new Set();
  if (APPS.includes(app) && fs.existsSync(bugsFile)) {
    let section = '';
    for (const line of read(bugsFile).split('\n')) {
      const h2 = /^##\s+(.*?)\s*$/.exec(line);
      if (h2 && !/^###/.test(line)) { section = h2[1]; continue; }
      const h3 = /^###\s+(\w+)\s*$/.exec(line);
      if (h3 && !/^(Found without a test|Gaps noticed|Shared fix recipes)$/.test(section)) entryNames.add(h3[1]);
    }
  }
  // Allow-list.
  // The allow-list lives outside every repo, like the defect documents: agent-docs/api-test-gaps/<app>.txt.
  // An in-repo list is refused, so none gets committed by habit.
  const inRepo = path.join(testDir, 'untested-gates.txt');
  if (fs.existsSync(inRepo)) {
    problems.push(`  ALLOW    ${rel(inRepo)} is an in-repo allow-list, which the check never reads: move its lines to agent-docs/api-test-gaps/<app>.txt and delete the file`);
  }
  if (!APPS.includes(app)) {
    problems.push(`  USAGE    cannot tell the app from '${path.basename(repo)}'; pass it: check-repo.js gates <repo> <app> (one of ${APPS.join(', ')})`);
  }
  const allowFile = path.join(AGENT_DOCS, 'api-test-gaps', `${app}.txt`);
  const allowName = `agent-docs/api-test-gaps/${app}.txt`;
  const allowed = new Map();
  if (APPS.includes(app) && fs.existsSync(allowFile)) {
    read(allowFile).split('\n').forEach((line, i) => {
      const l = line.trim();
      if (!l || l.startsWith('//') || /^#\s/.test(l) || l === '#') return;
      const m = /^(\S+)\s+Reason:\s*(.*)$/.exec(l);
      const where = `${allowName}:${i + 1}`;
      if (!m || !m[2].trim()) { problems.push(`  ALLOW    ${where} an allow-list line is '<gate id> Reason: <why the harness cannot reach it>'`); return; }
      if (/\b(?:budget|out of time|no time|ran out|follow-?ups?|todo|not (?:yet )?written|not yet|next round|another round|later round|out of scope|deferred)\b/i.test(m[2])) {
        problems.push(`  ALLOW    ${where} ${m[1]}: '${m[2].trim()}' is not a reason; only what the harness cannot reach is (CONVENTIONS.md section 4)`);
      }
      const reason = m[2].trim();
      const prefix = (/^(Inert|Defect):/.exec(reason) || [])[1] || null;
      const names = [...reason.matchAll(/\b(?:[A-Z]\w*\.)?([A-Z]\w*_\w+|[A-Z][A-Za-z0-9]*_[A-Za-z0-9_]+)\b/g)].map((x) => x[1]).filter((n) => entryNames.has(n));
      if (prefix === 'Defect' && !names.length) notes.push(`  NOTE     defect reason: ${where} ${m[1]}: a 'Defect:' reason names no entry or "Needs a decision" item of agent-docs/api-test-bugs/${app}.md`);
      // A line whose reason says the verdict is inert, or names a defect entry's test, stands even where a
      // test is credited: the credit is then the defect's characterization, not a covering test.
      const precedence = prefix === 'Inert' ? 'Inert' : names.length ? `names the entry ${names[0]}` : null;
      allowed.set(m[1], { reason, where, used: false, precedence });
    });
  }

  // Credits per call site.
  const holdsFor = (s) => {
    const unnamed = (s.resourceEnums || []).filter((e) => !builderEnums.has(e));
    const implicitRe = unnamed.length ? new RegExp(String.raw`\.(?:On|OnNew|In)(?:${unnamed.map((e) => e.replace(/Permission$/, '')).join('|')})\w*\s*\(`) : null;
    const tokenRe = s.tokens.length ? new RegExp(String.raw`\b\w*(?:Permission|Role)s?\s*\.\s*(?:${s.tokens.join('|')})\b|"(?:${s.tokens.join('|')})"`) : null;
    const holdsTok = (c) => (tokenRe ? tokenRe.test(c.text) || (s.resourceTokens.length && MEMBERSHIP_ROLE.test(c.text)) || (implicitRe && implicitRe.test(c.text)) : false);
    return {
      tokenRe,
      holdsTok,
      strict: (c) => (tokenRe ? holdsTok(c) : c.grant || c.dataRow || c.otherIdentity),
      legacy: (c) => (tokenRe ? holdsTok(c) : c.legacyGrant || c.dataRow || c.otherIdentity),
      // Its family: a permission of one of the site's enums (another value, or the same one elsewhere).
      family: (c) => (s.enums && s.enums.length ? new RegExp(String.raw`\b(?:${s.enums.join('|')})s?\s*\.\s*[A-Z]\w*`).test(c.text) || holdsTok(c) : c.grant || c.dataRow),
    };
  };
  // Prefer, among credited cases, the one in the gate's own class, naming no defect entry, holding the
  // fewest permissions.
  const rank = (g) => (c) => [
    entryNames.has(c.name) ? 1 : 0,
    g.scope && !c.scope ? 1 : 0,
    c.how === 'name' ? 1 : 0,
    g.reach && classMatches(c.cls, g.reach.stems) ? 0 : 1,
    c.permCount,
  ];
  const best = (g, list, first) => {
    const r = rank(g);
    const key = (c) => (first ? [first(c), ...r(c)] : r(c));
    return [...list].sort((x, y) => { const a = key(x); const b = key(y); for (let k = 0; k < a.length; k++) if (a[k] !== b[k]) return a[k] - b[k]; return 0; })[0];
  };
  // How two call sites of one member combine, j before k: 'or' when either verdict admits (`!a && !b`
  // before a throw, `a || b`, `else if`, a flag both feed), so a caller passing j never reaches k and a
  // denial is a denial at both; 'and' when both must admit (`!a || !b`, `if (!a) throw; if (!b) throw;`),
  // so a caller reaching k passed j; 'exclusive' in the two branches of an `if` neither decides; 'none'.
  const negated = (s) => /!\s*\(?\s*(?:await\s+)?$/.test(s.before || '');
  // The operator joining the two operands, read at the parenthesis level where they part, and whether
  // the second operand is negated (`!(x != null && await B(...))` is negated).
  const opRel = (b, from, to) => {
    let d = 0;
    let minD = 0;
    let op = null;
    let opAt = -1;
    for (let i = from; i < to; i++) {
      const c = b[i];
      if (c === '(') d++;
      else if (c === ')') { d--; if (d < minD) { minD = d; op = null; } }
      else if ((c === '&' && b[i + 1] === '&') || (c === '|' && b[i + 1] === '|')) { if (d === minD) { op = c === '&' ? '&&' : '||'; opAt = i; } i++; }
    }
    if (!op) return 'none';
    const neg = /^\s*!/.test(b.slice(opAt + 2, to));
    return (op === '&&') === neg ? 'or' : 'and';
  };
  const ifCache = new Map();
  const ifsOf = (g) => {
    if (!ifCache.has(g)) {
      const b = g.p.b;
      const list = [];
      const re = /\bif\s*\(/g;
      re.lastIndex = g.m.start;
      for (let x; (x = re.exec(b)) && x.index < g.m.end;) {
        const open = x.index + x[0].length - 1;
        const close = closeParen(b, open);
        const then = stmtAt(b, close + 1);
        const e = /^\s*else\b/.exec(b.slice(then.to));
        list.push({ open, close, then, otherwise: e ? stmtAt(b, then.to + e[0].length) : null });
      }
      ifCache.set(g, list);
    }
    return ifCache.get(g);
  };
  const relation = (g, j, k) => {
    const b = g.p.b;
    const within = (x, r) => r && x > r.from && x < r.to;
    for (const f of ifsOf(g)) {
      const jc = j.at > f.open && j.at < f.close;
      const kc = k.at > f.open && k.at < f.close;
      if (jc && kc) return opRel(b, j.at, k.at);
      if (jc && within(k.at, f.then)) return negated(j) ? 'or' : 'and';
      if (jc && within(k.at, f.otherwise)) return negated(j) ? 'and' : 'or';
      if ((within(j.at, f.then) && within(k.at, f.otherwise)) || (within(j.at, f.otherwise) && within(k.at, f.then))) return 'exclusive';
    }
    if (j.use.stmtFrom === k.use.stmtFrom) return opRel(b, j.at, k.at);
    const kText = b.slice(k.use.stmtFrom, k.at);
    for (const v of j.use.vars) {
      const mm = new RegExp(String.raw`\b${v}\b`).exec(kText);
      if (mm) return opRel(b, k.use.stmtFrom + mm.index, k.at);
    }
    if ([...j.use.vars].some((v) => k.use.vars.has(v))) return 'or';
    // Both verdicts handed to one call (`GetAsync(id, hasPermission, viewAsAdmin, ct)`): the callee reads
    // the second where the first did not admit.
    const firstVar = [...j.use.vars][0];
    const secondVar = [...k.use.vars][0];
    if (firstVar && secondVar && j.use.passedOn && k.use.passedOn) {
      const body = b.slice(Math.max(j.at, k.at), g.m.end);
      for (const x of body.matchAll(/\b\w+\s*(?:<[^<>()]*>)?\s*\(/g)) {
        const open = Math.max(j.at, k.at) + x.index + x[0].length - 1;
        const args = b.slice(open + 1, closeParen(b, open));
        if (new RegExp(String.raw`\b${firstVar}\b`).test(args) && new RegExp(String.raw`\b${secondVar}\b`).test(args)) return 'or';
      }
    }
    if (j.use.refuses && j.use.stmtFrom < k.use.stmtFrom) return 'and';
    return 'none';
  };
  const upstreamOf = (g) => {
    const out = [];
    if (!g.reach) return out;
    for (const vm of g.reach.via) { const ug = memberGate.get(vm); if (ug && ug !== g) out.push(ug); }
    if (g.typeObj && isHandler(g.typeObj) && /^(HandleRequest|Handle)$/.test(g.name)) {
      for (const ug of gates) if (ug.typeObj === g.typeObj && ug.name === 'Authorize' && ug !== g) out.push(ug);
    }
    // A verdict an earlier member only passes on (`hasSystemPermission` handed to the service) refuses
    // nobody there: it is one operand of the gate it is passed to.
    return out.filter((ug) => ug.sites.some((s) => s.use && s.use.refuses && !(s.use.passedOn && !s.use.refusesHere)));
  };

  let covered = 0;
  let missing = 0;
  let listed = 0;
  let provisional = 0;
  let sitesTotal = 0;
  let membersTotal = 0;
  const out = [];
  const coveredLines = [];
  const provisionalLines = [];
  const caseName = (c) => `${c.cls}.${c.name}${c.row ? ` (row ${c.row})` : ''}`;
  const isMappedHubMember = (g) => !hubMaps.length || (g.typeObj && mappedHubs.has(g.typeObj));
  for (const g of gates) {
    const matchedAll = g.scope ? cases.map((c) => Object.assign(Object.create(c), { how: 'scope' })) : casesFor(g);
    if (!g.hubConnection && !g.scope && g.reach && !g.reach.routes.length && !g.reach.hubs.size && !g.reach.callers && !(g.typeObj && isHub(g.typeObj) && isMappedHubMember(g))) {
      notes.push(`  NOTE     unrouted: ${g.id} (line ${g.line}): no route, hub or caller reaches it, so it is not counted`);
      continue;
    }
    if (g.typeObj && isHub(g.typeObj) && !g.hubConnection && !isMappedHubMember(g)) {
      notes.push(`  NOTE     unrouted: ${g.id} (line ${g.line}): its hub class is not mapped (no MapHub), so it is not counted`);
      continue;
    }
    membersTotal++;
    const upstream = upstreamOf(g);
    const legacySiteNearMiss = g.hubConnection ? matchedAll.find((c) => c.hubRefused || (c.anonymous && /HttpStatusCode\.Unauthorized/.test(c.text)))
      : matchedAll.find((c) => c.legacyDenial && (c.legacyGrant || c.dataRow));
    for (const s of g.sites) {
      sitesTotal++;
      const matched = g.siteReach ? matchedAll.filter((c) => c.how !== 'route' || g.siteReach.get(s).routes.some((r) => c.route && r.verb === c.route.verb && r.route === c.route.route)) : matchedAll;
      const h = holdsFor(s);
      const linkedHere = (c) => c.how === 'link' && c.linkedTo.some((l) => l === s.id || (l === g.id && g.sites.length === 1) || l === g.id);
      // The check before 2026-10-09, kept for one round so a credit it accepted and this one does not is a
      // PROVISIONAL warning, not a new failure.
      let legacyOk;
      let legacyNear;
      if (g.hubConnection) {
        legacyOk = matched.find((c) => c.hubConnection && !c.hubRefused && !c.anonymous && !/UserHeader[^;]*\bRoot\.Id\b/.test(c.text));
        legacyNear = legacySiteNearMiss;
      } else if (g.scope) {
        legacyOk = legacyNear = undefined;
      } else {
        legacyOk = matched.find((c) => !c.legacyDenial && !c.legacyRoot && !c.anonymous && h.legacy(c));
        const legacyBranchMiss = s.legacyBranch && h.tokenRe && matched.find((c) => !c.legacyDenial && !c.legacyRoot && c.legacyGrant && !h.tokenRe.test(c.text));
        legacyNear = legacySiteNearMiss || legacyBranchMiss;
      }
      // This check.
      let ok;
      let near;
      let nearKind = 'near miss';
      const okAll = [];
      const why = [];
      if (g.hubConnection) {
        ok = best(g, matched.filter((c) => c.hubConnection && !c.hubRefused && !c.anonymous && !c.root && !/UserHeader[^;]*\bRoot\.Id\b/.test(c.text)));
        near = matched.find((c) => c.hubRefused || (c.anonymous && /HttpStatusCode\.Unauthorized/.test(c.text)));
        if (ok) okAll.push(ok);
      } else if (g.scope) {
        ok = best(g, cases.filter((c) => !c.denial && !c.root && !c.anonymous && (c.routed || c.mentionsApi) && c.grant && !c.serverError));
        near = best(g, cases.filter((c) => c.scope && (c.denial || /HttpStatusCode\.Unauthorized/.test(c.text)) && (g.scope !== 'filter' || c.mentionsApi)));
        if (ok) okAll.push(ok);
      } else {
        const peers = g.sites.filter((o) => o !== s);
        const rel = (o) => (o.k < s.k ? relation(g, o, s) : relation(g, s, o));
        const earlierOr = peers.filter((o) => o.k < s.k && rel(o) === 'or');
        const priorAnd = peers.filter((o) => o.k < s.k && rel(o) === 'and' && o.use.refuses);
        const group = peers.filter((o) => rel(o) === 'or');
        // Who reaches this call site: every gate on the way passed (a route's earlier gate, a handler's
        // Authorize before its HandleRequest), and every earlier refusing site of this member passed.
        const onRoute = (ug, c) => !c.route || !ug.reach || (ug.typeObj === g.typeObj && ug.name === 'Authorize' && isHandler(ug.typeObj)) || ug.reach.routes.some((r) => r.verb === c.route.verb && r.route === c.route.route);
        const passes = (c) => (c.how !== 'route' || upstream.filter((ug) => onRoute(ug, c)).every((ug) => ug.sites.some((u) => !u.use.refuses || holdsFor(u).strict(c))))
          && priorAnd.every((o) => holdsFor(o).strict(c));
        const allowedCases = matched.filter((c) => !c.denial && !c.root && !c.anonymous && !c.serverError && h.strict(c)
          && (linkedHere(c) || earlierOr.every((o) => !(o.tokens.length ? holdsFor(o).holdsTok(c) : false))));
        ok = best(g, allowedCases);
        for (const tok of s.tokens) {
          const one = best(g, allowedCases.filter((c) => new RegExp(String.raw`\b\w*(?:Permission|Role)s?\s*\.\s*${tok}\b|"${tok}"`).test(c.text)));
          if (one && !okAll.includes(one)) okAll.push(one);
        }
        if (ok && !okAll.includes(ok)) okAll.unshift(ok);
        const refusing = s.use.refuses;
        const branching = s.use.branch || s.legacyBranch;
        const refusalCases = refusing ? matched.filter((c) => c.denial && !c.root && !c.scope && (c.grant || c.dataRow)
          && (linkedHere(c) || (passes(c)
            
            && !(s.use.inLoop)
            && (group.length === 0 || h.family(c))))) : [];
        const outsideGroup = (c) => s.use.solo || group.every((o) => !o.tokens.length || !holdsFor(o).holdsTok(c));
        // The other branch of a branch gate: a granted caller without the site's permission, answered 2xx
        // (a 2xx passed every gate on the way); for a site naming no permission, a test named for what the
        // branch leaves out; and a test of a service or hub method that is refused without a status
        // (`_leaves_out_`, `DidNotReceive().AddToGroupAsync`), which is that branch too.
        const branchCases = !branching ? [] : [
          ...(h.tokenRe ? matched.filter((c) => !c.denial && !c.root && !c.anonymous && !c.serverError && c.grant && !h.tokenRe.test(c.text) && (linkedHere(c) || outsideGroup(c)))
            : matched.filter((c) => !c.denial && !c.root && !c.anonymous && !c.serverError && (c.grant || c.dataRow) && /(?:^|_)(?:leaves_out|excludes|omits|hides|masks|only)(?:_|$)/.test(c.name))),
          ...(!refusing ? matched.filter((c) => c.denial && !c.calls.length && !c.root && !c.scope && (c.grant || c.dataRow) && (linkedHere(c) || outsideGroup(c))) : []),
        ];
        // Among near misses, one holding a permission of this site's own family names the site best.
        near = best(g, refusalCases, (c) => (s.enums && s.enums.length && h.family(c) ? 0 : 1));
        if (!near && branchCases.length) { near = best(g, branchCases); nearKind = 'other branch'; }
        if (!near && legacyNear) {
          if (legacyNear.root) why.push('its near miss is Root');
          else if (legacyNear.scope) why.push('its near miss is a scope test, refused by the default policy');
          else if (s.use.inLoop && legacyNear.denial) why.push('the call site is inside a loop: link a near miss that enters it with // Gate: ' + s.id);
          else if (legacyNear.how === 'route' && !passes(legacyNear)) why.push(`its near miss ${caseName(legacyNear)} is refused by an earlier gate on the way (${upstream.filter((ug) => onRoute(ug, legacyNear)).map((u) => u.id).concat(priorAnd.map((o) => o.id)).join(', ') || 'another call site'})`);
          else if (!refusing && legacyNear.denial) why.push(`the call site refuses nobody (a branch gate), so a 403 on its route comes from another gate; its other branch needs ${s.tokens.length ? `a granted caller without ${s.tokens.join(' or ')} who is answered 2xx` : 'a granted caller the branch leaves out'}`);
          else if (legacyNear.admits) why.push(`its near miss ${caseName(legacyNear)} asserts the caller was let in`);
          else if (group.length && !h.family(legacyNear)) why.push(`its near miss holds no permission of this call site's family (${s.enums.join(', ')})`);
          else why.push(`no near miss that reaches this call site (the credit was ${caseName(legacyNear)})`);
        }
        if (!ok && legacyOk) {
          if (legacyOk.serverError) why.push(`its allowed case ${caseName(legacyOk)} answers 5xx`);
          else if (legacyOk.root) why.push('its allowed case acts with every system permission');
          else if (earlierOr.some((o) => o.tokens.length && holdsFor(o).holdsTok(legacyOk))) why.push(`its allowed case ${caseName(legacyOk)} holds an earlier call site's permission, so it never reaches this one`);
          else why.push(`no allowed case that reaches this call site (the credit was ${caseName(legacyOk)})`);
        }
      }
      const lacks = [];
      if (!ok) lacks.push(g.hubConnection ? 'no test connecting an actor over a real HubConnection'
        : g.scope ? 'no allowed request with the configured scopes'
        : `no allowed case without Root${s.tokens.length ? ` holding ${s.tokens.join(' or ')}` : ' (an actor with a grant)'}`);
      if (!near) lacks.push(g.hubConnection ? 'no test that refuses a caller with no identity' : g.scope ? `no request refused for a token without a configured scope (TestAuthHandler.ScopeHeader)${g.scope === 'filter' ? ' on a controller route' : ''}` : 'no near-miss denied case');
      const allow = allowed.get(s.id) || allowed.get(g.id);
      if (allow) allow.used = true;
      const credit = () => {
        const extra = okAll.filter((c) => c !== ok);
        const tiers = s.systemTokens && s.systemTokens.length && s.resourceTokens && s.resourceTokens.length && !g.hubConnection && !g.scope
          ? (() => {
            const den = matched.filter((c) => c.denial && !c.root && !c.scope && (c.grant || c.dataRow));
            const sys = den.find((c) => /\bSystem\w*Permissions?\s*\.\s*[A-Z]\w*|\.WithSystemPermissions\s*\(/.test(c.text));
            const res = den.find((c) => new RegExp(String.raw`\b(?:${s.resourceEnums.join('|')})s?\s*\.\s*[A-Z]\w*`).test(c.text) || MEMBERSHIP_ROLE.test(c.text));
            return `; tiers: system ${sys ? caseName(sys) : 'none'}, resource ${res ? caseName(res) : 'none'}`;
          })() : '';
        return `allowed ${ok ? caseName(ok) : 'none'}${extra.length ? ` (also ${extra.map(caseName).join(', ')})` : ''}; ${near ? `${nearKind} ${caseName(near)}` : 'near miss none'}${tiers}`;
      };
      if (allow && allow.precedence) {
        listed++;
        out.push(`  ALLOWED  ${s.id} (line ${s.line}): ${lacks.length ? lacks.join('; ') : 'credited, but the allow-list line takes precedence'}. Reason: ${allow.reason}`);
        if (!lacks.length) coveredLines.push(`  LISTED   ${s.id}: ${credit()} (the allow-list line ${allow.precedence === 'Inert' ? "says 'Inert:'" : allow.precedence}, so it stands)`);
        continue;
      }
      if (!lacks.length) {
        covered++;
        coveredLines.push(`  COVERED  ${s.id}: ${credit()}`);
        if (allow) notes.push(`  NOTE     covered now: ${allow.where} ${s.id} is covered now; delete its allow-list line (or, if the credited test characterizes a defect, name its entry or start the reason with 'Inert:')`);
        continue;
      }
      if (allow) { listed++; out.push(`  ALLOWED  ${s.id} (line ${s.line}): ${lacks.join('; ')}. Reason: ${allow.reason}`); continue; }
      const routes = g.reach && g.reach.routes.length ? ` ${[...new Set(g.reach.routes.map((r) => `${r.verb} ${r.route}`))].join(', ')}` : g.hubConnection ? ` ${g.path || g.type}` : '';
      const legacyCovered = !g.scope && legacyOk && legacyNear;
      // Every provisional marker above dates from the 2026-10-09 version (newly inventoried shapes, and the
      // credits the check stopped accepting then, legacyCovered). It warned for that one version; from
      // 2026-10-12 such a gate is missing. A later tightening dates its own markers and warns for one version.
      const earlier = s.provisional || legacyCovered ? (s.provisional && !legacyCovered ? `newly inventoried in 2026-10-09 (${s.provisional})` : 'credited only by a test the 2026-10-09 check stopped accepting') : null;
      if (earlier && PROVISIONAL_SINCE === STANDARD_VERSION) {
        provisional++;
        provisionalLines.push(`  PROVISIONAL ${s.id} (line ${s.line}) [${s.kind}${s.tokens.length ? ': ' + s.tokens.join(', ') : ''}]${routes}: ${s.provisional && !legacyCovered ? `newly inventoried (${s.provisional}); ` : ''}${lacks.join('; ')}${why.length ? ` (${why.join('; ')})` : ''}`);
        continue;
      }
      missing++;
      problems.push(`  GATE     missing: ${s.id} (line ${s.line}) [${s.kind}${s.tokens.length ? ': ' + s.tokens.join(', ') : ''}]${routes}: ${lacks.join('; ')}${why.length ? ` (${why.join('; ')})` : ''}${matched.length && !g.scope ? ` (${matched.length} matching test case${matched.length > 1 ? 's' : ''})` : g.scope ? '' : ' (no test reaches it)'}${earlier ? `; provisional in the 2026-10-09 version (${earlier}), missing from ${STANDARD_VERSION}` : ''}`);
    }
  }
  for (const [id, a] of allowed) if (!a.used) {
    notes.push(`  NOTE     stale: ${a.where} '${id}' names no gate the check inventories (moved or renamed? check-repo.js gates prints every id; delete or correct the line)`);
  }
  if (flags.includes('--covered')) coveredLines.forEach((l) => console.log(l));
  out.forEach((l) => console.log(l));
  provisionalLines.forEach((l) => warnings.push(l.replace(/^  PROVISIONAL /, '  WARN     provisional: ')));
  trailer.push(`  (gates: ${sitesTotal} call sites in ${membersTotal} members, ${covered} covered, ${listed} allow-listed, ${missing} missing, ${provisional} provisional)`);
}

// ---------------------------------------------------------------------------------------------------------
// removed: no test lost without an account (CONVENTIONS.md section 2, "Removing or replacing a test").
// Removed tests (testing/README.md, "Removed-test accounting"). Every [Fact]/[Theory] method, and every
// [InlineData] row of a kept theory, that the diff base had and the tree no longer has is accounted for:
//   - by the script, when the match is mechanical: the method moved (the same name in its renamed file, the
//     same class and name anywhere, or the same name with an identical body in another class); it was
//     renamed with an identical body in the same class; the rows a theory lost are rows of another
//     theory of the class with an identical body; or each lost row is still a row of the theory with
//     arguments added after its own. Without --base these lines are written to
//     agent-docs/api-test-bugs/<app>.removed-tests-matched.md (regenerated; never edited by hand);
//   - otherwise by a line in agent-docs/api-test-bugs/<app>.removed-tests-<date>.md: A renamed or
//     rewritten, B merged, C replaced by a behaviour test (each naming a test that exists), D dropped with
//     the reason that makes it unreachable, E removed with the production file it tested (the file is gone).
// A removal neither accounts for, or whose line names no test that exists or gives no reason, fails.

// The test methods of one C# source: { cls, name, rows[], line, attr, body } per [Fact]/[Theory]; rows and
// the body (comments blanked, whitespace collapsed) normalized.
function testMethodsOf(src) {
  const out = [];
  const p = parseCs(src);
  for (const t of p.types) {
    if (t.kind !== 'type') continue;
    for (const m of t.members) {
      const attr = /\[\s*(Fact|Theory)\b/.exec(m.header);
      if (!attr) continue;
      const rows = [...m.header.matchAll(/\[\s*InlineData\s*\(/g)].map((x) => {
        const from = x.index + x[0].length - 1;
        return splitArgs(m.header.slice(from + 1, closeParen(m.header, from))).join(', ').replace(/\s+/g, ' ');
      });
      out.push({ cls: t.name, name: m.name, rows, line: p.lineOf(m.start), attr: attr[1], body: (m.body || '').replace(/\s+/g, ' ').trim() });
    }
  }
  return out;
}

function checkRemoved() {
  const { execFileSync } = require('child_process');
  const git = (...a) => execFileSync('git', ['-C', repo, ...a], { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024, stdio: ['ignore', 'pipe', 'ignore'] });
  const app = appArg || path.basename(repo);
  if (!APPS.includes(app)) {
    problems.push(`  USAGE    cannot tell the app from '${path.basename(repo)}'; pass it: check-repo.js removed <repo> <app> [--base <ref>]`);
    return;
  }
  const baseRef = baseArg || 'origin/main';
  let base;
  try {
    git('rev-parse', '--verify', '-q', `${baseRef}^{commit}`);
    base = git('merge-base', 'HEAD', baseRef).trim();
  } catch {
    problems.push(`  REMOVED  no diff base '${baseRef}' in ${repo}; nothing compared (fetch it, or pass --base <ref>)`);
    return;
  }
  const bugsDir = path.join(AGENT_DOCS, 'api-test-bugs');
  // The test projects at the base: every directory holding a *.Tests.csproj there.
  const baseFiles = git('ls-tree', '-r', '--name-only', base).split('\n').filter(Boolean);
  const baseFileSet = new Set(baseFiles);
  const baseTestDirs = baseFiles.filter((f) => /\.Tests\.csproj$/.test(f)).map((f) => path.posix.dirname(f));
  const testRel = rel(testDir).split(path.sep).join('/');
  if (!baseTestDirs.includes(testRel)) baseTestDirs.push(testRel);
  const inTests = (f) => f.endsWith('.cs') && baseTestDirs.some((d) => d === '.' || f.startsWith(d + '/')) && !/\/(bin|obj)\//.test(f);
  const renamed = new Map();
  for (const line of git('diff', '-M', '--name-status', base, '--', ...baseTestDirs).split('\n')) {
    const r = /^R\d*\t(.+)\t(.+)$/.exec(line);
    if (r) renamed.set(r[1], r[2]);
  }
  const tree = [];
  for (const f of sources) tree.push(...testMethodsOf(read(f)).map((m) => ({ ...m, file: rel(f).split(path.sep).join('/') })));
  const byClassName = new Map();
  const byFileName = new Map();
  const names = new Set();
  const push = (map, key, v) => map.set(key, (map.get(key) || []).concat(v));
  for (const m of tree) {
    push(byClassName, `${m.cls}.${m.name}`, m);
    push(byFileName, `${m.file}#${m.name}`, m);
    names.add(m.name);
    names.add(`${m.cls}.${m.name}`);
  }
  const removed = [];
  const baseKeys = new Set();
  let baseCount = 0;
  const baseMethods = [];
  for (const f of baseFiles.filter(inTests)) {
    let src;
    try { src = git('show', `${base}:${f}`); } catch { continue; }
    for (const m of testMethodsOf(src)) baseMethods.push({ ...m, file: f });
  }
  for (const m of baseMethods) baseKeys.add(`${m.cls}.${m.name}`);
  // Tests whose class and name the base did not have: the only candidates for a rename.
  const added = tree.filter((m) => !baseKeys.has(`${m.cls}.${m.name}`));
  const matched = [];
  for (const m of baseMethods) {
    baseCount++;
    const target = renamed.get(m.file) || m.file;
    const kept = byFileName.get(`${target}#${m.name}`) || byFileName.get(`${m.file}#${m.name}`) || byClassName.get(`${m.cls}.${m.name}`);
    if (!kept) {
      // Mechanical: the same name with an identical body in another class (moved), or a new name with an
      // identical body in the same class (renamed). Theories keep every row.
      const sameBody = (c) => c.body && c.body === m.body && c.attr === m.attr && m.rows.every((r) => c.rows.includes(r));
      const moved = tree.find((c) => c.name === m.name && c.cls !== m.cls && sameBody(c));
      const renamedTo = moved ? null : added.filter((c) => c.cls === m.cls && sameBody(c));
      if (moved) matched.push({ ...m, letter: 'A', to: `${moved.cls}.${moved.name}`, why: 'moved to another class; identical body' });
      else if (renamedTo.length === 1) matched.push({ ...m, letter: 'A', to: `${renamedTo[0].cls}.${renamedTo[0].name}`, why: 'renamed; identical body' });
      else removed.push({ ...m, kind: 'method' });
      continue;
    }
    const now = new Set(kept.flatMap((k) => k.rows));
    const lost = m.rows.filter((r) => !now.has(r));
    if (!lost.length) continue;
    // Mechanical: every lost row is still a row of the theory, with arguments added after its own.
    if (lost.every((r) => [...now].some((x) => x.startsWith(`${r}, `)))) {
      matched.push({ ...m, kind: 'rows', lost, letter: 'A', to: `${kept[0].cls}.${kept[0].name}`, why: `${lost.length} row${lost.length > 1 ? 's' : ''} kept with an argument added` });
      continue;
    }
    // Mechanical: every lost row is a row of another theory of the class with an identical body.
    const into = tree.find((c) => c.cls === m.cls && c.name !== m.name && c.attr === 'Theory' && c.body === m.body && lost.every((r) => c.rows.includes(r)));
    if (into) matched.push({ ...m, kind: 'rows', lost, letter: 'B', to: `${into.cls}.${into.name}`, why: `${lost.length} row${lost.length > 1 ? 's' : ''} merged into a theory with an identical body` });
    else removed.push({ ...m, kind: 'rows', lost });
  }
  // The script's own lines, regenerated on a run against the default base.
  const matchedName = `${app}.removed-tests-matched.md`;
  const matchedFile = path.join(bugsDir, matchedName);
  if (!baseArg && !flags.includes('--no-write')) {
    if (matched.length) {
      const byFile = new Map();
      for (const x of matched) push(byFile, x.file, x);
      const text = [
        `# ${app}: removed tests matched by the script`,
        '',
        `Written by \`check-repo.js removed\` against the merge base with origin/main (${base.slice(0, 8)}); regenerated on every run without \`--base\`, so never edit it: judged lines go in the dated accounting file beside it (testing/README.md, "Removed-test accounting"). ${matched.length} matched.`,
        '',
        ...[...byFile].sort(([a], [b]) => (a < b ? -1 : 1)).flatMap(([f, xs]) => [`## ${f}`, '', ...xs.map((x) => `- \`${x.cls}.${x.name}\`${x.kind === 'rows' ? ` (rows ${x.lost.map((r) => `\`(${r})\``).join(', ')})` : ''} -> ${x.letter} -> \`${x.to}\` (${x.why})`), '']),
      ].join('\n');
      if (!fs.existsSync(matchedFile) || read(matchedFile) !== text) fs.writeFileSync(matchedFile, text);
    } else if (fs.existsSync(matchedFile)) fs.unlinkSync(matchedFile);
  }
  // The judged accounting: every line naming an old test with its disposition.
  const docs = fs.readdirSync(bugsDir).filter((n) => n.startsWith(`${app}.removed-tests-`) && n.endsWith('.md') && n !== matchedName).sort();
  const accounted = new Map();
  const REJECTED = /\b(?:trivial(?:ly)?|budget|out of time|no time|ran out|later|follow-?ups?|not worth)\b/i;
  for (const doc of docs) {
    read(path.join(bugsDir, doc)).split('\n').forEach((line, i) => {
      const d = /->\s*\**([A-E])\b\**/.exec(line);
      if (!d) return;
      const where = `agent-docs/api-test-bugs/${doc}:${i + 1}`;
      const before = line.slice(0, d.index);
      const after = line.slice(d.index + d[0].length);
      // A name in backticks, with or without a folder or file (`Support/DatabaseHarnessTests.Uses_...`,
      // `Unit/Foo.cs` `Bar`), and `{A,B}_suffix` brace groups expanded.
      const namesIn = (text) => [...text.matchAll(/`([^`]+)`/g)].flatMap((x) => {
        const t = x[1].trim().replace(/\(.*$/, '').replace(/^.*\//, '').replace(/\.cs\b\s*/, ' ').trim().split(/\s+/).pop() || '';
        const brace = /^(.*)\{([^{}]+)\}(.*)$/.exec(t);
        const all = brace ? brace[2].split(',').map((v) => `${brace[1]}${v.trim()}${brace[3]}`) : [t];
        return all.filter((n) => /^(?:\w+\.)?\w+$/.test(n));
      });
      const olds = namesIn(before).map((n) => { const k = n.split('.'); return { cls: k.length > 1 ? k[0] : null, name: k[k.length - 1] }; });
      let ok = true;
      let why = '';
      if (d[1] === 'D') {
        if (!/^\s*->/.test(after)) notes.push(`  NOTE     accounting: ${where} a D line is \`- \\\`Old\\\` -> D -> <reason>\``);
        const reason = after.replace(/^[\s:,(-]*(?:->)?[\s:,(-]*(?:dropped)?[\s:,-]*/i, '').trim();
        if (reason.length < 12) { ok = false; why = 'a D line gives the reason (the unreachable branch or dead code it read in production)'; }
        else if (REJECTED.test(reason)) { ok = false; why = `'${reason.slice(0, 60)}' is not a reason (budget, time, "trivial" and a follow-up are not; name the unreachable branch or the dead code)`; }
      } else if (d[1] === 'E') {
        const files = [...after.matchAll(/`([^`]+\.(?:cs|cshtml|json))`/g)].map((x) => x[1]);
        if (!files.some((p) => baseFileSet.has(p) && !fs.existsSync(path.join(repo, p)))) { ok = false; why = 'an E line names the production file it tested, which the base had and the tree has not'; }
      } else if (!namesIn(after).some((n) => names.has(n) || names.has(n.split('.').pop()))) {
        ok = false; why = `an ${d[1]} line names the test that replaces it, and none it names exists in the tree`;
      }
      for (const o of olds) {
        const key = o.cls ? `${o.cls}.${o.name}` : o.name;
        if (!accounted.has(key) || ok) accounted.set(key, { ok, why, where, disposition: d[1], text: line.trim() });
      }
    });
  }
  let unaccounted = 0;
  let invalid = 0;
  const tally = { A: 0, B: 0, C: 0, D: 0, E: 0 };
  for (const r of removed) {
    const a = accounted.get(`${r.cls}.${r.name}`) || accounted.get(r.name);
    const what = r.kind === 'rows' ? `${r.cls}.${r.name}: ${r.lost.length} [InlineData] row${r.lost.length > 1 ? 's' : ''} removed (${r.lost.slice(0, 2).map((x) => `(${x})`).join(', ')}${r.lost.length > 2 ? ', ...' : ''})` : `${r.cls}.${r.name}`;
    if (!a) { unaccounted++; problems.push(`  REMOVED  ${r.file}:${r.line} ${what} has no line in agent-docs/api-test-bugs/${app}.removed-tests-<date>.md (\`- \\\`${r.name}\\\` -> A|B|C -> \\\`<new test>\\\`\`, \`-> D -> <reason>\` or \`-> E -> \\\`<deleted file>\\\`\`)`); continue; }
    if (!a.ok) { invalid++; problems.push(`  REMOVED  ${a.where} ${what}: ${a.why}`); continue; }
    tally[a.disposition]++;
    if (a.disposition === 'D' && flags.includes('--d-lines')) trailer.push(`  D-LINE   ${a.where}: ${a.text}`);
  }
  const methodsRemoved = [...removed, ...matched].filter((r) => r.kind !== 'rows').length;
  const rowsLosing = [...removed, ...matched].filter((r) => r.kind === 'rows').length;
  trailer.push(`  (removed: ${methodsRemoved} of ${baseCount} test methods at ${baseRef} (${base.slice(0, 8)}), ${rowsLosing} theories losing rows; tree ${tree.length} test methods, ${added.length} added; ${matched.length} matched by the script, ${removed.length - unaccounted - invalid} accounted (A ${tally.A}, B ${tally.B}, C ${tally.C}, D ${tally.D}, E ${tally.E}), ${unaccounted + invalid} unaccounted (${invalid} with an invalid line); accounting: ${[...docs, ...(matched.length && fs.existsSync(matchedFile) ? [matchedName] : [])].join(', ') || 'none'})`);
}

if (mode === 'harness') checkHarness();
else if (mode === 'tests') checkTests();
else if (mode === 'gates') checkGates();
else if (mode === 'removed') checkRemoved();
else checkDefects();
problems.forEach((p) => console.log(p));
warnings.forEach((w) => console.log(w));
notes.forEach((n) => console.log(n));
trailer.forEach((t) => console.log(t));
process.exit(problems.length || (strict && warnings.length) ? 1 : 0);
