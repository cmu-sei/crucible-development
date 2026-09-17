const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const { stripVTControlCharacters } = require('node:util');
const { readConf, readJson } = require('../api-config.cjs');

const repo = path.resolve(__dirname, '../..');

function fixture(t, settings = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'api-config-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const app = path.join(root, 'Crucible.AppHost');
  const config = path.join(app, 'resources/api/config');
  fs.mkdirSync(path.join(root, 'scripts'), { recursive: true });
  for (const file of ['api-config.cjs', 'configure-hypervisors.sh', 'toggle-hypervisor.sh'])
    fs.copyFileSync(path.join(repo, 'scripts', file), path.join(root, 'scripts', file));
  fs.mkdirSync(config, { recursive: true });
  fs.cpSync(path.join(repo, 'Crucible.AppHost/resources/api/config/templates'), path.join(config, 'templates'), { recursive: true });
  fs.writeFileSync(path.join(app, 'appsettings.json'), JSON.stringify({ Launch: { Dev: ['Player', 'Caster', 'TopoMojo'] } }));
  const settingsFile = path.join(app, 'appsettings.Development.json');
  fs.writeFileSync(settingsFile, JSON.stringify(settings));
  return {
    root, app, config, settingsFile,
    cli: require(path.join(root, 'scripts/api-config.cjs')),
    playerOnly() {
      const directory = path.join(config, 'local/player-only');
      fs.mkdirSync(directory, { recursive: true });
      fs.writeFileSync(path.join(directory, 'player-vm-api.conf'), 'Proxmox__Enabled=true\n');
      fs.writeFileSync(path.join(directory, 'caster-api.conf'), 'CUSTOM=value\n');
    },
    complete(profile) {
      const directory = path.join(config, 'local', profile);
      for (const file of fs.readdirSync(directory).filter(file => file.endsWith('.conf'))) {
        const target = path.join(directory, file);
        fs.writeFileSync(target, fs.readFileSync(target, 'utf8').replace(/<[^>\r\n]+>/g, 'configured'));
      }
    },
    run(script, args, extraEnv = {}) {
      const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !/^Launch__/i.test(key)));
      return spawnSync('bash', [path.join(root, 'scripts', script), ...args], {
        encoding: 'utf8', env: { ...env, ...extraEnv },
      });
    },
    settings() { return JSON.parse(fs.readFileSync(settingsFile, 'utf8')); },
  };
}

test('initialization is private, idempotent and leaves launch settings unchanged', t => {
  const f = fixture(t, { Launch: { ApiConfig: { Enabled: false } } });
  const before = fs.readFileSync(f.settingsFile, 'utf8');
  assert.equal(f.run('configure-hypervisors.sh', ['init', 'proxmox', '--profile', 'lab-a']).status, 0);
  const file = path.join(f.config, 'local/lab-a/player-vm-api.conf');
  assert.equal(fs.statSync(file).mode & 0o777, 0o600);
  assert.equal(fs.statSync(path.dirname(file)).mode & 0o777, 0o700);
  fs.writeFileSync(file, 'TOKEN=existing-secret\n');
  assert.equal(f.run('configure-hypervisors.sh', ['init', 'proxmox', '--profile', 'lab-a']).status, 0);
  assert.equal(fs.readFileSync(file, 'utf8'), 'TOKEN=existing-secret\n');
  assert.equal(fs.readFileSync(f.settingsFile, 'utf8'), before);
});

test('only two starting templates are offered; other environment names remain valid profiles', async t => {
  const f = fixture(t);
  const listed = f.run('configure-hypervisors.sh', ['list']);
  assert.equal(listed.status, 0, listed.stderr);
  assert.deepEqual(listed.stdout.trim().split('\n'), ['proxmox', 'vsphere']);
  const help = f.run('configure-hypervisors.sh', ['--help']);
  assert.match(help.stdout, /proxmox\|vsphere/);
  assert.doesNotMatch(help.stdout, /vmc|hybrid/);
  const before = fs.readFileSync(f.settingsFile, 'utf8');
  for (const name of ['vmc', 'hybrid']) {
    assert.notEqual(f.run('configure-hypervisors.sh', [name]).status, 0);
    const init = f.run('configure-hypervisors.sh', ['init', name]);
    assert.notEqual(init.status, 0);
    assert.match(init.stderr, /Unknown template set/);
    await assert.rejects(f.cli.configure(name, name, () => assert.fail('must not prompt')), /supports proxmox and vsphere/);
    assert.notEqual(f.run('toggle-hypervisor.sh', [name]).status, 0);
    assert.equal(fs.readFileSync(f.settingsFile, 'utf8'), before);
    assert.ok(!fs.existsSync(path.join(f.config, 'local', name)));
    assert.equal(f.run('configure-hypervisors.sh', ['init', 'vsphere', '--profile', name]).status, 0);
    f.complete(name);
    assert.equal(f.run('toggle-hypervisor.sh', [name]).status, 0);
    assert.equal(f.settings().Launch.ApiConfig.Profile, name);
    fs.writeFileSync(f.settingsFile, before);
  }
});

test('switching clears profile overrides, preserves disable flags and unrelated settings', t => {
  const f = fixture(t, { Other: 'keep', Launch: { ApiConfig: {
    Apps: { 'player-vm-api': { Profile: 'hybrid' }, 'caster-api': { Enabled: false } },
  } } });
  for (const profile of ['proxmox', 'vsphere']) {
    assert.equal(f.run('configure-hypervisors.sh', ['init', profile]).status, 0);
    f.complete(profile);
  }
  for (const profile of ['proxmox', 'vsphere', 'proxmox']) {
    const result = f.run('toggle-hypervisor.sh', [profile]);
    assert.equal(result.status, 0, result.stderr);
    const settings = f.settings();
    assert.equal(settings.Other, 'keep');
    assert.equal(settings.Launch.ApiConfig.Profile, profile);
    assert.equal(settings.Launch.ApiConfig.Enabled, true);
    assert.equal(settings.Launch.ApiConfig.Apps['caster-api'].Enabled, false);
    assert.equal(settings.Launch.ApiConfig.Apps['player-vm-api'].Profile, undefined);
  }
  assert.equal(f.run('toggle-hypervisor.sh', ['remove']).status, 0);
  assert.equal(f.settings().Launch.ApiConfig.Enabled, false);
  assert.ok(fs.existsSync(path.join(f.config, 'local/proxmox/topomojo.conf')));
});

test('missing or invalid profiles fail before settings mutation', t => {
  const f = fixture(t);
  const before = fs.readFileSync(f.settingsFile, 'utf8');
  for (const name of ['missing', '../escape', 'a/b'])
    assert.notEqual(f.run('toggle-hypervisor.sh', [name]).status, 0);
  f.playerOnly();
  assert.notEqual(f.run('toggle-hypervisor.sh', ['player-only']).status, 0);
  assert.equal(fs.readFileSync(f.settingsFile, 'utf8'), before);
  assert.notEqual(f.run('configure-hypervisors.sh', ['set-proxmox']).status, 0);
});

test('disabled apps need no selected file', t => {
  const f = fixture(t, { Launch: { ApiConfig: { Apps: { topomojo: { Enabled: false } } } } });
  f.playerOnly();
  const result = f.run('toggle-hypervisor.sh', ['player-only']);
  assert.equal(result.status, 0, result.stderr);
  fs.writeFileSync(path.join(f.config, 'local/player-only/topomojo.conf'), 'invalid ignored file');
  assert.equal(f.run('toggle-hypervisor.sh', ['player-only']).status, 0);
});

test('launchpoint also requires TopoMojo config, unless its file delivery is disabled', t => {
  const f = fixture(t);
  fs.writeFileSync(path.join(f.app, 'appsettings.json'), JSON.stringify({ Launch: { Dev: ['TopoMojoLaunchpoint'] } }));
  f.playerOnly();
  assert.notEqual(f.run('toggle-hypervisor.sh', ['player-only']).status, 0);
  assert.equal(f.run('toggle-hypervisor.sh', ['player-only'], {
    Launch__ApiConfig__Apps__topomojo__Enabled: 'false',
  }).status, 0);
});

test('malformed local files fail selection without exposing values or changing settings', t => {
  const f = fixture(t);
  assert.equal(f.run('configure-hypervisors.sh', ['init', 'proxmox']).status, 0);
  f.complete('proxmox');
  fs.writeFileSync(path.join(f.config, 'local/proxmox/caster-api.conf'), 'KEY=secret\nkey=another');
  const before = fs.readFileSync(f.settingsFile, 'utf8');
  const result = f.run('toggle-hypervisor.sh', ['proxmox']);
  assert.notEqual(result.status, 0);
  assert.ok(!result.stderr.includes('secret'));
  assert.equal(fs.readFileSync(f.settingsFile, 'utf8'), before);
});

test('literal parsing preserves credentials without executing or exposing them', t => {
  const f = fixture(t);
  const file = path.join(f.root, 'literal.conf');
  fs.writeFileSync(file, '\uFEFF# comment\r\n \r\n TOKEN =user@realm!id=secret$HOME#literal\r\nEMPTY=\nQUOTED="literal"\n');
  assert.equal(readConf(file).get('TOKEN'), 'user@realm!id=secret$HOME#literal');
  assert.equal(readConf(file).get('EMPTY'), '');
  assert.equal(readConf(file).get('QUOTED'), '"literal"');
  for (const contents of ['TOKEN=secret\nTOKEN=other', 'token=secret\nTOKEN=other', 'invalid-secret-line', 'BAD-KEY=secret']) {
    fs.writeFileSync(file, contents);
    assert.throws(() => readConf(file), error => !error.message.includes('secret'));
  }
});

test('all templates parse and local profiles and backups are ignored by Git', () => {
  const config = 'Crucible.AppHost/resources/api/config';
  for (const profile of fs.readdirSync(path.join(repo, config, 'templates'))) {
    for (const file of fs.readdirSync(path.join(repo, config, 'templates', profile)))
      assert.ok(readConf(path.join(repo, config, 'templates', profile, file)).size);
  }
  for (const file of ['local/lab-a/caster-api.conf', 'local/lab-a/caster-api.conf.bak', 'local/tmp']) {
    const result = spawnSync('git', ['check-ignore', '--quiet', `${config}/${file}`], { cwd: repo });
    assert.equal(result.status, 0);
  }
  assert.equal(spawnSync('git', ['check-ignore', '--quiet', `${config}/templates/proxmox/topomojo.conf.template`], { cwd: repo }).status, 1);
});

test('JSON comments/trailing commas preserve literal values and case-insensitive launch keys', t => {
  const f = fixture(t);
  fs.writeFileSync(f.settingsFile, '{ // comment\n"launch": {"ApiConfig": {"Enabled": false,},}, "url": "https://x/*not a comment*/", "password": "\\\\\\"//secret",}');
  const before = readJson(f.settingsFile);
  assert.equal(f.run('configure-hypervisors.sh', ['init', 'proxmox']).status, 0);
  f.complete('proxmox');
  assert.equal(f.run('toggle-hypervisor.sh', ['proxmox']).status, 0);
  assert.equal(f.settings().url, before.url);
  assert.equal(f.settings().password, before.password);
  assert.equal(f.settings().launch.ApiConfig.Enabled, true);
  assert.equal(f.settings().Launch, undefined);
});

test('Proxmox setup fills missing templates but preserves existing files and keeps credentials out of launch settings', t => {
  const f = fixture(t);
  const token = 'user@realm!id=secret$&=literal';
  const result = spawnSync('node', [path.join(f.root, 'scripts/api-config.cjs'), 'setup-proxmox'], {
    encoding: 'utf8', env: { ...process.env, PROXMOX_HOST: 'pve.test', PROXMOX_API_TOKEN: token },
  });
  assert.equal(result.status, 0, result.stderr);
  assert.ok(!result.stdout.includes(token));
  assert.ok(!fs.readFileSync(f.settingsFile, 'utf8').includes(token));
  assert.equal(readConf(path.join(f.config, 'local/proxmox/player-vm-api.conf')).get('Proxmox__Token'), token);
  const file = path.join(f.config, 'local/proxmox/topomojo.conf');
  fs.appendFileSync(file, '# customized\n');
  const before = fs.readFileSync(file, 'utf8');
  const second = spawnSync('node', [path.join(f.root, 'scripts/api-config.cjs'), 'setup-proxmox'], {
    encoding: 'utf8', env: { ...process.env, PROXMOX_HOST: 'other.test', PROXMOX_API_TOKEN: 'different' },
  });
  assert.equal(second.status, 0, second.stderr);
  assert.equal(fs.readFileSync(file, 'utf8'), before);
});

function answers(t, responses) {
  const pending = [...responses];
  t.after(() => assert.deepEqual(pending, [], 'all expected prompts were asked'));
  return async (label, fallback, secret) => {
    assert.ok(pending.length, `unexpected prompt: ${label}`);
    const [expected, answer, expectedSecret] = pending.shift();
    assert.match(label, expected);
    if (expectedSecret !== undefined) assert.equal(secret, expectedSecret);
    return answer;
  };
}

test('guided Proxmox setup uses saved answers once and fills native settings in all apps', async t => {
  const f = fixture(t);
  const token = 'user@realm!id=secret$&=<literal>';
  await f.cli.configure('proxmox', 'lab-pve', answers(t, [
    [/Proxmox host/, ''], [/Proxmox port/, '8006'],
    [/API token/, '', true], [/VM and disk storage/, 'fast-vms'], [/ISO storage/, 'isos'],
  ]), { host: 'pve.test', token });
  const directory = path.join(f.config, 'local/lab-pve');
  const topo = readConf(path.join(directory, 'topomojo.conf'));
  const player = readConf(path.join(directory, 'player-vm-api.conf'));
  const caster = readConf(path.join(directory, 'caster-api.conf'));
  assert.equal(topo.get('Pod__Url'), 'https://pve.test:8006');
  assert.equal(topo.get('Pod__AccessToken'), token);
  assert.equal(topo.get('Pod__VmStore'), 'fast-vms');
  assert.equal(player.get('Proxmox__Host'), 'pve.test');
  assert.equal(player.get('Proxmox__Port'), '8006');
  assert.equal(player.get('Proxmox__IsoStorage'), 'isos');
  assert.equal(player.get('Proxmox__Token'), token);
  assert.equal(caster.get('Terraform__EnvironmentVariables__Direct__PROXMOX_VE_ENDPOINT'), 'https://pve.test:8006');
  assert.equal(caster.get('Terraform__EnvironmentVariables__Direct__PROXMOX_VE_API_TOKEN'), token);
  assert.equal(fs.statSync(path.join(directory, 'player-vm-api.conf')).mode & 0o777, 0o600);
  assert.equal(f.settings().Launch.ApiConfig.Profile, 'lab-pve');
  assert.ok(!fs.readFileSync(f.settingsFile, 'utf8').includes(token));
});

for (const profile of ['vsphere', 'vmc']) {
  test(`guided vSphere setup for profile ${profile} shares credentials/storage and preserves upload defaults`, async t => {
    const f = fixture(t);
    const password = 'literal!$&=a#b"<not-a-template>';
    await f.cli.configure('vsphere', profile, answers(t, [
      [/vCenter host/, 'vc.test'], [/username/, ''], [/password/, password, true],
      [/Datastore name/, 'custom store'], [/Pool path/, 'DC/Cluster/Parent/Pool'],
    ]));
    const directory = path.join(f.config, `local/${profile}`);
    const topo = readConf(path.join(directory, 'topomojo.conf'));
    const player = readConf(path.join(directory, 'player-vm-api.conf'));
    const caster = readConf(path.join(directory, 'caster-api.conf'));
    assert.equal(topo.get('Pod__Password'), password);
    assert.equal(player.get('Vsphere__Hosts__0__Password'), password);
    assert.equal(caster.get('Terraform__EnvironmentVariables__Direct__VSPHERE_PASSWORD'), password);
    assert.equal(topo.get('Pod__VmStore'), '[custom store] topomojo');
    assert.equal(player.get('Vsphere__Hosts__0__DsName'), 'custom store');
    assert.equal(caster.get('Terraform__EnvironmentVariables__Direct__VSPHERE_DATASTORE'), 'custom store');
    assert.equal(caster.get('Terraform__EnvironmentVariables__Direct__VSPHERE_RESOURCE_POOL'), 'Parent/Pool');
    assert.equal(topo.get('Pod__PoolPath'), 'DC/Cluster/Parent/Pool');
    assert.equal(topo.get('FileUpload__UseDatastoreApi'), 'false');
    assert.equal(player.get('Vsphere__IsoUploadViaApi'), 'false');
    assert.equal(f.settings().Launch.ApiConfig.Profile, profile);
  });
}

test('existing profiles default to keeping edits; regeneration backs up files; cancellation writes nothing', async t => {
  const f = fixture(t);
  assert.equal(f.run('configure-hypervisors.sh', ['init', 'vsphere', '--profile', 'vmc']).status, 0);
  f.complete('vmc');
  const directory = path.join(f.config, 'local/vmc');
  const file = path.join(directory, 'topomojo.conf');
  fs.appendFileSync(file, '# custom setting\nCustom__Setting=keep\n');
  const before = fs.readFileSync(file, 'utf8');
  await f.cli.configure('vsphere', 'vmc', answers(t, [[/Keep files/, '']]));
  assert.equal(fs.readFileSync(file, 'utf8'), before);
  const settingsBefore = fs.readFileSync(f.settingsFile, 'utf8');
  await assert.rejects(f.cli.configure('vsphere', 'vmc', answers(t, [[/Keep files/, 'cancel']])), /cancelled/);
  assert.equal(fs.readFileSync(file, 'utf8'), before);
  assert.equal(fs.readFileSync(f.settingsFile, 'utf8'), settingsBefore);
  await f.cli.configure('vsphere', 'vmc', answers(t, [
    [/Keep files/, 'regenerate'], [/vCenter host/, 'new.test'],
    [/username/, ''], [/password/, 'new-secret', true], [/Datastore name/, ''], [/Pool path/, ''],
  ]));
  const backups = fs.readdirSync(directory).filter(file => file.endsWith('.bak'));
  assert.equal(backups.length, 3);
  const backup = backups.find(file => file.startsWith('topomojo.conf.'));
  assert.equal(fs.readFileSync(path.join(directory, backup), 'utf8'), before);
  assert.equal(fs.statSync(path.join(directory, backup)).mode & 0o777, 0o600);
  assert.equal(readConf(file).get('Pod__Url'), 'https://new.test/sdk');
  assert.equal(readConf(file).get('Pod__VmStore'), '[datastore1] topomojo');
  assert.equal(readConf(file).get('Custom__Setting'), undefined);
});

test('unfinished manual templates cannot be selected or kept as a completed setup', async t => {
  const f = fixture(t);
  assert.equal(f.run('configure-hypervisors.sh', ['init', 'proxmox']).status, 0);
  const before = fs.readFileSync(f.settingsFile, 'utf8');
  const result = f.run('toggle-hypervisor.sh', ['proxmox']);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Unfilled template placeholder/);
  await assert.rejects(f.cli.configure('proxmox', 'proxmox', answers(t, [[/Keep files/, 'keep']])), /Unfilled template placeholder/);
  assert.equal(fs.readFileSync(f.settingsFile, 'utf8'), before);
});

test('saved Proxmox config handles shell escaping and explicit environment takes precedence', t => {
  const f = fixture(t);
  const saved = path.join(f.app, 'resources/proxmox/config');
  fs.mkdirSync(path.dirname(saved), { recursive: true });
  fs.writeFileSync(saved, 'export PROXMOX_HOST=pve.test\nexport PROXMOX_API_TOKEN=root@pam\\!CRUCIBLE=a\\$b\\&c\\=d\n');
  assert.deepEqual(f.cli.savedProxmox({}), { host: 'pve.test', token: 'root@pam!CRUCIBLE=a$b&c=d' });
  assert.deepEqual(f.cli.savedProxmox({ PROXMOX_HOST: 'override.test', PROXMOX_API_TOKEN: 'override' }),
    { host: 'override.test', token: 'override' });
  const custom = path.join(f.root, 'custom-config');
  fs.writeFileSync(custom, 'export PROXMOX_HOST=custom.test\nexport PROXMOX_API_TOKEN=custom\n');
  assert.deepEqual(f.cli.savedProxmox({ PROXMOX_CONFIG_FILE: custom }), { host: 'custom.test', token: 'custom' });
});

test('menus create, select, disable and quit without requesting credentials when selecting', async t => {
  const f = fixture(t);
  await f.cli.menu(answers(t, [
    [/Action/, 'configure'], [/Backend/, 'vmc'], [/Backend/, 'hybrid'], [/Backend/, 'vsphere'], [/Profile name/, 'office'],
    [/vCenter host/, 'vc.test'], [/username/, ''], [/password/, 'secret', true],
    [/Datastore name/, ''], [/Pool path/, ''],
  ]));
  const before = fs.readFileSync(path.join(f.config, 'local/office/topomojo.conf'), 'utf8');
  assert.equal(readConf(path.join(f.config, 'local/office/caster-api.conf'))
    .get('Terraform__EnvironmentVariables__Direct__VSPHERE_RESOURCE_POOL'), '');
  await f.cli.menu(answers(t, [[/Action/, 'disable']]));
  assert.equal(f.settings().Launch.ApiConfig.Enabled, false);
  await f.cli.menu(answers(t, [[/Action/, 'select'], [/Profile/, 'office']]));
  assert.equal(f.settings().Launch.ApiConfig.Enabled, true);
  assert.equal(fs.readFileSync(path.join(f.config, 'local/office/topomojo.conf'), 'utf8'), before);
  const settings = fs.readFileSync(f.settingsFile, 'utf8');
  await f.cli.menu(answers(t, [[/Action/, 'quit']]));
  assert.equal(fs.readFileSync(f.settingsFile, 'utf8'), settings);
});

test('guided setup without a terminal fails promptly; help and manual init still work', t => {
  const f = fixture(t);
  for (const script of ['configure-hypervisors.sh', 'toggle-hypervisor.sh']) {
    const result = f.run(script, []);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /needs a terminal/);
    assert.equal(f.run(script, ['--help']).status, 0);
  }
  assert.ok(!fs.existsSync(path.join(f.config, 'local')));
});

test('invalid input is reprompted and an interrupted regeneration preserves existing files', async t => {
  const f = fixture(t);
  await f.cli.configure('proxmox', 'pve', answers(t, [
    [/Proxmox host/, 'https://bad.test/path'], [/Proxmox host/, 'pve.test'],
    [/Proxmox port/, '0'], [/Proxmox port/, '8006'],
    [/API token/, 'bad\nsecret'], [/API token/, 'good-secret', true],
    [/VM and disk storage/, ''], [/ISO storage/, ''],
  ]), { host: 'pve.test', token: 'saved' });
  const file = path.join(f.config, 'local/pve/topomojo.conf');
  const before = fs.readFileSync(file, 'utf8');
  let count = 0;
  await assert.rejects(f.cli.configure('proxmox', 'pve', async () => {
    if (count++ === 0) return 'regenerate';
    throw new Error('cancelled');
  }, { host: 'pve.test', token: 'saved' }), /cancelled/);
  assert.equal(fs.readFileSync(file, 'utf8'), before);
  assert.ok(!fs.readdirSync(path.dirname(file)).some(file => file.endsWith('.bak')));
});

test('new fixed template settings need no prompts; missing inputs fail before replacing any files', async t => {
  const f = fixture(t);
  const template = path.join(f.config, 'templates/vsphere/topomojo.conf.template');
  fs.appendFileSync(template, '# An example <in a comment> is not an input.\nNew__Setting=fixed-default\n');
  const setup = () => f.cli.configure('vsphere', 'vmc', answers(t, [
    [/vCenter host/, 'vc.test'], [/username/, ''], [/password/, 'secret'],
    [/Datastore name/, ''], [/Pool path/, ''],
  ]));
  await setup();
  const file = path.join(f.config, 'local/vmc/topomojo.conf');
  assert.equal(readConf(file).get('New__Setting'), 'fixed-default');
  const before = fs.readFileSync(file, 'utf8');
  const settingsBefore = fs.readFileSync(f.settingsFile, 'utf8');
  fs.appendFileSync(template, 'Another__Setting=<new-input>\n');
  await assert.rejects(f.cli.configure('vsphere', 'vmc', answers(t, [
    [/Keep files/, 'regenerate'], [/vCenter host/, 'vc.test'], [/username/, ''],
    [/password/, 'secret'], [/Datastore name/, ''], [/Pool path/, ''],
  ])), /Unfilled template placeholder/);
  assert.equal(fs.readFileSync(file, 'utf8'), before);
  assert.equal(fs.readFileSync(f.settingsFile, 'utf8'), settingsBefore);
  assert.ok(!fs.readdirSync(path.dirname(file)).some(file => file.endsWith('.bak')));
});

// Exercise real readline/TTY behavior as well as the injected-answer tests above.
// util-linux script supplies a pseudo-terminal in the Linux development container.
const hasPty = process.platform === 'linux' && spawnSync('script', ['--version']).status === 0;
function terminal(t, f, steps) {
  const quote = text => `'${text.replaceAll("'", "'\\''")}'`;
  const command = [process.execPath, path.join(f.root, 'scripts/api-config.cjs'), 'configure', 'vsphere', '--profile', 'vmc'].map(quote).join(' ');
  const child = spawn('script', ['-q', '-e', '-c', command, '/dev/null']);
  t.after(() => { if (child.exitCode === null) child.kill('SIGTERM'); });
  let output = '', pending = '';
  const replies = [...steps];
  const receive = chunk => {
    output += chunk;
    pending += chunk;
    if (replies.length && stripVTControlCharacters(pending).includes(replies[0][0])) {
      const [, reply] = replies.shift();
      pending = '';
      child.stdin.write(reply);
    }
  };
  child.stdout.on('data', receive);
  child.stderr.on('data', receive);
  return new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', code => {
      child.stdin.end();
      resolve({ code, output, remaining: replies.length });
    });
  });
}

test('real terminal hides passwords and writes their literal values', { skip: !hasPty, timeout: 10000 }, async t => {
  const f = fixture(t);
  const password = 'tty-secret!$&=#literal';
  const result = await terminal(t, f, [
    ['vCenter host (hostname or IP only): ', 'vc.test\r'],
    ['vCenter username [administrator@vsphere.local]: ', '\r'],
    ['vCenter password: ', `${password}\r`],
    ['Datastore name [datastore1]: ', '\r'],
    ['Pool path (Datacenter/Cluster[/ResourcePool]) [Datacenter/Cluster]: ', '\r'],
  ]);
  assert.equal(result.code, 0, result.output);
  assert.equal(result.remaining, 0);
  assert.ok(!result.output.includes(password), 'password must not be echoed');
  assert.equal(readConf(path.join(f.config, 'local/vmc/topomojo.conf')).get('Pod__Password'), password);
});

test('Ctrl-C at a real password prompt cancels without writing a profile', { skip: !hasPty, timeout: 10000 }, async t => {
  const f = fixture(t);
  const before = fs.readFileSync(f.settingsFile, 'utf8');
  const result = await terminal(t, f, [
    ['vCenter host (hostname or IP only): ', 'vc.test\r'],
    ['vCenter username [administrator@vsphere.local]: ', '\r'],
    ['vCenter password: ', 'unfinished-secret\u0003'],
  ]);
  assert.notEqual(result.code, 0);
  assert.equal(result.remaining, 0);
  assert.match(result.output, /Setup cancelled/);
  assert.ok(!result.output.includes('unfinished-secret'));
  assert.equal(fs.readFileSync(f.settingsFile, 'utf8'), before);
  assert.ok(!fs.existsSync(path.join(f.config, 'local')));
});
