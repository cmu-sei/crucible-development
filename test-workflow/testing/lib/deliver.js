#!/usr/bin/env node
// The logic behind testing/deliver.sh; see its header for usage. Plain Node, no dependencies; runs git
// and gh. The rules it follows are orchestration/RULES.md, Delivery: commit and push only on the user's
// word (push needs the batch id of the summary the user saw), the person delivering is the author (their own
// git identity and gh account, no attribution, scans before and after), brief commits and one 2-5 line PR
// comment per push, identity and auth first. The commit-message file and the other files are described in
// testing/README.md.
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawnSync } = require('child_process');

const TESTING = path.join(__dirname, '..');
const STANDARDS = path.join(TESTING, '..');
// The workspace docs (test-work/, the defect docs, the allow-lists): on the /mnt/data volume, never in the
// checkout this script runs from. CRUCIBLE_ROOT overrides /mnt/data/crucible.
const DOCS = path.join(process.env.CRUCIBLE_ROOT || '/mnt/data/crucible', 'agent-docs');
// orchestration/RULES.md, Delivery: must print nothing for author, committer, message, PR author, body,
// commits and comments.
const ATTRIBUTION = /claude|anthropic|openai|gpt|codex|oh.my.pi|\bomp\b|co-authored|generated with|🤖|created by/i;
const SUBJECT_MAX = 71; // "under 72 characters"
const WRITER_BODY_MAX = 4; // deliver.sh adds the tests and gates lines: six in all

const argv = process.argv.slice(2);
const mode = argv[0];
const opts = { batch: null, dryRun: false, worktrees: [] };
for (let i = 1; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--batch') opts.batch = argv[++i];
  else if (a.startsWith('--batch=')) opts.batch = a.slice(8);
  else if (a === '--dry-run') opts.dryRun = true;
  else if (a.startsWith('-')) die(`unknown option ${a}`);
  else opts.worktrees.push(path.resolve(a));
}
if (!['summary', 'push'].includes(mode) || !opts.worktrees.length || (mode === 'push' && !opts.batch)) {
  die('usage: deliver.sh summary <worktree>...\n       deliver.sh push --batch <id> [--dry-run] <worktree>...', 2);
}

function die(msg, code = 2) { console.error(`deliver.sh: ${msg}`); process.exit(code); }
function run(cmd, args, o = {}) {
  const r = spawnSync(cmd, args, { encoding: 'utf8', maxBuffer: 1 << 28, ...o });
  return { code: r.status === null ? 1 : r.status, out: (r.stdout || '').trim(), raw: r.stdout || '', err: (r.stderr || '').trim() };
}
const git = (w, ...a) => run('git', ['-C', w, ...a]);
const sha1 = (s) => crypto.createHash('sha1').update(s).digest('hex');
const indent = (text, p = '  | ') => text.split('\n').map((l) => `${p}${l}`.trimEnd()).join('\n');

// --- once per run ------------------------------------------------------------------------------------
const gh = run('gh', ['auth', 'status']);
const ghText = `${gh.out}\n${gh.err}`;
const ghOk = gh.code === 0;
const ghScopes = (/Token scopes:\s*(.*)/.exec(ghText) || [])[1] || '';
const ghLogin = ghOk ? run('gh', ['api', 'user', '-q', '.login']).out : '';

// --- per repo ------------------------------------------------------------------------------------------
function stackOf(w) { return fs.existsSync(path.join(w, 'angular.json')) ? 'ui' : 'api'; }

// What a test delivery may change (orchestration/RULES.md, Scope: tests only). Anything else stops it.
function isTestFile(stack, f, testDir) {
  if (stack === 'api') {
    return (testDir && (f === testDir || f.startsWith(`${testDir}/`))) || f === '.github/workflows/build-and-test.yml'
      || f === '.editorconfig' || f === 'Directory.Packages.props' || /\.slnx?$/.test(f) || f === 'docs/Testing.md';
  }
  return /\.spec\.ts$/.test(f) || f.startsWith('src/app/test-utils/') || f.startsWith('patches/')
    || ['src/test-setup.ts', 'vitest.config.ts', 'tsconfig.spec.json', 'angular.json', 'package.json', 'package-lock.json',
      '.github/workflows/build_test.yml', 'README.md'].includes(f);
}

function check(stack, w, app, mode, extra = []) {
  const script = path.join(STANDARDS, `${stack}-testing`, 'check-repo.js');
  const args = stack === 'api' ? [script, mode, w, app, ...extra] : [script, mode, w, '--app', app, ...extra];
  return run('node', args);
}

function collect(w) {
  const app = path.basename(w);
  const stack = stackOf(w);
  const r = { w, app, stack, stops: [], oks: [], info: [] };
  const stop = (m) => r.stops.push(m);
  const ok = (m) => r.oks.push(m);
  if (!fs.existsSync(path.join(w, '.git'))) { stop(`${w} is not a worktree`); return r; }
  const work = path.join(DOCS, 'test-work', app);
  r.work = work;
  r.branch = git(w, 'branch', '--show-current').out;
  const url = git(w, 'remote', 'get-url', 'origin').out;
  r.slug = (/github\.com[:/](.+?)(?:\.git)?$/.exec(url) || [])[1] || null;
  if (!r.branch) stop('detached HEAD: deliver from the test branch');
  if (!r.slug) stop(`origin is not a GitHub remote (${url})`);
  const fetched = git(w, 'fetch', '-q', 'origin');
  if (fetched.code !== 0) r.info.push(`git fetch failed (${fetched.err.split('\n')[0]}); origin as last fetched`);
  r.head = git(w, 'rev-parse', 'HEAD').out;
  r.originSha = git(w, 'rev-parse', '-q', '--verify', `refs/remotes/origin/${r.branch}`).out;
  const behind = r.originSha ? Number(git(w, 'rev-list', '--count', `HEAD..origin/${r.branch}`).out) : 0;
  r.ahead = r.originSha ? Number(git(w, 'rev-list', '--count', `origin/${r.branch}..HEAD`).out) : Number(git(w, 'rev-list', '--count', 'HEAD').out);
  if (behind) stop(`origin/${r.branch} has ${behind} commit(s) this worktree lacks: someone else pushed; stop and ask`);
  else ok(`level with origin/${r.branch} (${r.originSha ? `${r.ahead} local commit(s) not pushed` : 'branch not on origin yet'})`);

  // Identity and auth (RULES, Delivery): the person delivering is the author, so the identity is theirs, read
  // from git config and the gh login; a missing one stops the repo.
  const name = git(w, 'config', 'user.name').out;
  const email = git(w, 'config', 'user.email').out;
  r.identity = name && email ? `${name} <${email}>` : '';
  if (!r.identity) stop(`git identity is incomplete (user.name '${name}', user.email '${email}'): the person delivering sets their own with git config --global user.name and user.email; ask the user`);
  else ok(`identity ${r.identity}`);
  if (!ghOk) stop('gh is not authenticated (gh auth status): the person delivering logs in with gh auth login; ask the user');
  else if (!ghLogin) stop('gh is authenticated but its login could not be read (gh api user): ask the user');
  else ok(`gh account ${ghLogin}`);

  // The tree: only test files changed, nothing forbidden in it.
  const proj = run('bash', ['-c', `cd "${w}" && find . -name '*.Tests.csproj' -not -path '*/bin/*' -not -path '*/obj/*' | sed 's|^\\./||' | head -1`]).out;
  const testDir = proj ? path.posix.dirname(proj) : null;
  r.changes = git(w, 'status', '--porcelain=v1', '-uall').raw.split('\n').filter(Boolean).map((l) => ({ xy: l.slice(0, 2), file: l.slice(3).replace(/^.* -> /, '') }));
  r.deleted = r.changes.filter((c) => c.xy.includes('D')).map((c) => c.file);
  const production = r.changes.filter((c) => !isTestFile(stack, c.file, testDir)).map((c) => c.file);
  if (production.length) stop(`files outside the tests changed (tests-only scope; a broken-gate edit not restored?): ${production.join(', ')}`);
  else ok(`${r.changes.length} changed file(s), all test files`);
  const workflows = r.changes.some((c) => c.file.startsWith('.github/workflows/'));
  if (workflows && !/\bworkflow\b/.test(ghScopes)) stop('the push touches .github/workflows and the gh token has no workflow scope: ask the user');
  const forbidden = git(w, 'ls-files', '-co', '--exclude-standard').out.split('\n').filter((f) => /(^|\/)(NOTES\.md|untested-gates\.txt|gates\.allow\.json)$/.test(f) && !f.includes('node_modules/'));
  if (forbidden.length) stop(`files that never ship are in the tree: ${forbidden.join(', ')}`);

  // The verify log for this exact tree.
  r.tree = run(path.join(TESTING, 'tree-hash.sh'), [w]).out;
  const vlog = path.join(work, `verify-${r.tree}.log`);
  const cur = run(path.join(TESTING, 'tree-hash.sh'), ['--check', vlog, w]);
  const vtext = fs.existsSync(vlog) ? fs.readFileSync(vlog, 'utf8') : '';
  if (cur.code !== 0) stop(`no current verify log for tree ${r.tree.slice(0, 12)}: ${cur.out}; run ${stack}-testing/verify.sh`);
  else if (!/^== 0 check\(s\) failed/m.test(vtext)) stop(`the verify log ${vlog} has failed checks`);
  else ok(`verify log ${path.relative(DOCS, vlog)} current and passing`);
  r.tests = (stack === 'api' ? /dotnet test \(Failed: \d+, Passed: (\d+)/ : /npm test \(Tests\s+(\d+) passed/).exec(vtext)?.[1] || '?';

  // Gates and removed tests, now (cheap; the summary must say what this tree has).
  const g = check(stack, w, app, 'gates');
  r.gatesLine = stack === 'api' ? ((/^\s*(\(gates: .*\))\s*$/m.exec(g.out) || [])[1] || '') : ((/^\s*SUMMARY\s+(.*)$/m.exec(g.out) || [])[1] || '');
  const gm = /(\d+) missing, (\d+) provisional\)?\s*$/.exec(r.gatesLine);
  if (g.code !== 0 || !gm || gm[1] !== '0' || gm[2] !== '0') stop(`gates: ${r.gatesLine || 'no summary'} (a missing or provisional gate blocks delivery)`);
  else ok(`gates: 0 missing, 0 provisional`);
  r.allowed = stack === 'api'
    ? [...g.raw.matchAll(/^  ALLOWED  (\S+) \(line \d+\): .*?Reason: (.*)$/gm)].map((m) => `- \`${m[1]}\`: ${m[2]}`)
      : [...g.raw.matchAll(/^  NOTE     allowed (\S+?)(?: gates ([^:]+))?: (.*)$/gm)].map((m) => `- \`${m[1]}\` (${m[2] ? `gates ${m[2]}` : 'whole file'}): ${m[3]}`);
  const branchRemoved = check(stack, w, app, 'removed', ['--no-write']);
  r.removedLine = stack === 'api' ? ((/^\s*(\(removed: .*\))\s*$/m.exec(branchRemoved.out) || [])[1] || '') : ((/^\s*SUMMARY\s+(.*)$/m.exec(branchRemoved.out) || [])[1] || '');
  if (branchRemoved.code !== 0) stop(`removed tests: ${r.removedLine || 'no summary'} (an unaccounted removal blocks delivery)`);
  else ok('removed tests: 0 unaccounted');
  const unacc = /(\d+) unaccounted|unaccounted (\d+)/.exec(r.removedLine) || [];
  r.unaccounted = Number(unacc[1] || unacc[2] || 0);
  if (r.originSha) {
    const push = check(stack, w, app, 'removed', ['--base', `origin/${r.branch}`, '--no-write']);
    const line = push.out;
    r.pushRemoved = Number((stack === 'api' ? /\(removed: (\d+) of/ : /removed (\d+) \(/).exec(line)?.[1] || 0);
    r.pushAdded = Number((stack === 'api' ? /, (\d+) added;/ : /, (\d+) titles added/).exec(line)?.[1] || 0);
    const pu = /(\d+) unaccounted|unaccounted (\d+)/.exec(line) || [];
    r.pushUnmatched = Number(pu[1] || pu[2] || 0);
  }
  // The D line that accounts for each dropped test, as the check read it.
  r.dLines = [...check(stack, w, app, 'removed', ['--no-write', '--d-lines']).raw.matchAll(/^  D-LINE   \S+: (.*)$/gm)].map((m) => m[1].trim());

  // The commit message (testing/README.md, "The commit-message file").
  const msgFile = path.join(work, 'COMMIT_MSG');
  r.commit = r.changes.length > 0;
  if (r.commit) {
    if (!fs.existsSync(msgFile)) stop(`no commit-message file ${path.relative(DOCS, msgFile)}`);
    else {
      const lines = fs.readFileSync(msgFile, 'utf8').replace(/\s+$/, '').split('\n');
      const subject = lines[0] || '';
      const body = lines.slice(2).map((l) => l.trimEnd()).filter((l) => l.trim());
      if (!subject.trim()) stop('the commit-message file has no subject');
      if (subject.length > SUBJECT_MAX) stop(`the subject is ${subject.length} characters (under 72)`);
      if (lines[1] && lines[1].trim()) stop('the commit-message file has no blank line after the subject');
      if (body.length > WRITER_BODY_MAX) stop(`the body is ${body.length} lines; the file holds at most ${WRITER_BODY_MAX} (deliver.sh adds the tests and gates lines)`);
      if (body.some((l) => /^[A-Z][\w-]+:\s/.test(l) && /^(co-authored|signed-off|tests|gates):/i.test(l))) stop('the body carries a trailer or a Tests:/Gates: line; deliver.sh writes those');
      const delta = r.originSha ? `; this push adds ${r.pushAdded} and removes ${r.pushRemoved}, every removal accounted for` : '';
      r.message = [subject, '', ...body, `Tests: ${r.tests} passing${delta}.`, `Gates: ${r.gatesLine.replace(/^\((?:gates: )?|\)$/g, '')}.`].join('\n');
      r.subject = subject;
    }
  } else if (!r.ahead) r.info.push('nothing to deliver: the tree is clean and nothing is ahead of origin');

  // The PR.
  r.pr = null;
  if (r.slug && ghOk) {
    const list = run('gh', ['pr', 'list', '-R', r.slug, '--head', r.branch, '--state', 'open', '--json', 'number,url,body']);
    const prs = list.code === 0 ? JSON.parse(list.out || '[]') : [];
    if (prs.length) r.pr = prs[0];
    else if (stack === 'ui') stop(`no open PR for ${r.branch} in ${r.slug}`);
  }
  r.sections = sections(r);
  r.comment = [
    `${r.subject || 'No new commit; pushes the branch as it is'}.`,
    `Tests: ${r.tests} passing${r.originSha ? ` (+${r.pushAdded}, -${r.pushRemoved}; every removal accounted for)` : ''}.`,
    `Gates: ${r.gatesLine.replace(/^\((?:gates: )?|\)$/g, '')}.`,
  ].join('\n');
  if (!r.pr && stack === 'api') {
    const subjects = git(w, 'log', '--format=%s', `origin/main..HEAD`).out.split('\n').filter(Boolean).reverse();
    if (r.subject) subjects.push(r.subject);
    r.prTitle = 'Test suite on the shared API test standard';
    r.prBody = ['## Summary', '', 'Moves the test suite onto the shared Crucible API test standard: xUnit v3, PostgreSQL through Testcontainers with the real migrations, the app hosted in process, and permissions from seeded rows through the real claims transformer.', '',
      ...subjects.map((s) => `- ${s}`), '', r.sections].join('\n');
  } else if (r.pr) {
    r.prBody = replaceSections(r.pr.body || '', r.sections);
  }
  // Attribution scan of everything this push will write (RULES, Delivery).
  const outgoing = [r.message, r.comment, r.prTitle, r.prBody].filter(Boolean).join('\n');
  if (ATTRIBUTION.test(outgoing)) stop(`attribution scan: '${ATTRIBUTION.exec(outgoing)[0]}' in the commit message, PR comment or PR body`);
  else ok('attribution scan of the outgoing commit message, PR comment and PR body: clean');
  const pushed = r.originSha ? git(w, 'log', '--format=%an <%ae>%n%cn <%ce>%n%B', `origin/${r.branch}..HEAD`).out : '';
  if (pushed && ATTRIBUTION.test(pushed)) stop(`attribution scan of the unpushed commits: '${ATTRIBUTION.exec(pushed)[0]}'`);
  r.id = sha1([r.app, r.tree, r.head, r.originSha, r.message || '', r.comment, r.prBody || '', r.identity, ghLogin].join('\n')).slice(0, 12);
  return r;
}

function sections(r) {
  return [
    '## Gate coverage', '',
    `\`${r.gatesLine}\``, '',
    `Tests: ${r.tests} passing.`, '',
    r.allowed.length ? 'Allow-listed gates (each is still an untested gate):' : 'Allow-listed gates: none.',
    ...r.allowed, '',
    'Accepted gaps: none.', '',
    '## Removed-test accounting', '',
    `\`${r.removedLine}\``, '',
    r.dLines.length ? 'Dropped tests (D lines), each with the reason it was let go:' : 'No removed test was dropped: every one is still asserted by a named test.',
    ...r.dLines.map((l) => (l.startsWith('|') ? `- ${l.split('|').map((c) => c.trim()).filter(Boolean).join('; ')}` : l.startsWith('-') ? l : `- ${l}`)), '',
  ].join('\n');
}

// The PR body with its "Gate coverage" and "Removed-test accounting" sections replaced by new ones
// (appended where the body has none).
function replaceSections(body, fresh) {
  const out = [];
  let skip = false;
  for (const l of body.replace(/\r\n/g, '\n').split('\n')) {
    const h = /^##\s+(.*?)\s*$/.exec(l);
    if (h) skip = /^(Gate coverage|Gates|Removed-test accounting)$/i.test(h[1]);
    if (!skip) out.push(l);
  }
  return `${out.join('\n').replace(/\s+$/, '')}\n\n${fresh}`;
}

function printSummary(r) {
  console.log(`\n== ${r.app} (${r.stack}, ${r.branch || '?'} -> ${r.slug || '?'}, ${r.pr ? `PR #${r.pr.number}` : r.stack === 'api' ? 'PR to open' : 'no PR'})`);
  console.log('preflight:');
  for (const m of r.oks) console.log(`  ok    ${m}`);
  for (const m of r.stops) console.log(`  STOP  ${m}`);
  for (const m of r.info) console.log(`  note  ${m}`);
  if (!r.tree) return;
  const added = (r.changes || []).filter((c) => c.xy === '??' || c.xy.includes('A')).length;
  console.log(`files: ${(r.changes || []).length} changed (${added} new, ${r.deleted.length} deleted)${r.deleted.length ? `; deleted: ${r.deleted.join(', ')}` : ''}`);
  console.log(`tests: ${r.tests} passing (verify log)${r.originSha ? `; this push: ${r.pushAdded} added, ${r.pushRemoved} removed, ${r.pushUnmatched} unmatched` : ''}`);
  console.log(`unmatched removals on the branch: ${r.unaccounted}  ${r.removedLine}`);
  console.log(`gates: ${r.gatesLine}`);
  console.log(r.commit ? `commit message:\n${indent(r.message || '(none)')}` : `commit: none (the tree is clean; ${r.ahead} commit(s) to push)`);
  console.log(`PR comment:\n${indent(r.comment)}`);
  if (r.prTitle) console.log(`PR to open: ${r.prTitle}`);
  console.log(`PR sections:\n${indent(r.sections)}`);
  console.log(`id ${r.id}`);
}

function batchId(rs) { return sha1(rs.map((r) => `${r.app}:${r.id}`).sort().join('\n')).slice(0, 12); }

function log(r, text) {
  if (!r.work) return;
  fs.mkdirSync(r.work, { recursive: true });
  fs.appendFileSync(path.join(r.work, 'deliver.log'), `${text}\n`);
}

// --- push ----------------------------------------------------------------------------------------------
function push(r) {
  const steps = [];
  const step = (label, cmd, args, o) => {
    steps.push(`${label}: ${[cmd, ...args].map((a) => (/\s/.test(a) ? JSON.stringify(a) : a)).join(' ')}`);
    if (opts.dryRun) { console.log(`  dry-run  ${label}: ${cmd} ${args.join(' ')}`); return { code: 0, out: '' }; }
    const res = run(cmd, args, o);
    console.log(`  ${res.code === 0 ? 'done ' : 'FAIL '}  ${label}`);
    if (res.code !== 0) throw new Error(`${label} failed: ${res.err || res.out}`);
    return res;
  };
  const dir = path.join(r.work, 'deliver');
  fs.mkdirSync(dir, { recursive: true });
  const msgFile = path.join(dir, 'COMMIT_MSG.final');
  const commentFile = path.join(dir, 'PR_COMMENT.md');
  const bodyFile = path.join(dir, 'PR_BODY.md');
  if (r.message) fs.writeFileSync(msgFile, `${r.message}\n`);
  fs.writeFileSync(commentFile, `${r.comment}\n`);
  if (r.prBody) fs.writeFileSync(bodyFile, `${r.prBody}\n`);
  try {
    if (r.commit) {
      step('stage', 'git', ['-C', r.w, 'add', '-A']);
      // Hooks off: what is committed is the tree the verify log describes, with no trailer added.
      step('commit', 'git', ['-C', r.w, '-c', 'core.hooksPath=/dev/null', 'commit', '-q', '-F', msgFile]);
      if (!opts.dryRun) {
        const t = git(r.w, 'rev-parse', 'HEAD^{tree}').out;
        if (t !== r.tree) throw new Error(`the commit's tree ${t} is not the verified tree ${r.tree}; not pushing`);
      }
    }
    if (!opts.dryRun) {
      const range = r.originSha ? `origin/${r.branch}..HEAD` : 'HEAD';
      const commits = git(r.w, 'log', '--format=%an <%ae>%n%cn <%ce>%n%B', range).out;
      if (ATTRIBUTION.test(commits)) throw new Error(`attribution scan of the commits to push: '${ATTRIBUTION.exec(commits)[0]}'`);
      for (const line of git(r.w, 'log', '--format=%an <%ae>|%cn <%ce>', range).out.split('\n').filter(Boolean)) {
        if (line !== `${r.identity}|${r.identity}`) throw new Error(`a commit to push is not authored and committed as ${r.identity}: ${line}`);
      }
    }
    step('push', 'git', ['-C', r.w, 'push', `--force-with-lease=refs/heads/${r.branch}:${r.originSha || ''}`, 'origin', `HEAD:refs/heads/${r.branch}`]);
    let number = r.pr && r.pr.number;
    if (!number && r.stack === 'api') {
      const c = step('open the PR', 'gh', ['pr', 'create', '-R', r.slug, '--base', 'main', '--head', r.branch, '--title', r.prTitle, '--body-file', bodyFile]);
      number = opts.dryRun ? '<new>' : (/\/pull\/(\d+)/.exec(c.out) || [])[1];
    } else if (number) {
      step('PR sections', 'gh', ['pr', 'edit', String(number), '-R', r.slug, '--body-file', bodyFile]);
    }
    if (number) step('PR comment', 'gh', ['pr', 'comment', String(number), '-R', r.slug, '--body-file', commentFile]);
    if (!opts.dryRun && number) {
      const v = run('gh', ['pr', 'view', String(number), '-R', r.slug, '--json', 'author,body,commits,comments']);
      const pr = JSON.parse(v.out || '{}');
      const text = [pr.author && pr.author.login, pr.body, ...(pr.commits || []).flatMap((c) => [c.messageHeadline, c.messageBody, ...(c.authors || []).map((a) => `${a.login} ${a.name} ${a.email}`)]), ...(pr.comments || []).map((c) => `${c.author && c.author.login} ${c.body}`)].join('\n');
      if (ATTRIBUTION.test(text)) throw new Error(`attribution scan after the push: '${ATTRIBUTION.exec(text)[0]}' on PR #${number}; fix it now (amend and push with lease, edit the body or comment)`);
      if (pr.author && pr.author.login !== ghLogin) throw new Error(`PR #${number} is authored by ${pr.author.login}, not ${ghLogin}`);
      const after = git(r.w, 'log', '-1', '--format=%an <%ae>%n%cn <%ce>%n%B').out;
      if (ATTRIBUTION.test(after)) throw new Error(`attribution scan of the pushed commit: '${ATTRIBUTION.exec(after)[0]}'`);
      console.log(`  done   attribution scan after the push: clean (commit ${git(r.w, 'rev-parse', '--short', 'HEAD').out}, PR #${number})`);
    }
    log(r, `== ${new Date().toISOString()} push${opts.dryRun ? ' (dry run)' : ''} ${r.app} batch ${opts.batch}\n${steps.join('\n')}\nresult: done`);
    return true;
  } catch (e) {
    console.log(`  STOP   ${e.message}`);
    log(r, `== ${new Date().toISOString()} push ${r.app} batch ${opts.batch}\n${steps.join('\n')}\nresult: stopped: ${e.message}`);
    return false;
  }
}

// --- main ----------------------------------------------------------------------------------------------
const repos = opts.worktrees.map(collect);
const id = batchId(repos);
if (mode === 'summary') {
  for (const r of repos) {
    printSummary(r);
    log(r, `== ${new Date().toISOString()} summary ${r.app} id ${r.id} batch ${id}: ${r.stops.length ? `stopped (${r.stops.join('; ')})` : 'ready to push'}`);
  }
  const ready = repos.filter((r) => !r.stops.length);
  console.log(`\nbatch ${id}: ${ready.length} of ${repos.length} ready to push${ready.length < repos.length ? `; stopped: ${repos.filter((r) => r.stops.length).map((r) => r.app).join(', ')}` : ''}`);
  console.log(`after the user's word on this summary: testing/deliver.sh push --batch ${id} ${opts.worktrees.join(' ')}`);
  process.exit(ready.length === repos.length ? 0 : 1);
}
if (id !== opts.batch) die(`batch ${opts.batch} is not this batch (${id}): a repo changed since the summary, or the worktrees differ; run the summary again and show it to the user`, 1);
let failed = 0;
for (const r of repos) {
  console.log(`\n== ${r.app}`);
  if (r.stops.length) { console.log(`  STOP   ${r.stops.join('; ')}`); failed++; continue; }
  if (!push(r)) failed++;
}
process.exit(failed ? 1 : 0);
