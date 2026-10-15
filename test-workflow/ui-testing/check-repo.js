#!/usr/bin/env node
// Structural checks of one Crucible UI repo against the standard, run by
// sync.sh (helpers) and verify.sh (specs, gates, removed). Uses the repo's own
// TypeScript.
//
//   node check-repo.js helpers <repo>   app-specific helpers vs their templates,
//                                       extra test-utils files and setupFiles
//   node check-repo.js specs <repo> [--app <app>]
//                                       spec patterns the standard replaced,
//                                       defect notes in spec comments; NOTE
//                                       lines for defect entries whose test
//                                       (by spec file and test name) is not
//                                       there
//   node check-repo.js gates <repo> [--app <app>] [--list]
//                                       every component and unit has a spec
//                                       beside it; every file that reads a
//                                       permission has a spec with a denied
//                                       case, and every input bound from a
//                                       parent's permission one too (--list
//                                       also prints the gates of every gated
//                                       file and the denied test that names
//                                       each); missing ones fail, provisional
//                                       ones (GLOSSARY.md) are WARN lines
//   node check-repo.js removed <repo> [--base <ref>] [--app <app>] [--no-write]
//                                       every test title removed since the
//                                       merge base with origin/main (or
//                                       --base) is accounted for: by the
//                                       script when the match is mechanical
//                                       (written, without --base, to
//                                       agent-docs/ui-test-bugs/<app>.removed-tests-matched.md),
//                                       otherwise by a valid line in
//                                       agent-docs/ui-test-bugs/<app>.removed-tests-<date>.md
//
// --app names the app for the files outside the repo (agent-docs/ui-test-gaps,
// agent-docs/ui-test-bugs); the default is the repo folder's name. --strict
// makes WARN lines (provisional gates) fail too.
//
// Prints one line per problem and exits 1 if there are any. WARN lines
// (provisional gates) and NOTE lines (bookkeeping and reviewer input) follow;
// NOTE lines never change the exit code (testing/README.md, "Check output").
'use strict';
// The standard version this script belongs to (testing/CHANGELOG.md). A check
// tightened in a version reports what it newly refuses as provisional for that
// version only (GLOSSARY.md). Nothing in this script is provisional in
// 2026-10-12: the 2026-10-09 WARN checks (units without a spec, DERIVED,
// WEAKDENY) report missing gates now.
const STANDARD_VERSION = '2026-10-12';
const PROVISIONAL = new Set(); // tags provisional in STANDARD_VERSION
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const MODES = ['helpers', 'specs', 'gates', 'removed'];
const usage = () => {
  console.error(
    'usage: check-repo.js helpers|specs|gates|removed <repo> [--app <app>] [--list] [--base <ref>] [--no-write] [--d-lines] [--strict]',
  );
  process.exit(2);
};
const argv = process.argv.slice(2);
const mode = argv[0];
const opts = { app: null, base: 'origin/main', baseGiven: false, list: false, strict: false, write: true };
let repoArg = null;
for (let i = 1; i < argv.length; i++) {
  const a = argv[i];
  const valued = /^--(app|base)(?:=(.*))?$/.exec(a);
  if (valued) {
    const v = valued[2] ?? argv[++i];
    if (!v || v.startsWith('-')) {
      console.error(`check-repo.js: --${valued[1]} needs a value`);
      usage();
    }
    opts[valued[1]] = v;
    if (valued[1] === 'base') opts.baseGiven = true;
  } else if (a === '--list') opts.list = true;
  else if (a === '--no-write') opts.write = false;
  else if (a === '--d-lines') opts.dLines = true;
  else if (a === '--strict') opts.strict = true;
  else if (a.startsWith('-')) {
    console.error(`check-repo.js: unknown option ${a}`);
    usage();
  } else if (!repoArg) repoArg = a;
  else {
    console.error(`check-repo.js: unexpected argument ${a}`);
    usage();
  }
}
if (!MODES.includes(mode) || !repoArg) usage();
const repo = path.resolve(repoArg);
const standard = __dirname;
let ts;
try {
  ts = require(path.join(repo, 'node_modules/typescript'));
} catch {
  console.log(
    '  ERROR    no node_modules/typescript in the repo (npm ci first)',
  );
  process.exit(1);
}
const problems = [];
const warnings = []; // WARN lines (provisional gates): reported, fatal only with --strict
const notes = []; // NOTE lines: bookkeeping and reviewer input, never fatal
const trailer = []; // notes and summaries, printed after the problems
// The app name for the files kept outside the repo, like ui-test-bugs/<app>.md.
const app = opts.app ?? path.basename(repo);
if (!/^[\w.-]+$/.test(app)) {
  console.error(`check-repo.js: --app ${app} is not an app name`);
  process.exit(2);
}
// The workspace docs (defect docs, allow-lists, test-work/): on the /mnt/data volume, never in the checkout
// this script runs from. CRUCIBLE_ROOT overrides /mnt/data/crucible.
const AGENT_DOCS = path.join(process.env.CRUCIBLE_ROOT || '/mnt/data/crucible', 'agent-docs');
if (
  !opts.app &&
  ['gates', 'removed'].includes(mode) &&
  !fs.existsSync(path.join(AGENT_DOCS, 'ui-test-bugs', `${app}.md`))
) {
  trailer.push(
    `  NOTE     --app not given and agent-docs/ui-test-bugs/${app}.md does not exist; the files outside the repo are looked up as "${app}" (pass --app <app> for a scratch copy)`,
  );
}
const read = (f) => fs.readFileSync(f, 'utf8');
const parse = (f) =>
  ts.createSourceFile(f, read(f), ts.ScriptTarget.Latest, true);
const rel = (f) => path.relative(repo, f);
const lineOf = (src, node) =>
  src.getLineAndCharacterOfPosition(node.getStart(src)).line + 1;
const walk = (node, visit) => {
  visit(node);
  ts.forEachChild(node, (child) => walk(child, visit));
};
const files = (dir, keep, out = []) => {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name !== 'node_modules') files(p, keep, out);
    } else if (keep(p)) out.push(p);
  }
  return out;
};
const unwrap = (e) => {
  while (
    e &&
    (ts.isParenthesizedExpression(e) ||
      ts.isAsExpression(e) ||
      ts.isSatisfiesExpression(e))
  ) {
    e = e.expression;
  }
  return e;
};
const variables = (src) => {
  const map = new Map();
  walk(src, (n) => {
    if (ts.isVariableDeclaration(n) && ts.isIdentifier(n.name)) {
      map.set(n.name.text, n);
    }
  });
  return map;
};
const prop = (obj, name, src) =>
  obj.properties.find(
    (p) => ts.isPropertyAssignment(p) && p.name.getText(src) === name,
  );

// --- helpers ---------------------------------------------------------------

// Every `{ provide: X, useValue: {...} }` in live code, as the token plus the
// dotted paths of the keys inside its value (following local variables).
function providerShape(file) {
  const src = parse(file);
  const vars = variables(src);
  const resolve = (e, depth = 0) => {
    e = unwrap(e);
    if (e && ts.isIdentifier(e) && vars.has(e.text) && depth < 5) {
      return resolve(vars.get(e.text).initializer, depth + 1);
    }
    return e;
  };
  const out = new Set();
  const keys = (obj, prefix) => {
    for (const p of obj.properties) {
      if (!p.name) continue;
      const key = `${prefix}.${p.name.getText(src)}`;
      out.add(key);
      let value;
      if (ts.isPropertyAssignment(p)) value = resolve(p.initializer);
      if (ts.isShorthandPropertyAssignment(p)) value = resolve(p.name);
      if (ts.isGetAccessorDeclaration(p) && p.body) {
        const ret = p.body.statements.find(ts.isReturnStatement);
        value = ret && resolve(ret.expression);
      }
      if (value && ts.isObjectLiteralExpression(value)) keys(value, key);
    }
  };
  walk(src, (n) => {
    if (!ts.isObjectLiteralExpression(n)) return;
    const provide = prop(n, 'provide', src);
    if (!provide) return;
    const token = provide.initializer.getText(src);
    out.add(token);
    const useValue = prop(n, 'useValue', src);
    const value = useValue && resolve(useValue.initializer);
    if (value && ts.isObjectLiteralExpression(value)) keys(value, token);
  });
  return out;
}

function exportsOf(file) {
  const names = new Set();
  for (const st of parse(file).statements) {
    const exported = st.modifiers?.some(
      (m) => m.kind === ts.SyntaxKind.ExportKeyword,
    );
    if (exported && st.name) names.add(st.name.text);
  }
  return names;
}

function checkHelpers() {
  const tu = path.join(repo, 'src/app/test-utils');
  const dtp = path.join(tu, 'default-test-providers.ts');
  const mpd = path.join(tu, 'mock-permission-data.service.ts');
  const tpl = (n) => path.join(standard, 'test-utils', n);
  if (fs.existsSync(dtp)) {
    const want = providerShape(tpl('default-test-providers.template.ts'));
    const have = providerShape(dtp);
    const missing = [...want].filter((k) => !have.has(k));
    if (missing.length) {
      problems.push(
        `  DRIFT    ${rel(dtp)} lacks what the template provides: ${missing.join(', ')}`,
      );
    }
    for (const name of exportsOf(tpl('default-test-providers.template.ts'))) {
      if (!exportsOf(dtp).has(name)) {
        problems.push(`  DRIFT    ${rel(dtp)} does not export ${name}`);
      }
    }
    // Root-provided common-library services the app injects (constructor
    // parameter or inject()) must be listed, or the real one is built in every
    // spec. Route guards are not injected by components and are not counted.
    const used = new Set();
    for (const f of files(
      path.join(repo, 'src/app'),
      (p) =>
        p.endsWith('.ts') &&
        !p.endsWith('.spec.ts') &&
        !p.includes(`${path.sep}test-utils${path.sep}`) &&
        !p.includes(`${path.sep}generated${path.sep}`),
    )) {
      const src = parse(f);
      const common = new Set();
      for (const st of src.statements) {
        const named = st.importClause?.namedBindings;
        if (
          ts.isImportDeclaration(st) &&
          st.moduleSpecifier.text === '@cmusei/crucible-common' &&
          named &&
          ts.isNamedImports(named)
        ) {
          for (const el of named.elements) {
            if (/(Service|Query)$/.test(el.name.text)) common.add(el.name.text);
          }
        }
      }
      if (!common.size) continue;
      walk(src, (n) => {
        let name;
        if (
          ts.isParameter(n) &&
          ts.isConstructorDeclaration(n.parent) &&
          n.type &&
          ts.isTypeReferenceNode(n.type)
        ) {
          name = n.type.typeName.getText(src);
        }
        if (
          ts.isCallExpression(n) &&
          ts.isIdentifier(n.expression) &&
          n.expression.text === 'inject' &&
          n.arguments[0] &&
          ts.isIdentifier(n.arguments[0])
        ) {
          name = n.arguments[0].text;
        }
        if (name && common.has(name)) used.add(name);
      });
    }
    const listed = new Set();
    walk(parse(dtp), (n) => {
      if (ts.isIdentifier(n)) listed.add(n.text);
    });
    const unlisted = [...used].filter((n) => !listed.has(n)).sort();
    if (unlisted.length) {
      problems.push(
        `  DRIFT    ${rel(dtp)} lacks common-library services the app injects (add unstubbed(...) or a stub): ${unlisted.join(', ')}`,
      );
    }
  }
  checkExtras(tu);
  if (fs.existsSync(mpd)) {
    const have = exportsOf(mpd);
    for (const name of exportsOf(
      tpl('mock-permission-data.service.template.ts'),
    )) {
      if (!have.has(name)) {
        problems.push(`  DRIFT    ${rel(mpd)} does not export ${name}`);
      }
    }
  }
}

// Files a repo may keep in src/app/test-utils besides the nine shared helpers
// and the two app-specific ones: fakes for things the standard has no
// equivalent for, each allowed for the app that needs it (README, "Helpers").
// A second app that needs one is the signal to promote it into the standard.
const SHARED_HELPERS = [
  'render-component.ts',
  'unstubbed.ts',
  'api-stub.ts',
  'record-emissions.ts',
  'unhandled-rx-errors.ts',
  'fake-hub-connection.ts',
  'activated-route.ts',
  'dialog-refs.ts',
  'file-list.ts',
];
const APP_HELPERS = [
  'default-test-providers.ts',
  'mock-permission-data.service.ts',
];
const ALLOWED_EXTRAS = {
  'fake-wmks.ts': ['console.ui'],
  'clipboard.ts': ['console.ui'],
  'download-response.ts': ['caster.ui'],
  'jsdom-canvas.ts': ['caster.ui'],
  'match-media.ts': ['caster.ui'],
  'mat-dialog.ts': ['cite.ui'],
  'msel-load-api-stubs.ts': ['blueprint.ui'],
};
// For a scratch copy under another name, any listed extra is accepted.
const KNOWN_APPS = new Set(
  'alloy blueprint caster cite console gallery player steamfitter vm'
    .split(' ')
    .map((a) => `${a}.ui`),
);
const extraAllowed = (name) =>
  Boolean(ALLOWED_EXTRAS[name]) &&
  (!KNOWN_APPS.has(app) || ALLOWED_EXTRAS[name].includes(app));

function readAngularJson() {
  const f = path.join(repo, 'angular.json');
  if (!fs.existsSync(f)) return null;
  let parseJson;
  try {
    parseJson = require(path.join(repo, 'node_modules/jsonc-parser')).parse;
  } catch {
    parseJson = (t) => JSON.parse(t.replace(/^\s*\/\/.*$/gm, ''));
  }
  return parseJson(read(f));
}

function checkExtras(tu) {
  if (fs.existsSync(tu)) {
    for (const name of fs.readdirSync(tu).sort()) {
      if (!name.endsWith('.ts') || name.endsWith('.spec.ts')) continue;
      if (SHARED_HELPERS.includes(name) || APP_HELPERS.includes(name)) continue;
      if (!extraAllowed(name)) {
        problems.push(
          `  DRIFT    src/app/test-utils/${name} is not a shared helper, an app-specific helper or an allowed extra for ${app} (README, "Helpers": name it there, or promote it into the standard)`,
        );
      }
    }
  }
  // setupFiles: src/test-setup.ts first; an app may append an allowed extra
  // that has to run before any spec's module graph loads (caster.ui's
  // jsdom-canvas.ts for @xterm/xterm).
  const ng = readAngularJson();
  if (!ng) return;
  for (const [name, project] of Object.entries(ng.projects ?? {})) {
    const t = project.architect?.test;
    if (!t || t.builder !== '@angular/build:unit-test') continue;
    const setup = t.options?.setupFiles ?? [];
    if (setup[0] !== 'src/test-setup.ts') {
      problems.push(
        `  DRIFT    angular.json ${name}:test setupFiles must start with src/test-setup.ts (got ${JSON.stringify(setup)})`,
      );
    }
    for (const extra of setup.slice(1)) {
      const m = /^src\/app\/test-utils\/([\w.-]+\.ts)$/.exec(extra);
      if (!m || !extraAllowed(m[1])) {
        problems.push(
          `  DRIFT    angular.json ${name}:test setupFiles entry ${extra} is not an allowed extra under src/app/test-utils (README, "Helpers")`,
        );
      }
    }
  }
}

// --- specs -----------------------------------------------------------------

function checkSpecs() {
  const generated = new Set();
  for (const f of files(
    path.join(repo, 'src/app'),
    (p) => /[\\/]generated[\\/]/.test(p) && p.endsWith('.service.ts'),
  )) {
    for (const m of read(f).matchAll(/export class (\w+)/g)) {
      generated.add(m[1]);
    }
  }
  const stale = [
    [
      /HubConnectionBuilder\.prototype/,
      'spies on HubConnectionBuilder.prototype (use mockHubConnectionBuilder: onBuild, connections)',
    ],
    [
      /Omit<ApiStub/,
      'Omit<ApiStub...> workaround (ApiStub covers all overloads)',
    ],
  ];
  // Defects are described in agent-docs/ui-test-bugs/<app>.md, not in specs
  // (CONVENTIONS.md section 3), so no spec comment may say BUG.
  const defectNote = [/\/\/.*\bBUG\b/, /\*.*\bBUG\b/];
  const appDir = path.join(repo, 'src/app') + path.sep;
  for (const f of files(path.join(repo, 'src'), (p) =>
    p.endsWith('.spec.ts'),
  )) {
    const text = read(f);
    text.split('\n').forEach((line, i) => {
      if (f.startsWith(appDir) && defectNote.some((re) => re.test(line))) {
        problems.push(
          `  PIN      ${rel(f)}:${i + 1} BUG in a spec comment (describe the defect in agent-docs/ui-test-bugs/${app}.md and keep only a neutral comment; CONVENTIONS.md section 3)`,
        );
      }
      if (/^\s*(\/\/|\*)/.test(line)) return;
      for (const [re, why] of stale) {
        if (re.test(line))
          problems.push(`  STALE    ${rel(f)}:${i + 1} ${why}`);
      }
    });
    const src = parse(f);
    const vars = variables(src);
    const aliases = new Map();
    const fromGenerated = new Set();
    walk(src, (n) => {
      if (ts.isTypeAliasDeclaration(n)) {
        aliases.set(n.name.text, n.type.getText(src));
      }
    });
    for (const st of src.statements) {
      const named = st.importClause?.namedBindings;
      if (
        ts.isImportDeclaration(st) &&
        /generated/.test(st.moduleSpecifier.text) &&
        named &&
        ts.isNamedImports(named)
      ) {
        for (const el of named.elements) fromGenerated.add(el.name.text);
      }
    }
    const isApiStubType = (text) => {
      for (let i = 0; i < 5 && text; i++) {
        if (/\bApiStub</.test(text)) return true;
        text = aliases.get(text.trim());
      }
      return false;
    };
    // true: checked against ApiStub; false: provably unchecked; null: unknown
    // (a call, a property access), which is left alone.
    const typed = (e, depth = 0) => {
      while (ts.isParenthesizedExpression(e)) e = e.expression;
      if (ts.isSatisfiesExpression(e))
        return isApiStubType(e.type.getText(src));
      if (ts.isAsExpression(e)) return false;
      if (ts.isObjectLiteralExpression(e)) {
        // The documented exception: members whose generated type is wrong sit
        // next to a spread of a checked block.
        return e.properties.some(
          (p) => ts.isSpreadAssignment(p) && typed(p.expression) === true,
        );
      }
      if (ts.isIdentifier(e)) {
        const d = vars.get(e.text);
        if (!d) return null;
        if (d.type) return isApiStubType(d.type.getText(src));
        return d.initializer && depth < 5
          ? typed(d.initializer, depth + 1)
          : null;
      }
      return null;
    };
    walk(src, (n) => {
      if (!ts.isObjectLiteralExpression(n)) return;
      const provide = prop(n, 'provide', src);
      const useValue = prop(n, 'useValue', src);
      if (!provide || !useValue || !ts.isIdentifier(provide.initializer))
        return;
      const token = provide.initializer.text;
      const value = unwrap(useValue.initializer);
      if (
        /(Service|Query|Store)$/.test(token) &&
        ts.isObjectLiteralExpression(value) &&
        value.properties.length === 0
      ) {
        problems.push(
          `  STALE    ${rel(f)}:${lineOf(src, n)} { provide: ${token}, useValue: {} } (use unstubbed(${token}))`,
        );
        return;
      }
      if (
        generated.has(token) &&
        fromGenerated.has(token) &&
        typed(useValue.initializer) === false
      ) {
        problems.push(
          `  UNTYPED  ${rel(f)}:${lineOf(src, n)} ${token} stub is not checked with satisfies ApiStub<${token}>`,
        );
      }
    });
  }
}

// Each defect entry names the test that pins it by spec file and test name
// (testing/README.md, "Defect documents"): `Test: `<spec file>` `<test name>``.
// The check confirms the named test is there. Everything about the document's
// own shape is bookkeeping, so every line it prints is a NOTE, never fatal.
// The old `Spec: `<file>:<line>`` form is read too; testing/fix-docs.js
// rewrites it.
function checkDefectTests() {
  const doc = path.join(AGENT_DOCS, 'ui-test-bugs', `${app}.md`);
  if (!fs.existsSync(doc)) return;
  const name = `agent-docs/ui-test-bugs/${app}.md`;
  const note = (i, msg) => notes.push(`  NOTE     defects: ${name}:${i + 1} ${msg}`);
  let specPath = null;
  let section = '';
  let entry = null;
  let entries = 0;
  let missing = 0;
  const cache = new Map();
  const testsIn = (f) => {
    if (!cache.has(f)) {
      const abs = path.join(repo, f);
      cache.set(f, fs.existsSync(abs) ? titlesOf(read(abs), abs) : null);
    }
    return cache.get(f);
  };
  const close = () => {
    if (entry && !entry.seen && entry.counted)
      note(entry.line, `${entry.title}: no 'Test:' line naming its spec file and test name`);
  };
  read(doc)
    .split('\n')
    .forEach((line, i) => {
      const h2 = /^##\s+(.*?)\s*$/.exec(line);
      if (h2) {
        close();
        section = h2[1];
        specPath = /^\S+\.spec\.ts$/.test(section) ? section : null;
        entry = null;
        return;
      }
      const h3 = /^###\s+(.*?)\s*$/.exec(line);
      if (h3) {
        close();
        const counted = !!specPath || section === 'Needs a decision';
        entry = { title: h3[1], seen: false, line: i, counted };
        if (counted) entries++;
        return;
      }
      const m = /^(Test|Spec):\s*(.*)$/.exec(line);
      if (!m || !entry || entry.seen || !entry.counted) return;
      entry.seen = true;
      const spans = [...m[2].matchAll(/(`+)\s?(.+?)\s?\1(?!`)/g)].map((x) =>
        x[2].trim(),
      );
      if (!spans.length) {
        note(i, `${entry.title}: '${m[1]}:' is \`<spec file>\` \`<test name>\``);
        return;
      }
      const legacy = m[1] === 'Spec' || /:\d+(?:-\d+)?$/.test(spans[0]);
      if (legacy)
        note(
          i,
          `${entry.title}: '${m[1]}:' carries a line number; 'Test:' names the spec file and the test name (testing/fix-docs.js rewrites it)`,
        );
      const file = spans[0].replace(/:\d+(?:-\d+)?$/, '');
      const typing = /^\(typing note on /.test(entry.title);
      const title = legacy || typing ? entry.title : (spans[1] ?? entry.title);
      if (!legacy && !typing && spans[1] && spans[1] !== entry.title)
        note(i, `'Test:' names '${spans[1]}', the heading '${entry.title}'`);
      if (specPath && file !== specPath)
        note(i, `${entry.title}: 'Test:' names ${file}, not the section's ${specPath}`);
      const tests = testsIn(file);
      if (!tests) {
        missing++;
        note(i, `${entry.title}: ${file} does not exist (moved? update the entry)`);
        return;
      }
      if (typing) return;
      if (!tests.some((x) => x.title === title)) {
        missing++;
        note(
          i,
          `no test named '${title}' in ${file} (renamed or removed? update the entry; testing/fix-docs.js follows a removed-test A line)`,
        );
      }
    });
  close();
  trailer.push(
    `  (${name}: ${entries} entries, ${missing} naming a test that does not exist)`,
  );
}

// --- gates -----------------------------------------------------------------
//
// An untested permission gate is a blocker (WORKFLOW.md, Deliver). This check
// inventories every component under src/app, and every directive or guard
// that reads a permission, and fails when:
//   NOSPEC    a component has no spec beside it (x.component.ts ->
//             x.component.spec.ts; the smoke spec template is the minimum);
//   UNTESTED  a file that reads a permission has no spec beside it;
//   NODENIED  its spec has no denied case (DENIED_SHAPES below);
//   ALLOW*    an entry of agent-docs/ui-test-gaps/<app>.json has no reason,
//             gives budget as the reason, or matches nothing; or a
//             gates.allow.json exists anywhere under the repo's src (the
//             allow-list lives outside the repos, like the defect documents).
// The tables below are the whole definition. When an app writes a gate in a
// shape they miss, extend the table here and say so in the CHANGELOG.
//
// What it cannot judge: whether a denied case is a near miss and whether it
// fails when its gate is broken. That is the reviewer's reading and the
// writer's broken-gate check (CONVENTIONS.md sections 2 and 5).

// Services that answer permission questions, matched by class name when the
// import is app code. (player.ui's generated PermissionService is a CRUD
// client, so generated/ imports never count.)
const PERMISSION_SERVICES = new Set([
  'PermissionService', // caster.ui
  'PermissionDataService', // alloy, blueprint, cite, gallery, steamfitter
  'UserPermissionsService', // player.ui, vm.ui, console.ui
]);
// Service members that load data rather than decide. (get* members count:
// player.ui's getManageableTeamIds is a decision.)
const SERVICE_NOT_A_GATE = /^(load|ngOn)/;
// Service members that expose the raw permission list. Reading one marks the
// file as gated; the decisions are the `.includes(...)` reads on it, so the
// member itself is listed as a gate only when no other gate is found.
const SERVICE_SOURCE = /[pP]ermissions\$?$/;
// can-prefixed names that are not permission gates.
const NOT_GATES = new Set([
  'canActivate', // router guard interfaces
  'canActivateChild',
  'canDeactivate',
  'canMatch',
  'canLoad',
  'canFullScreen', // the WMKS console API (console.ui)
]);
const ENUM_PERMISSION = /\b[A-Z]\w*Permission\.\w+/g;

// Where a gate is read. Each `find(text, ctx)` returns `{ gate, source? }`
// items; `ctx.services` holds the names of the injected permission services.
// Runs on the class file (comments, imports and the right-hand side of a
// `canX = ...` assignment blanked, so a derived flag counts once) and on the
// template (inline or templateUrl, HTML comments removed).
const GATE_PATTERNS = [
  {
    shape:
      'canEdit, canEdit$ | async, @if (canManage), *ngIf="canX", canEvent(...), this.data.canEdit',
    find: (text) =>
      [...text.matchAll(/(?<![\w$])can[A-Z]\w*\$?/g)]
        .map((m) => m[0])
        .filter((name) => !NOT_GATES.has(name.replace(/\$$/, '')))
        .map((gate) => ({ gate })),
  },
  {
    shape:
      "permissions.includes(SystemPermission.ViewUsers), x.scenarioPermissions?.some(m => m === ScenarioPermission.EditScenario), permissionValues.includes(TeamPermission.ManageTeam), permissions.includes(item.permission); a role editor's role.permissions.some(x => x === permission) has no *Permission.Member argument and is not a gate",
    find: (text) => {
      const out = [];
      const re =
        /([\w$.?]*[pP]ermission\w*)\??\.(includes|some|indexOf|find|every)\(((?:[^()]|\((?:[^()]|\([^()]*\))*\))*)\)/g;
      for (const m of text.matchAll(re)) {
        const refs = m[3].match(ENUM_PERMISSION);
        if (refs) out.push(...refs.map((gate) => ({ gate })));
        else if (
          /^(this\.)?permissions$/.test(m[1]) &&
          m[2] === 'includes' &&
          /^\s*[\w$.?]+\s*$/.test(m[3])
        ) {
          out.push({ gate: m[3].trim() });
        }
      }
      return out;
    },
  },
  {
    shape:
      'this.permissionDataService.hasPermission(SystemPermission.EditMsels), userPermissionsService.can(AppTeamPermission.UploadVmFiles), permissionService.permissions$',
    find: (text, ctx) => {
      const out = [];
      for (const name of ctx.services) {
        const re = new RegExp(
          `(?<![\\w$])${name.replace(/\$/g, '\\$')}\\s*\\.\\s*(\\w+\\$?)(\\s*\\(((?:[^()]|\\([^()]*\\))*)\\))?`,
          'g',
        );
        for (const m of text.matchAll(re)) {
          const member = m[1];
          if (SERVICE_NOT_A_GATE.test(member) || /^can[A-Z]/.test(member)) {
            continue;
          }
          if (SERVICE_SOURCE.test(member)) {
            out.push({ gate: member, source: true });
            continue;
          }
          const refs = (m[3] ?? '').match(ENUM_PERMISSION);
          if (refs) out.push(...refs.map((gate) => ({ gate })));
          else {
            const args = (m[3] ?? '').replace(/\s+/g, ' ').trim();
            const short = args.length > 40 ? `${args.slice(0, 37)}...` : args;
            out.push({ gate: m[2] ? `${member}(${short})` : member });
          }
        }
      }
      return out;
    },
  },
];

// A test (it / test / it.each / test.for; never .skip or .todo) is a denied
// case when it both sets up permissions and asserts that something is absent
// or disabled. Its text is its name, its it.each table, its body, the
// beforeEach bodies of the describes around it, and the declarations of
// non-function constants it names (a `nearMiss` grant object).
const PERMISSION_SETUP = [
  'permissionDataProviders(...) or permissionApiStubs(...)',
  'a PermissionGrants value, or one of its keys as an object key (system:, projects:, teams:, ...; read from mock-permission-data.service.ts)',
  'a *Permission.Member enum value (SystemPermission.ViewUsers)',
  "one of the component's own gate names (canEdit: false passed to a child)",
];
// An it.each matrix: rows of grants, each compared with the exact list it
// renders, so the near-miss rows prove what they do not see.
const MATRIX = (e, t) =>
  Boolean(t.table) &&
  (t.table.match(/\{/g) ?? []).length >= 2 &&
  /^(toEqual|toStrictEqual)$/.test(e.matcher) &&
  !e.not &&
  RENDERED.test(e.arg) &&
  /^[A-Za-z_$][\w$.]*$/.test(e.value);
const RENDERED =
  /fixture|screen|container|within\(|query|getBy|getAllBy|textContent|Texts?\b|[mM]enu|[iI]tems|[lL]abels|[oO]ptions|[rR]ows|[sS]ections|[pP]anels|[bB]uttons|[lL]inks|[tT]abs/;
// The test's own text (name, it.each table, body; not the factory it calls)
// must say it is the denied side: a false or [] value, or a denial word.
const DENIED_HINT =
  /\bfalse\b|(?<![\w>)\]])\[\s*\]|\b(without|lacks?|lacking|denied|deny|denies|hides?|hidden|cannot|can't|not|no|read-?only|restricted|disabled?|disables|near[- ]?miss\w*|only)\b|nearMiss/i;
const QUERYISH =
  /\bquery(All)?By|querySelector|within\(|By\.(css|directive)|componentInstance|\bcan[A-Z]|[pP]ermi|disabled|hidden|visible|shown|[sS]tub\b/;

const DENIED_SHAPES = [
  [
    'expect(el).not.toBeInTheDocument() / .not.toBeVisible()',
    (e) => e.not && /^(toBeInTheDocument|toBeVisible)$/.test(e.matcher),
  ],
  [
    'expect(el).toBeDisabled() / .not.toBeEnabled()',
    (e) =>
      (!e.not && e.matcher === 'toBeDisabled') ||
      (e.not && e.matcher === 'toBeEnabled'),
  ],
  [
    "expect(el).toHaveAttribute('disabled' | 'aria-disabled', ...)",
    (e) =>
      !e.not &&
      e.matcher === 'toHaveAttribute' &&
      /^['"](aria-)?disabled['"]/.test(e.value),
  ],
  [
    'expect(<query, stub input, can*, permission>).toBeNull() / .toBeFalsy() / .toBe(false)',
    (e) =>
      QUERYISH.test(e.arg) &&
      !/\.(disabled|hidden)\b|aria-disabled/.test(e.arg) &&
      ((!e.not &&
        (/^(toBeNull|toBeFalsy|toBeUndefined)$/.test(e.matcher) ||
          (/^(toBe|toEqual|toStrictEqual)$/.test(e.matcher) &&
            e.value === 'false'))) ||
        (e.not && e.matcher === 'toBeTruthy')),
  ],
  [
    'expect(<query or rendered list>).toEqual([]) / .toHaveLength(0)',
    (e) =>
      !e.not &&
      (QUERYISH.test(e.arg) || RENDERED.test(e.arg)) &&
      ((/^(toEqual|toStrictEqual)$/.test(e.matcher) &&
        /^\[\s*\]$/.test(e.value)) ||
        (e.matcher === 'toHaveLength' && e.value === '0')),
  ],
  [
    'expect(el.disabled | .hidden).toBe(true)',
    (e) =>
      !e.not &&
      /^(toBe|toEqual)$/.test(e.matcher) &&
      e.value === 'true' &&
      /\.(disabled|hidden)\b|aria-disabled/.test(e.arg),
  ],
  [
    'expect(<rendered list>).toEqual([...exact list]) in a test that passes a can* flag as false (canMountIso: false)',
    (e, t) =>
      /^(toEqual|toStrictEqual)$/.test(e.matcher) &&
      !e.not &&
      /^\[/.test(e.value) &&
      RENDERED.test(e.arg) &&
      /(?<![\w$.])can[A-Z]\w*\$?\s*:\s*(false|of\(\s*false\s*\))/.test(t.own),
  ],
  [
    'an it.each matrix of grants and the exact rendered list each row sees: expect(<rendered list>).toEqual(<row value>)',
    MATRIX,
  ],
  [
    'it.each rows with a false or [] value, and expect(<query, stub input, can*, rendered list>).toBe(<row value>)',
    (e, t) =>
      t.table &&
      /\bfalse\b|(?<![\w>)\]])\[\s*\]/.test(t.table) &&
      (QUERYISH.test(e.arg) || RENDERED.test(e.arg)) &&
      /^(toBe|toEqual|toStrictEqual)$/.test(e.matcher) &&
      /^[A-Za-z_$][\w$.]*$/.test(e.value) &&
      !/^(true|false|null|undefined)$/.test(e.value),
  ],
];
// The allow-list lives outside every repo, like agent-docs/ui-test-bugs.
const ALLOW_PATH = path.join(AGENT_DOCS, 'ui-test-gaps', `${app}.json`);
const ALLOW_FILE = `agent-docs/ui-test-gaps/${app}.json`;
const BUDGET_REASON =
  /\b(budget|time|later|follow[- ]?up|todo|tbd|not yet|ran out|out of)\b/i;

function blank(text, ranges) {
  const chars = text.split('');
  for (const [start, end] of ranges) {
    for (let i = start; i < end; i++) if (chars[i] !== '\n') chars[i] = ' ';
  }
  return chars.join('');
}

function commentRanges(src) {
  const text = src.getFullText();
  const seen = new Map();
  walk(src, (n) => {
    for (const r of [
      ...(ts.getLeadingCommentRanges(text, n.getFullStart()) ?? []),
      ...(ts.getTrailingCommentRanges(text, n.getEnd()) ?? []),
    ]) {
      seen.set(r.pos, [r.pos, r.end]);
    }
  });
  return [...seen.values()];
}

const isCanName = (n) =>
  n && /^can[A-Z]\w*\$?$/.test(n) && !NOT_GATES.has(n.replace(/\$$/, ''));

// The class side of one source file: its decorators, the names of injected
// permission services, its templates, and the text the patterns run on.
function readSource(file) {
  const text = read(file);
  const src = ts.createSourceFile(file, text, ts.ScriptTarget.Latest, true);
  const appServices = new Set();
  const ranges = commentRanges(src);
  const comments = [...ranges];
  for (const st of src.statements) {
    if (!ts.isImportDeclaration(st)) continue;
    ranges.push([st.getStart(src), st.getEnd()]);
    const named = st.importClause?.namedBindings;
    if (
      named &&
      ts.isNamedImports(named) &&
      !/generated/.test(st.moduleSpecifier.text)
    ) {
      for (const el of named.elements) {
        if (PERMISSION_SERVICES.has(el.name.text))
          appServices.add(el.name.text);
      }
    }
  }
  const kinds = new Set();
  const services = new Set();
  const templates = [];
  const selectors = [];
  const inputs = new Set();
  const notGates = new Set();
  const members = new Set(); // can* names declared as class members
  const locals = new Set(); // can* names declared as parameters or locals
  const literalOnly = new Map(); // can* member -> only ever a boolean literal
  const canMethods = new Set();
  const isBoolLiteral = (e) =>
    e &&
    (e.kind === ts.SyntaxKind.TrueKeyword ||
      e.kind === ts.SyntaxKind.FalseKeyword);
  const heritage = (n) =>
    (n.heritageClauses ?? []).flatMap((h) =>
      h.types.map((t) => t.expression.getText(src)),
    );
  walk(src, (n) => {
    if (ts.isDecorator(n) && ts.isCallExpression(n.expression)) {
      const name = n.expression.expression.getText(src);
      if (['Component', 'Directive', 'Pipe', 'Injectable'].includes(name))
        kinds.add(name);
      if (name === 'StoreConfig') kinds.add('Store');
      if (/^Input$/.test(name) && n.parent && n.parent.name) {
        inputs.add(n.parent.name.getText(src));
      }
      const meta = n.expression.arguments[0];
      if (
        ['Component', 'Directive'].includes(name) &&
        meta &&
        ts.isObjectLiteralExpression(meta)
      ) {
        const sel = prop(meta, 'selector', src);
        if (sel && ts.isStringLiteralLike(sel.initializer)) {
          selectors.push(
            ...sel.initializer.text
              .split(',')
              .map((x) => x.trim())
              .filter((x) => /^[a-z][\w-]*$/.test(x)),
          );
        }
      }
      if (name === 'Component' && meta && ts.isObjectLiteralExpression(meta)) {
        const url = prop(meta, 'templateUrl', src);
        const inline = prop(meta, 'template', src);
        if (url && ts.isStringLiteralLike(url.initializer)) {
          const f = path.resolve(path.dirname(file), url.initializer.text);
          if (fs.existsSync(f)) templates.push(read(f));
        }
        if (inline && ts.isStringLiteralLike(inline.initializer)) {
          templates.push(inline.initializer.text);
        } else if (inline && ts.isTemplateExpression(inline.initializer)) {
          templates.push(inline.initializer.getText(src));
        }
      }
    }
    // Signal inputs: canEdit = input(...), input.required(...).
    if (
      ts.isPropertyDeclaration(n) &&
      n.name &&
      n.initializer &&
      ts.isCallExpression(n.initializer) &&
      /^input(\.required)?$/.test(n.initializer.expression.getText(src))
    ) {
      inputs.add(n.name.getText(src));
    }
    if (ts.isClassDeclaration(n)) {
      // An Akita query whose members only pass their parameters straight to
      // Akita (`selectById(id) { return this.selectEntity(id); }`) is wiring:
      // the data service spec exercises it with the real store.
      const passThrough = (m) => {
        if (!ts.isMethodDeclaration(m) || !m.body) return false;
        const [st] = m.body.statements;
        if (m.body.statements.length !== 1 || !ts.isReturnStatement(st))
          return false;
        const call = st.expression;
        if (
          !call ||
          !ts.isCallExpression(call) ||
          !ts.isPropertyAccessExpression(call.expression) ||
          call.expression.expression.kind !== ts.SyntaxKind.ThisKeyword ||
          !AKITA_QUERY_METHODS.has(call.expression.name.text)
        )
          return false;
        const params = m.parameters.map((p) => p.name.getText(src));
        const args = call.arguments.map((a) => a.getText(src));
        return (
          args.length === params.length && args.every((a, i) => a === params[i])
        );
      };
      const selectors = n.members.filter(
        (m) => !ts.isConstructorDeclaration(m) && !passThrough(m),
      );
      if (
        heritage(n).some((h) => /^Query(Entity)?$/.test(h)) &&
        selectors.length === 0
      )
        kinds.add('WiringQuery');
      for (const h of heritage(n)) {
        if (/^(Entity)?Store$/.test(h)) kinds.add('Store');
        if (/^Query(Entity)?$/.test(h)) kinds.add('Query');
        if (
          /^(CanActivate|CanActivateChild|CanMatch|CanLoad|CanDeactivate)$/.test(
            h,
          )
        )
          kinds.add('Guard');
        if (h === 'HttpInterceptor') kinds.add('Interceptor');
        if (h === 'Resolve') kinds.add('Resolver');
      }
    }
    if (
      ts.isTypeReferenceNode(n) &&
      /^(CanActivate|CanActivateChild|CanMatch|CanLoad|CanDeactivate)(Fn)?$/.test(
        n.typeName.getText(src),
      )
    ) {
      kinds.add('Guard');
    }
    if (
      ts.isTypeReferenceNode(n) &&
      n.typeName.getText(src) === 'HttpInterceptorFn'
    )
      kinds.add('Interceptor');
    if (ts.isTypeReferenceNode(n) && n.typeName.getText(src) === 'ResolveFn')
      kinds.add('Resolver');
    if (
      ts.isParameter(n) &&
      ts.isIdentifier(n.name) &&
      n.type &&
      ts.isTypeReferenceNode(n.type) &&
      appServices.has(n.type.typeName.getText(src))
    ) {
      services.add(n.name.text);
    }
    if (
      (ts.isPropertyDeclaration(n) || ts.isVariableDeclaration(n)) &&
      ts.isIdentifier(n.name) &&
      n.initializer &&
      ts.isCallExpression(n.initializer) &&
      n.initializer.expression.getText(src) === 'inject' &&
      appServices.has(n.initializer.arguments[0]?.getText(src))
    ) {
      services.add(n.name.text);
    }
    // Where can* names are declared: class members are gates; parameters
    // (`teams.some((canControl) => ...)`), destructured names and locals are
    // not (their right-hand side still counts through the other patterns).
    const nameText = n.name && n.name.getText ? n.name.getText(src) : '';
    if (
      (ts.isPropertyDeclaration(n) ||
        ts.isMethodDeclaration(n) ||
        ts.isGetAccessorDeclaration(n) ||
        ts.isSetAccessorDeclaration(n)) &&
      isCanName(nameText)
    ) {
      members.add(nameText);
      if (ts.isMethodDeclaration(n))
        canMethods.add([nameText, n.getStart(src), n.getEnd()]);
      if (ts.isPropertyDeclaration(n)) {
        const lit = !n.initializer || isBoolLiteral(n.initializer);
        literalOnly.set(nameText, lit && Boolean(n.initializer));
      }
    }
    if (
      ts.isParameter(n) &&
      ts.isIdentifier(n.name) &&
      isCanName(n.name.text)
    ) {
      const isProp = n.modifiers?.some((m) =>
        [
          ts.SyntaxKind.PublicKeyword,
          ts.SyntaxKind.PrivateKeyword,
          ts.SyntaxKind.ProtectedKeyword,
          ts.SyntaxKind.ReadonlyKeyword,
        ].includes(m.kind),
      );
      if (isProp) members.add(n.name.text);
      else locals.add(n.name.text);
    }
    if (
      ts.isBindingElement(n) &&
      ts.isIdentifier(n.name) &&
      isCanName(n.name.text)
    )
      locals.add(n.name.text);
    const isLocalVar =
      ts.isVariableDeclaration(n) &&
      ts.isIdentifier(n.name) &&
      isCanName(n.name.text) &&
      ts.findAncestor(
        n,
        (x) => ts.isFunctionLike(x) || ts.isClassStaticBlockDeclaration(x),
      );
    if (isLocalVar) locals.add(n.name.text);
    // A derived flag counts once: blank the right-hand side of `canX = ...`
    // (property, module-level variable, `this.canX =` assignment) and the body
    // of a `canX()` method. A local variable's right-hand side stays, so the
    // permission it reads is found by the other patterns.
    const fold = (node) =>
      node && ranges.push([node.getStart(src), node.getEnd()]);
    if (
      (ts.isPropertyDeclaration(n) || ts.isVariableDeclaration(n)) &&
      n.name &&
      isCanName(n.name.getText(src)) &&
      !isLocalVar
    ) {
      fold(n.initializer);
    }
    if (
      ts.isBinaryExpression(n) &&
      n.operatorToken.kind === ts.SyntaxKind.EqualsToken &&
      isCanName(n.left.getText(src).replace(/^this\./, ''))
    ) {
      const target = n.left.getText(src).replace(/^this\./, '');
      if (/^this\./.test(n.left.getText(src))) {
        fold(n.right);
        if (!isBoolLiteral(n.right)) literalOnly.set(target, false);
      } else if (!locals.has(target)) fold(n.right);
    }
    // A `canX()` method or getter whose body reads no permission and no other
    // gate (an object-type switch, a form check) is not a gate.
    if (
      (ts.isMethodDeclaration(n) ||
        ts.isGetAccessorDeclaration(n) ||
        ts.isFunctionDeclaration(n)) &&
      n.name &&
      isCanName(n.name.getText(src)) &&
      n.body
    ) {
      const body = n.body.getText(src);
      if (
        !/[pP]ermission|(?<![\w$])can[A-Z]/.test(body) &&
        ![...services].some((s) => body.includes(s))
      ) {
        notGates.add(n.name.getText(src));
      }
      fold(n.body);
    }
  });
  const templateText = templates
    .join('\n')
    .replace(/<!--[\s\S]*?-->/g, (c) => c.replace(/[^\n]/g, ' '));
  const classText = blank(text, ranges);
  // Names that are only parameters or locals are not gates, unless the same
  // name is also read as a member (`data.canEdit` in the template).
  for (const l of locals) {
    const member = new RegExp(`\\.\\s*${esc(l)}(?![\\w$])`);
    const inTemplate = new RegExp(`(?<![\\w$])${esc(l)}(?![\\w$])`);
    if (
      !members.has(l) &&
      !inTemplate.test(templateText) &&
      !member.test(blank(text, comments))
    )
      notGates.add(l);
  }
  // A can* field that is only ever a boolean literal (`canManageTeam = false`)
  // and is not an input decides nothing, unless other code sets it
  // (`dialogRef.componentInstance.canManageRoles = ...`; checked in gatesOf).
  const literalFields = [...literalOnly]
    .filter(([name, lit]) => lit && !inputs.has(name))
    .map(([name]) => name);
  // A can* method nothing calls (neither the class nor the template) is dead.
  // Calls are `this.canX(...)` or a bare `canX` outside the method itself;
  // `this.permissionService.canX()` inside it is the service's method.
  for (const [m, start, end] of canMethods) {
    const code = blank(text, [...comments, [start, end]]);
    const own = new RegExp(
      `(?:this\\s*\\.\\s*|(?<![\\w$.]))${esc(m)}(?![\\w$])`,
    );
    const inTemplate = new RegExp(`(?<![\\w$])${esc(m)}(?![\\w$])`);
    if (!own.test(code) && !inTemplate.test(templateText)) notGates.add(m);
  }
  return {
    kinds,
    services,
    notGates,
    literalFields,
    selectors,
    inputs,
    templateRaw: templateText,
    classText,
    templateText,
  };
}

// Akita Query / QueryEntity methods a wiring query may pass through to.
const AKITA_QUERY_METHODS = new Set([
  'select',
  'selectAll',
  'getAll',
  'selectEntity',
  'getEntity',
  'hasEntity',
  'selectActive',
  'getActive',
  'selectActiveId',
  'getActiveId',
  'selectLoading',
  'selectError',
  'selectCount',
  'getCount',
  'selectFirst',
  'selectLast',
  'selectMany',
]);

// can* members that some other file of the app sets: `x.canManageRoles = ...`
// or a `[canEdit]` binding. Filled by checkGates before any gatesOf call.
const EXTERNALLY_SET = new Set();

function gatesOf(source) {
  const ctx = { services: source.services };
  const found = [];
  for (const text of [source.classText, source.templateText]) {
    for (const p of GATE_PATTERNS) found.push(...p.find(text, ctx));
  }
  const decisions = [
    ...new Set(found.filter((g) => !g.source).map((g) => g.gate)),
  ].filter(
    (g) =>
      !source.notGates.has(g) &&
      !(source.literalFields.includes(g) && !EXTERNALLY_SET.has(g)),
  );
  const sources = [
    ...new Set(found.filter((g) => g.source).map((g) => g.gate)),
  ];
  return decisions.length ? decisions : sources;
}

// expect(arg)[.not].matcher(value), anywhere under `node`.
function expectations(node, src) {
  const out = [];
  walk(node, (n) => {
    if (!ts.isCallExpression(n) || !ts.isPropertyAccessExpression(n.expression))
      return;
    let obj = n.expression.expression;
    let not = false;
    if (ts.isPropertyAccessExpression(obj) && obj.name.text === 'not') {
      not = true;
      obj = obj.expression;
    }
    if (
      ts.isCallExpression(obj) &&
      ts.isIdentifier(obj.expression) &&
      obj.expression.text === 'expect' &&
      obj.arguments[0]
    ) {
      out.push({
        arg: obj.arguments[0].getText(src),
        not,
        matcher: n.expression.name.text,
        value: n.arguments.map((a) => a.getText(src)).join(', '),
      });
    }
  });
  return out;
}

// Every test in a spec, with the text the setup rule reads.
function testsOf(specFile) {
  const src = parse(specFile);
  const consts = new Map();
  const factories = new Map();
  walk(src, (n) => {
    if (ts.isFunctionDeclaration(n) && n.name && n.body) {
      factories.set(n.name.text, n);
    } else if (ts.isVariableDeclaration(n) && ts.isIdentifier(n.name)) {
      const fn =
        n.initializer &&
        (ts.isArrowFunction(n.initializer) ||
          ts.isFunctionExpression(n.initializer));
      if (fn) factories.set(n.name.text, n.initializer);
      else consts.set(n.name.text, n.getText(src));
    }
  });
  // A local render factory called WITH arguments (renderList(false),
  // renderTopbar(nearMiss)) contributes its body: the grants usually live
  // there. One called with none does not, or a factory with fixed grants
  // would make every test look like a permission setup.
  const factoryText = (node, depth = 0, seen = new Set()) => {
    const out = [];
    walk(node, (n) => {
      if (
        ts.isCallExpression(n) &&
        ts.isIdentifier(n.expression) &&
        n.arguments.length &&
        factories.has(n.expression.text) &&
        !seen.has(n.expression.text)
      ) {
        const f = factories.get(n.expression.text);
        seen.add(n.expression.text);
        out.push(f.getText(src));
        if (depth < 2) out.push(...factoryText(f, depth + 1, seen));
      }
    });
    return out;
  };
  const tests = [];
  const callee = (n) => {
    // it(...), it.only(...), it.each(table)(...), test.for(table)(...)
    let e = n.expression;
    let table = null;
    if (ts.isCallExpression(e)) {
      if (!ts.isPropertyAccessExpression(e.expression)) return null;
      if (!['each', 'for'].includes(e.expression.name.text)) return null;
      table = e.arguments.map((a) => a.getText(src)).join(', ');
      e = e.expression.expression;
    }
    const parts = e.getText(src).split('.');
    if (!['it', 'test', 'describe'].includes(parts[0])) return null;
    if (parts.some((p) => ['skip', 'todo', 'fails'].includes(p))) return null;
    if (
      parts
        .slice(1)
        .some((p) => !['only', 'concurrent', 'sequential'].includes(p))
    )
      return null;
    return { kind: parts[0], table };
  };
  const visit = (node, inherited) => {
    if (ts.isCallExpression(node)) {
      const c = callee(node);
      const fn = node.arguments.find(
        (a) => ts.isArrowFunction(a) || ts.isFunctionExpression(a),
      );
      if (c && c.kind === 'describe' && fn) {
        const before = [];
        if (ts.isBlock(fn.body)) {
          for (const st of fn.body.statements) {
            const ex = ts.isExpressionStatement(st) && st.expression;
            if (
              ex &&
              ts.isCallExpression(ex) &&
              /^beforeEach$/.test(ex.expression.getText(src))
            ) {
              before.push(ex.getText(src));
            }
          }
        }
        ts.forEachChild(fn.body, (ch) => visit(ch, [...inherited, ...before]));
        return;
      }
      if (c && c.kind !== 'describe' && fn) {
        let text = [
          node.arguments[0]?.getText(src) ?? '',
          c.table ?? '',
          fn.getText(src),
          ...factoryText(fn),
          ...inherited,
        ].join('\n');
        for (let depth = 0; depth < 2; depth++) {
          const extra = [];
          for (const id of new Set(text.match(/[A-Za-z_$][\w$]*/g) ?? [])) {
            if (consts.has(id) && !text.includes(consts.get(id))) {
              extra.push(consts.get(id));
            }
          }
          text += '\n' + extra.join('\n');
        }
        const own = [
          node.arguments[0]?.getText(src) ?? '',
          c.table ?? '',
          fn.getText(src),
        ].join('\n');
        // The test's own text plus the constants it names (a `nearMiss`
        // grant), but not the factory it calls or the beforeEach around it.
        let ownPlus = own;
        for (let depth = 0; depth < 2; depth++) {
          const extra = [];
          for (const id of new Set(ownPlus.match(/[A-Za-z_$][\w$]*/g) ?? [])) {
            if (consts.has(id) && !ownPlus.includes(consts.get(id))) {
              extra.push(consts.get(id));
            }
          }
          ownPlus += '\n' + extra.join('\n');
        }
        // Arguments of the local factories the test calls (renderDialog(false)).
        const factoryArgs = [];
        walk(fn, (x) => {
          if (
            ts.isCallExpression(x) &&
            ts.isIdentifier(x.expression) &&
            factories.has(x.expression.text) &&
            x.arguments.length
          ) {
            factoryArgs.push(x.arguments.map((a) => a.getText(src)).join(', '));
          }
        });
        tests.push({
          name: node.arguments[0]?.getText(src) ?? '',
          table: c.table,
          own,
          ownPlus,
          factoryArgs,
          text,
          expects: expectations(fn, src),
        });
        return;
      }
    }
    ts.forEachChild(node, (ch) => visit(ch, inherited));
  };
  visit(src, []);
  return tests;
}

function grantKeys() {
  const f = path.join(
    repo,
    'src/app/test-utils/mock-permission-data.service.ts',
  );
  const keys = new Set();
  if (!fs.existsSync(f)) return keys;
  walk(parse(f), (n) => {
    if (ts.isInterfaceDeclaration(n) && n.name.text === 'PermissionGrants') {
      for (const m of n.members) if (m.name) keys.add(m.name.getText());
    }
  });
  return keys;
}

// The words a gate is written with in a test: `canEdit$` -> canEdit,
// `SystemPermission.ViewUsers` -> SystemPermission, ViewUsers.
function gateWords(gates) {
  const words = new Set();
  for (const g of gates) {
    for (const w of g.match(/[A-Za-z_][\w]*/g) ?? []) {
      if (/^can[A-Z]|[A-Z]\w*Permission$/.test(w) || /^[A-Z]/.test(w))
        words.add(w);
    }
  }
  return words;
}

const esc = (w) => w.replace(/[$]/g, '\\$');

// Every test of a spec that counts as a denied case for `gates`, best first.
//
// A test counts when its text (with factories, beforeEach and constants) sets
// up permissions and it asserts a denied shape. Which one is *named* matters to
// the reviewer, so candidates are ranked by where the permission setup is:
//   1. in the test's own text (with the constants it names): a grant
//      (permissionDataProviders, permissionApiStubs, PermissionGrants, a
//      *Permission.Member), one of the file's can* gates set false
//      (`canEdit: false`, `canEdit$: of(false)`, an it.each table with false
//      rows that names it), or a local factory called with a false
//      (`renderDialog(false)`);
//   2. a PermissionGrants key in its own text (`teams:` is also an ordinary
//      data key, so it ranks lower), or a grant only in the factory it calls,
//      a beforeEach or a constant;
//   3. only through a gate word that appears outside a false value (a factory
//      default `canManageRoles = true`, an allowed-side `canUploadView: true`).
// Within a rank, a denial word in the test name wins, then file order. The
// ranking only chooses the name --list prints; which files pass is unchanged.
function deniedCandidates(specFile, gates, keys, inputNames = []) {
  const words = gateWords(gates);
  for (const w of inputNames) words.add(w);
  const strongGrant = [
    'permissionDataProviders\\s*\\(',
    'permissionApiStubs\\s*\\(',
    '\\bPermissionGrants\\b',
    ENUM_PERMISSION.source,
  ].join('|');
  const keyGrant = [...keys].map((k) => `(?<![\\w$.])${esc(k)}\\s*:`).join('|');
  const grant = keyGrant ? `${strongGrant}|${keyGrant}` : strongGrant;
  const strongRe = new RegExp(strongGrant);
  const grantRe = new RegExp(grant);
  const setup = new RegExp(
    [grant, ...[...words].map((w) => `\\b${esc(w)}\\b`)].join('|'),
  );
  const canWords = [...words].filter(
    (w) => /^can[A-Z]/.test(w) || inputNames.includes(w),
  );
  const gateFalse = canWords.length
    ? new RegExp(
        `(?<![\\w$])(${canWords.map(esc).join('|')})\\$?\\s*(?:[:=,]\\s*(?:false\\b|of\\(\\s*false\\s*\\))|\\.next\\(\\s*false\\s*\\))`,
      )
    : null;
  const namesCan = canWords.length
    ? new RegExp(`(?<![\\w$])(${canWords.map(esc).join('|')})\\b`)
    : null;
  const falseRow = /\bfalse\b|(?<![\w>)\]])\[\s*\]/;
  const rank = (t) => {
    if (strongRe.test(t.ownPlus)) return 1;
    if (gateFalse && gateFalse.test(t.ownPlus)) return 1;
    if (namesCan && t.table && falseRow.test(t.table) && namesCan.test(t.own))
      return 1;
    // A factory called with a false (renderDialog(false), { canEdit: false }).
    if (t.factoryArgs.some((a) => /\bfalse\b|of\(\s*false\s*\)/.test(a)))
      return 1;
    if (grantRe.test(t.ownPlus) || strongRe.test(t.text)) return 2;
    return 3;
  };
  const strong =
    /without|lack|denie|deny|hide|hidden|cannot|can't|read-?only|restrict|disabl|near[- ]?miss|\bno\b/i;
  return testsOf(specFile)
    .map((t, index) => ({ ...t, index }))
    .filter(
      (t) =>
        setup.test(t.text) &&
        t.expects.some(
          (e) =>
            (MATRIX(e, t) ||
              DENIED_HINT.test(t.own.replace(/\.\s*not\s*\./g, '.'))) &&
            DENIED_SHAPES.some(([, ok]) => ok(e, t)),
        ),
    )
    .map((t) => ({ ...t, rank: rank(t) }))
    .sort(
      (a, b) =>
        a.rank - b.rank ||
        Number(strong.test(b.name)) - Number(strong.test(a.name)) ||
        a.index - b.index,
    );
}

// For --list: the best denied candidate whose own text names this gate.
function namingTest(candidates, gate) {
  const words = [...gateWords([gate])].filter(
    (w) => !/Permission$/.test(w) || !/\./.test(gate),
  );
  if (!words.length) return null;
  const re = new RegExp(`(?<![\\w$])(${words.map(esc).join('|')})\\b`);
  return candidates.find((t) => re.test(t.ownPlus)) ?? null;
}

function readAllowList() {
  for (const stray of files(path.join(repo, 'src'), (p) =>
    p.endsWith(`${path.sep}gates.allow.json`),
  )) {
    problems.push(
      `  ALLOW    ${rel(stray)} is an in-repo allow-list; it is not read and must not be committed. Move its entries to ${ALLOW_FILE} and delete it`,
    );
  }
  const f = ALLOW_PATH;
  if (!fs.existsSync(f)) return [];
  let entries;
  try {
    entries = JSON.parse(read(f));
  } catch (e) {
    problems.push(`  ALLOW    ${ALLOW_FILE} is not valid JSON: ${e.message}`);
    return [];
  }
  if (!Array.isArray(entries)) {
    problems.push(
      `  ALLOW    ${ALLOW_FILE} must be an array of { path, gates?, reason }`,
    );
    return [];
  }
  return entries.map((e, i) => ({ ...e, index: i }));
}

// Files that are not components but still need a spec beside them: every
// @Injectable service, Akita query that declares its own selectors, pipe,
// directive, guard, resolver and interceptor. Akita stores and queries with
// nothing but a constructor are wiring (the data service spec runs them with
// the real store) and are not counted. Reported as WARN this round
// (CHANGELOG 2026-10-09); FAIL from the next.
const UNIT_KINDS = [
  ['Pipe', 'pipe'],
  ['Directive', 'directive'],
  ['Guard', 'guard'],
  ['Resolver', 'resolver'],
  ['Interceptor', 'interceptor'],
  ['Query', 'query'],
  ['Injectable', 'service'],
];
const unitKind = (kinds) => {
  if (kinds.has('Component')) return null;
  if (kinds.has('Store') && !kinds.has('Query')) return null;
  if (kinds.has('WiringQuery')) return null;
  for (const [k, label] of UNIT_KINDS) if (kinds.has(k)) return label;
  return null;
};

function checkGates() {
  const list = opts.list;
  const keys = grantKeys();
  const allow = readAllowList();
  const used = new Set();
  const notes = [];
  const listed = [];
  for (const a of allow) {
    const where = `${ALLOW_FILE}[${a.index}] (${a.path ?? 'no path'})`;
    if (typeof a.reason !== 'string' || !a.reason.trim()) {
      problems.push(
        `  ALLOW    ${where} has no reason (say what the harness cannot render)`,
      );
    } else if (BUDGET_REASON.test(a.reason)) {
      problems.push(
        `  ALLOW    ${where} gives time or budget as the reason ("${a.reason}"); only a harness limitation is a reason`,
      );
    }
  }
  const sourceFiles = files(
    path.join(repo, 'src/app'),
    (p) =>
      p.endsWith('.ts') &&
      !p.endsWith('.spec.ts') &&
      !p.endsWith('.d.ts') &&
      !p.includes(`${path.sep}test-utils${path.sep}`) &&
      !p.includes(`${path.sep}generated${path.sep}`),
  ).sort();
  // components: with a spec + allowed without one + missing = total;
  // gated files: with a denied case + allowed + missing = total.
  const n = {
    components: 0,
    withSpec: 0,
    compAllowed: 0,
    compMissing: 0,
    gated: 0,
    gatedOk: 0,
    gatedAllowed: 0,
    gatesFound: 0,
    gatesInOk: 0,
    gatesNamed: 0,
    units: 0,
    unitsWithSpec: 0,
    unitsAllowed: 0,
    unitsMissing: 0,
    weak: 0,
    derived: 0,
    derivedOk: 0,
    missing: 0,
    provisional: 0,
  };
  // A gate the tests do not cover is missing (a failure), unless the check
  // that finds it was tightened in this standard version: then it is
  // provisional, a WARN line, for this version only (GLOSSARY.md).
  const report = (tag, text) => {
    if (PROVISIONAL.has(tag)) {
      n.provisional++;
      warnings.push(`  WARN     provisional: ${tag} ${text}`);
    } else {
      n.missing++;
      problems.push(`  ${tag.padEnd(8)} missing: ${text}`);
    }
  };
  const sources = new Map();
  for (const f of sourceFiles) {
    const text = read(f);
    for (const m of text.matchAll(/\.(can[A-Z]\w*\$?)\s*=(?![=>])/g)) {
      if (!/this\s*$/.test(text.slice(Math.max(0, m.index - 6), m.index)))
        EXTERNALLY_SET.add(m[1]);
    }
    sources.set(f, readSource(f));
  }
  for (const s of sources.values()) {
    for (const m of s.templateText.matchAll(/\[(can[A-Z]\w*\$?)\]\s*=/g))
      EXTERNALLY_SET.add(m[1]);
  }
  for (const f of sourceFiles) {
    const source = sources.get(f);
    const isComponent = source.kinds.has('Component');
    let gates = gatesOf(source);
    const unit = unitKind(source.kinds);
    const r = rel(f);
    const spec = f.replace(/\.ts$/, '.spec.ts');
    const hasSpec = fs.existsSync(spec);
    const entries = allow.filter((a) => a.path === r);
    const gateReader =
      gates.length &&
      (isComponent ||
        source.kinds.has('Directive') ||
        source.kinds.has('Guard'));
    if (!isComponent && !gateReader) {
      // A service, pipe, directive, guard, resolver or interceptor that reads
      // no permission: it needs a spec beside it.
      if (!unit) continue;
      n.units++;
      if (hasSpec) {
        n.unitsWithSpec++;
        continue;
      }
      const whole = entries.find(
        (a) => !(Array.isArray(a.gates) && a.gates.length),
      );
      for (const a of entries) used.add(a.index);
      if (whole) {
        n.unitsAllowed++;
        notes.push(`  NOTE     allowed ${r}: ${whole.reason ?? '(no reason)'}`);
        continue;
      }
      n.unitsMissing++;
      report(
        'NOSPEC',
        `${r} (${unit}) has no spec beside it (a behaviour spec of the class at ${rel(spec)}, or an allow-list entry saying why it is pure wiring)`,
      );
      continue;
    }
    if (isComponent) n.components++;
    if (hasSpec && isComponent) n.withSpec++;
    let wholeFile = null;
    for (const a of entries) {
      used.add(a.index);
      if (Array.isArray(a.gates) && a.gates.length) {
        for (const g of a.gates) {
          if (!gates.includes(g)) {
            problems.push(
              `  ALLOW    ${ALLOW_FILE}[${a.index}] (${r}) names gate ${g}, which the check does not find there`,
            );
          }
        }
        gates = gates.filter((g) => !a.gates.includes(g));
        notes.push(
          `  NOTE     allowed ${r} gates ${a.gates.join(', ')}: ${a.reason ?? '(no reason)'}`,
        );
      } else {
        wholeFile = a;
      }
    }
    if (wholeFile) {
      // A whole-file entry excuses the file: its smoke spec and its gates.
      if (isComponent && !hasSpec) n.compAllowed++;
      if (gates.length) (n.gated++, n.gatedAllowed++);
      notes.push(
        `  NOTE     allowed ${r}: ${wholeFile.reason ?? '(no reason)'}`,
      );
      if (list && gates.length)
        listed.push(`  GATED    ${r} [allowed]: ${gates.join(', ')}`);
      continue;
    }
    if (!gates.length) {
      if (!hasSpec) {
        if (isComponent) n.compMissing++;
        report(
          'NOSPEC',
          `${r} has no spec beside it (start from templates/component-smoke.spec.template.ts)`,
        );
      }
      continue;
    }
    n.gated++;
    n.gatesFound += gates.length;
    let state;
    let candidates = [];
    if (!hasSpec) {
      state = 'no spec';
      if (isComponent) n.compMissing++;
      report(
        'UNTESTED',
        `${r} reads permissions and has no spec; gates: ${gates.join(', ')}`,
      );
    } else if (!(candidates = deniedCandidates(spec, gates, keys)).length) {
      state = 'no denied case';
      report(
        'NODENIED',
        `${rel(spec)} has no denied case; gates: ${gates.join(', ')}`,
      );
    } else {
      const best = candidates[0];
      const from = [
        '',
        'own setup',
        'factory or beforeEach setup',
        'gate word only',
      ][best.rank];
      if (best.rank === 3) {
        state = `weak, denied case ${best.name} (${from})`;
        n.weak++;
        report(
          'WEAKDENY',
          `${rel(spec)}: no denied case sets a permission in its own text; the one counted (${best.name}) matches only through a gate word elsewhere (set the gate false or pass the near-miss grant in the test itself)`,
        );
      } else {
        state = `ok, denied case ${best.name} (${from})`;
        n.gatedOk++;
        n.gatesInOk += gates.length;
      }
    }
    for (const g of gates) if (namingTest(candidates, g)) n.gatesNamed++;
    if (list) {
      listed.push(`  GATED    ${r} [${state}]: ${gates.join(', ')}`);
      if (candidates.length) {
        for (const g of gates) {
          const t = namingTest(candidates, g);
          listed.push(
            `             ${g}: ${t ? `denied in ${t.name}` : 'no denied test names it'}`,
          );
        }
      }
    }
  }
  // Inputs bound from a parent's permission value under another name
  // (`[showAdminButton]="canViewAdministration"`): the gate lives in the
  // child's template, so the child's spec needs a denied case for that input.
  const bySelector = new Map();
  for (const [f, s] of sources) {
    if (s.kinds.has('Component'))
      for (const sel of s.selectors) bySelector.set(sel, f);
  }
  const derived = new Map(); // child file -> Map(input -> [parent, expr])
  for (const [f, s] of sources) {
    if (!s.kinds.has('Component') || !s.templateRaw) continue;
    const parentGates = gatesOf(s).map((g) => g.replace(/\$$/, ''));
    for (const m of s.templateRaw.matchAll(/<([a-z][\w-]*)\b([^>]*)>/g)) {
      const child = bySelector.get(m[1]);
      if (!child || child === f) continue;
      const cs = sources.get(child);
      for (const b of m[2].matchAll(/\[(\w+)\]\s*=\s*"([^"]*)"/g)) {
        const [, input, expr] = b;
        if (isCanName(input) || !cs.inputs.has(input)) continue;
        const reads =
          /(?<![\w$])can[A-Z]\w*|[A-Z]\w*Permission\./.test(expr) ||
          parentGates.some((g) => g && expr.includes(g));
        if (!reads) continue;
        if (!derived.has(child)) derived.set(child, new Map());
        if (!derived.get(child).has(input))
          derived.get(child).set(input, [rel(f), expr.trim()]);
      }
    }
  }
  for (const [child, map] of [...derived].sort()) {
    const spec = child.replace(/\.ts$/, '.spec.ts');
    const hasSpec = fs.existsSync(spec);
    for (const [input, [parent, expr]] of map) {
      // The test names the input in its own text, or in its name
      // ('disables editing in read-only mode' for readOnly).
      const flat = (x) => x.toLowerCase().replace(/[^a-z]/g, '');
      const t = hasSpec
        ? deniedCandidates(spec, [], keys, [input]).find(
            (c) =>
              new RegExp(`\\b${esc(input)}\\b`).test(c.ownPlus) ||
              flat(c.name).includes(flat(input)),
          )
        : null;
      if (list)
        listed.push(
          `  DERIVED  ${rel(child)} input ${input} <- ${parent} [${expr}]: ${t ? `denied in ${t.name}` : 'no denied case names it'}`,
        );
      n.derived++;
      if (t) n.derivedOk++;
      else
        report(
          'DERIVED',
          `${rel(child)} input ${input} is bound from a permission value in ${parent} ("${expr}"); ${hasSpec ? 'no denied case in its spec names it' : 'it has no spec'}`,
        );
    }
  }
  for (const a of allow) {
    if (!used.has(a.index)) {
      notes.push(
        `  NOTE     stale: ${ALLOW_FILE}[${a.index}] (${a.path ?? 'no path'}) matches no component, service, pipe, directive, guard, resolver or interceptor (delete or correct the entry)`,
      );
    }
  }
  trailer.push(...listed, ...notes);
  const gatedMissing = n.gated - n.gatedOk - n.gatedAllowed;
  trailer.push(
    `  SUMMARY  components ${n.components} (${n.withSpec} with a spec, ${n.compAllowed} allowed, ${n.compMissing} missing); gated files ${n.gated} (${n.gatedOk} with a denied case, ${n.gatedAllowed} allowed, ${gatedMissing} missing${n.weak ? `, ${n.weak} of them WEAKDENY` : ''}); gates ${n.gatesFound} found, ${n.gatesInOk} in files with a denied case, ${n.gatesNamed} named by a denied test; derived inputs ${n.derived} (${n.derivedOk} with a denied case, ${n.derived - n.derivedOk} missing); other units ${n.units} (${n.unitsWithSpec} with a spec, ${n.unitsAllowed} allowed, ${n.unitsMissing} missing); ${n.missing} missing, ${n.provisional} provisional`,
  );
}

// --- removed ---------------------------------------------------------------
//
// No test is lost without a line saying where its behaviour went
// (testing/README.md, "Removed-test accounting"). Compares the test titles of
// every spec under src at the merge base with --base (default origin/main)
// against the working tree (uncommitted and untracked files included): an
// it/test title whose count drops, an it.each/test.for table with fewer literal
// rows, every test of a deleted spec file. The script accounts for a removal
// itself when the match is mechanical: the title moved to another spec with an
// identical body, it was renamed in the same spec and describe with an
// identical body, or the rows an it.each lost are rows of another it.each of
// the spec with an identical body; without --base those lines are written to
// agent-docs/ui-test-bugs/<app>.removed-tests-matched.md. Every other removed
// title needs a line in agent-docs/ui-test-bugs/<app>.removed-tests-<date>.md:
//   `<old title>` -> A -> `<new title>`   renamed or rewritten, same behaviour
//   `<old title>` -> B -> `<new title>`   merged into another test
//   `<old title>` -> C -> `<new title>`   replaced by a behaviour test
//   `<old title>` -> D -> <reason>        dropped: the unreachable branch or
//                                         dead code it tested, or the e2e home
//                                         of a behaviour jsdom cannot express
//   `<old title>` -> E -> `<path>`        removed with the production code it
//                                         tested (the named file is gone)
// The named new title of A/B/C must exist in the tree; a D reason may not be
// time, budget or "trivial". The file context is the line's own spec path, the
// first cell of a table row, or the nearest heading that names a spec path.
// A removal with no valid line fails; a line's format is a NOTE.
const BAD_REASON =
  /\b(trivial|budget|time|later|follow[- ]?up|todo|tbd|ran out|not worth)\b/i;

// Comments dropped and formatting normalized, so two copies of one body compare
// equal however they were indented.
const printer = ts.createPrinter({ removeComments: true });
const canon = (node, src) =>
  node
    ? printer
        .printNode(ts.EmitHint.Unspecified, node, src)
        .replace(/\s+/g, ' ')
        .trim()
    : '';

function titlesOf(text, file) {
  const src = ts.createSourceFile(file, text, ts.ScriptTarget.Latest, true);
  const out = [];
  // The titles of the describe blocks around a node, outermost first.
  const describesOf = (node) => {
    const chain = [];
    for (let p = node.parent; p; p = p.parent) {
      if (!ts.isCallExpression(p)) continue;
      let callee = p.expression;
      if (ts.isCallExpression(callee)) callee = callee.expression;
      const head = callee.getText(src).split('.')[0];
      if (head === 'describe' && p.arguments[0])
        chain.unshift(
          ts.isStringLiteralLike(p.arguments[0])
            ? p.arguments[0].text
            : p.arguments[0].getText(src),
        );
    }
    return chain.join(' > ');
  };
  walk(src, (n) => {
    if (!ts.isCallExpression(n)) return;
    let e = n.expression;
    let rows = 1;
    let each = false;
    let rowTexts = [];
    if (ts.isCallExpression(e)) {
      if (!ts.isPropertyAccessExpression(e.expression)) return;
      if (!['each', 'for'].includes(e.expression.name.text)) return;
      const table = e.arguments[0];
      if (table && ts.isArrayLiteralExpression(table)) {
        rows = table.elements.length;
        rowTexts = table.elements.map((el) => canon(el, src));
      }
      each = true;
      e = e.expression.expression;
    } else if (ts.isTaggedTemplateExpression(e)) {
      return;
    }
    const parts = e.getText(src).split('.');
    if (!['it', 'test'].includes(parts[0])) return;
    if (
      parts
        .slice(1)
        .some(
          (p) =>
            !['only', 'concurrent', 'sequential', 'skip', 'todo'].includes(p),
        )
    )
      return;
    const skipped = parts.some((p) => ['skip', 'todo'].includes(p));
    const a = n.arguments[0];
    if (!a) return;
    let title;
    if (ts.isStringLiteralLike(a)) title = a.text;
    else if (ts.isTemplateExpression(a)) title = a.getText(src).slice(1, -1);
    else title = a.getText(src);
    out.push({
      title,
      rows,
      rowTexts,
      each,
      skipped,
      body: canon(n.arguments[1], src),
      describes: describesOf(n),
      line: lineOf(src, n),
      end: src.getLineAndCharacterOfPosition(n.getEnd()).line + 1,
    });
  });
  return out.filter((t) => !t.skipped);
}

const reEscape = (x) => x.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
// A title as a pattern: template-literal parts and it.each placeholders match
// anything.
const titlePattern = (t) =>
  reEscape(t)
    .replace(/\\\$\\\{[^}]*\\\}/g, '.+?')
    .replace(/%[sdifjo#%]|\\\$[\w.]+/g, '.+?');

const MATCHED_SUFFIX = '.removed-tests-matched.md';
function accountingLines() {
  const dir = path.join(AGENT_DOCS, 'ui-test-bugs');
  const out = [];
  if (!fs.existsSync(dir)) return { files: [], lines: out };
  const names = fs
    .readdirSync(dir)
    .filter(
      (f) =>
        f.startsWith(`${app}.removed-tests`) &&
        f.endsWith('.md') &&
        f !== `${app}${MATCHED_SUFFIX}`,
    )
    .sort();
  const specPath = /`?((?:[\w.-]+\/)*[\w.-]+\.spec\.ts)`?/;
  for (const name of names) {
    let heading = null;
    let section = '';
    read(path.join(dir, name))
      .split('\n')
      .forEach((line, i) => {
        const h = /^(#+)\s+(.*)$/.exec(line);
        if (h) {
          heading = specPath.exec(h[2])?.[1] ?? null;
          if (h[1].length <= 2) section = h[2];
          return;
        }
        const own = specPath.exec(line)?.[1] ?? null;
        const cell = /^\|\s*`?([\w.-]+)`?\s*\|/.exec(line)?.[1] ?? null;
        out.push({
          file: name,
          n: i + 1,
          text: line,
          ctx: own ?? (cell && !/^-+$/.test(cell) ? cell : null) ?? heading,
          dSection: /^D\b/.test(section),
          used: false,
        });
      });
  }
  return { files: names, lines: out };
}

const ctxMatches = (file, ctx) => {
  if (!ctx) return true;
  if (ctx.endsWith('.spec.ts')) return file === ctx || file.endsWith(`/${ctx}`);
  return path.basename(file).startsWith(`${ctx}.`);
};

// The disposition a line gives `title`, or null. The title and what follows
// it are matched as one pattern, so a template part (`${perm}`) stretches to
// meet the arrow.
//   `title` (a note, maybe with `code()`) -> X -> rest     a list line
//   | `title` | **X** -> rest |                            a table row
const NOTE_THEN = '\\s*`*\\s*(?:\\((?:[^()]|\\([^()]*\\))*\\)\\s*)?`*\\s*';
const DISP =
  '(?:->|\\|)\\s*(?:\\*\\*)?([A-E])(?:\\*\\*)?(?=[\\s.:,;)|]|$)\\s*(?:->|:)?\\s*(.*)$';
function disposition(line, title) {
  const head = `(?<![A-Za-z0-9])${titlePattern(title)}${NOTE_THEN}`;
  const d = new RegExp(head + DISP).exec(line.text);
  if (d) return { letter: d[1], rest: d[2], inferred: false };
  // A row of a "D" table that carries no letter of its own.
  if (line.dSection && /^\s*\|/.test(line.text)) {
    const c = new RegExp(`${head}\\|(.*)$`).exec(line.text);
    if (c)
      return { letter: 'D', rest: c[1].replace(/\|/g, ';'), inferred: true };
  }
  return null;
}

function checkRemoved() {
  const git = (...args) =>
    execFileSync('git', ['-C', repo, ...args], {
      encoding: 'utf8',
      maxBuffer: 256 * 1024 * 1024,
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  let base;
  try {
    base = git('merge-base', 'HEAD', opts.base).trim();
  } catch {
    problems.push(
      `  REMOVED  no merge base with ${opts.base} (fetch it, or pass --base <ref>); removed tests not checked`,
    );
    return;
  }
  const baseSpecs = git('ls-tree', '-r', '--name-only', base, '--', 'src')
    .split('\n')
    .filter((f) => f.endsWith('.spec.ts'));
  const treeSpecs = files(path.join(repo, 'src'), (p) =>
    p.endsWith('.spec.ts'),
  ).map(rel);
  const renamedSpec = new Map();
  for (const line of git('diff', '-M', '--name-status', base, '--', 'src').split('\n')) {
    const r = /^R\d*\t(.+)\t(.+)$/.exec(line);
    if (r) renamedSpec.set(r[1], r[2]);
  }
  const baseSet = new Set(baseSpecs);
  const tree = new Map();
  for (const f of treeSpecs) tree.set(f, titlesOf(read(path.join(repo, f)), f));
  const allTree = [...tree.entries()].flatMap(([f, ts_]) =>
    ts_.map((t) => ({ ...t, file: f })),
  );
  const treeTitles = new Set(allTree.map((t) => t.title));
  const treeTemplates = allTree
    .filter((t) => t.each || /\$\{/.test(t.title))
    .map((t) => new RegExp(`^${titlePattern(t.title)}$`));
  const inTree = (title) =>
    treeTitles.has(title) || treeTemplates.some((re) => re.test(title));
  const count = (list) => list.reduce((sum, t) => sum + t.rows, 0);
  let baseCount = 0;
  const removed = [];
  const matched = [];
  let added = 0;
  const baseTitlesByFile = new Map();
  for (const f of baseSpecs) {
    const before = titlesOf(git('show', `${base}:${f}`), f);
    baseTitlesByFile.set(f, before);
    baseCount += count(before);
  }
  for (const [f, list] of tree) {
    const old = new Set(
      (baseTitlesByFile.get(f) ?? baseTitlesByFile.get([...renamedSpec].find(([, to]) => to === f)?.[0]) ?? []).map((t) => t.title),
    );
    added += list.filter((t) => !old.has(t.title)).length;
  }
  for (const f of baseSpecs) {
    const before = baseTitlesByFile.get(f);
    const target = renamedSpec.get(f) ?? f;
    const after = tree.get(target) ?? tree.get(f) ?? [];
    const beforeTitles = new Set(before.map((t) => t.title));
    const left = new Map();
    for (const t of after) left.set(t.title, [...(left.get(t.title) ?? []), t]);
    for (const t of before) {
      const same = left.get(t.title);
      if (same && same.length) {
        const kept = same.shift();
        if (t.each && kept.rows < t.rows) {
          const lost = t.rowTexts.filter((r) => !kept.rowTexts.includes(r));
          const into = after.find(
            (x) =>
              x !== kept &&
              x.each &&
              x.body === t.body &&
              lost.length &&
              lost.every((r) => x.rowTexts.includes(r)),
          );
          if (into)
            matched.push({
              file: f,
              title: t.title,
              letter: 'B',
              to: into.title,
              why: `${lost.length} it.each row${lost.length > 1 ? 's' : ''} merged into an it.each with an identical body`,
            });
          else
            removed.push({
              file: f,
              title: t.title,
              rows: `${t.rows} -> ${kept.rows} rows`,
            });
        }
        continue;
      }
      // Moved with its file: the same title in a new spec of the same name, or
      // the same title with an identical body in a spec the base did not have.
      const moved = allTree.find(
        (x) =>
          x.file !== f &&
          x.file !== target &&
          !baseSet.has(x.file) &&
          x.title === t.title &&
          (path.basename(x.file) === path.basename(f) || (t.body && x.body === t.body)),
      );
      if (moved) continue;
      // Renamed in place: a title the base's spec did not have, in the same
      // spec and describe, with an identical body.
      const renamedTo = after.filter(
        (x) =>
          !beforeTitles.has(x.title) &&
          x.body &&
          x.body === t.body &&
          x.describes === t.describes &&
          x.rows >= t.rows,
      );
      if (renamedTo.length === 1) {
        matched.push({
          file: f,
          title: t.title,
          letter: 'A',
          to: renamedTo[0].title,
          why: 'renamed; identical body',
        });
        continue;
      }
      removed.push({ file: f, title: t.title, deleted: !tree.has(target) });
    }
  }
  const treeCount = count(allTree);
  // The script's own lines, regenerated on a run against the default base.
  const matchedName = `${app}${MATCHED_SUFFIX}`;
  const matchedFile = path.join(AGENT_DOCS, 'ui-test-bugs', matchedName);
  if (!opts.baseGiven && opts.write) {
    if (matched.length) {
      const byFile = new Map();
      for (const x of matched) byFile.set(x.file, [...(byFile.get(x.file) ?? []), x]);
      const text = [
        `# ${app}: removed tests matched by the script`,
        '',
        `Written by \`check-repo.js removed\` against the merge base with origin/main (${base.slice(0, 8)}); regenerated on every run without \`--base\`, so never edit it: judged lines go in the dated accounting file beside it (testing/README.md, "Removed-test accounting"). ${matched.length} matched.`,
        '',
        ...[...byFile]
          .sort(([a], [b]) => (a < b ? -1 : 1))
          .flatMap(([f, xs]) => [
            `## ${f}`,
            '',
            ...xs.map((x) => `- \`${x.title}\` -> ${x.letter} -> \`${x.to}\` (${x.why})`),
            '',
          ]),
      ].join('\n');
      if (!fs.existsSync(matchedFile) || read(matchedFile) !== text)
        fs.writeFileSync(matchedFile, text);
    } else if (fs.existsSync(matchedFile)) fs.unlinkSync(matchedFile);
  }
  const acct = accountingLines();
  const tally = { A: 0, B: 0, C: 0, D: 0, E: 0 };
  let unaccounted = 0;
  const where = `agent-docs/ui-test-bugs/${app}.removed-tests-<date>.md`;
  for (const r of removed) {
    // Best line: one that names this spec, then one with an explicit letter
    // (a D-table row without one comes last), then file order.
    const hits = [];
    for (const line of acct.lines) {
      if (line.used || !ctxMatches(r.file, line.ctx)) continue;
      const d = disposition(line, r.title);
      if (d) hits.push({ line, ...d });
    }
    hits.sort(
      (a, b) =>
        Number(!a.line.ctx) - Number(!b.line.ctx) ||
        Number(a.inferred) - Number(b.inferred),
    );
    const hit = hits[0] ?? null;
    const label = `${r.file}: '${r.title}'${r.rows ? ` (it.each ${r.rows})` : ''}${r.deleted ? ' (spec file deleted)' : ''}`;
    if (!hit) {
      unaccounted++;
      problems.push(`  REMOVED  ${label} has no line in ${where}`);
      continue;
    }
    hit.line.used = true;
    const at = `${hit.line.file}:${hit.line.n}`;
    let bad = null;
    if ('ABC'.includes(hit.letter)) {
      // Backticked titles (`describe > title` names the last part too), and
      // the quoted title inside backticked code (`it.each(rows)('... %s')`).
      const named = [...hit.rest.matchAll(/`+([^`]+)`+/g)].flatMap((m) => [
        m[1].trim(),
        m[1].split(' > ').pop().trim(),
        ...[...m[1].matchAll(/(['"])((?:(?!\1).)+)\1/g)].map((q) => q[2]),
      ]);
      if (!named.some(inTree))
        bad = `${hit.letter} line names no test that exists in the tree`;
    } else if (hit.letter === 'D') {
      const reason = hit.rest.replace(/[`|;*\s]+/g, ' ').trim();
      if (!reason || BAD_REASON.test(reason))
        bad = `D line gives no reason the standard accepts ("${reason.slice(0, 80)}"); name the unreachable branch or dead code (never time, budget or "trivial")`;
    } else {
      const paths = [
        ...hit.rest.matchAll(/((?:src\/)?[\w./-]+\.(?:ts|html))/g),
      ].map((m) => m[1]);
      const gone = paths.filter(
        (p) =>
          !fs.existsSync(path.join(repo, p)) &&
          !fs.existsSync(path.join(repo, 'src/app', p)),
      );
      if (!gone.length)
        bad = `E line names no production file that is gone from the tree`;
    }
    if (bad) {
      unaccounted++;
      problems.push(`  REMOVED  ${at} '${r.title}': ${bad}`);
      continue;
    }
    if (hit.inferred)
      notes.push(
        `  NOTE     accounting: ${at} the D table row for '${r.title}' carries no letter (write \`- \\\`title\\\` -> D -> <reason>\`)`,
      );
    tally[hit.letter]++;
    if (hit.letter === 'D' && opts.dLines)
      trailer.push(`  D-LINE   ${at}: ${hit.line.text.trim()}`);
  }
  if (removed.length && !acct.files.length)
    notes.push(`  NOTE     accounting: ${removed.length} removed test(s) and no ${where}`);
  if (treeCount < baseCount && unaccounted)
    notes.push(
      `  NOTE     count: the tree has fewer tests than ${opts.base} (${treeCount} < ${baseCount}) and ${unaccounted} removed title(s) are unaccounted`,
    );
  trailer.push(
    `  SUMMARY  base ${base.slice(0, 8)} (${opts.base}): ${baseCount} tests in ${baseSpecs.length} spec files; tree: ${treeCount} tests in ${treeSpecs.length} spec files, ${added} titles added (static count: it/test calls plus literal it.each rows); removed ${removed.length + matched.length} (matched by the script ${matched.length}; accounted ${removed.length - unaccounted}: A ${tally.A}, B ${tally.B}, C ${tally.C}, D ${tally.D}, E ${tally.E}; unaccounted ${unaccounted}); accounting: ${[...acct.files, ...(matched.length && fs.existsSync(matchedFile) ? [matchedName] : [])].join(', ') || 'none'}`,
  );
}

if (mode === 'helpers') checkHelpers();
else if (mode === 'specs') {
  checkSpecs();
  checkDefectTests();
} else if (mode === 'gates') checkGates();
else checkRemoved();
problems.forEach((p) => console.log(p));
warnings.forEach((w) => console.log(w));
notes.forEach((n) => console.log(n));
trailer.forEach((t) => console.log(t));
process.exit(problems.length || (opts.strict && warnings.length) ? 1 : 0);
