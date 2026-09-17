#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const readline = require('node:readline');
const { Writable } = require('node:stream');
const { spawnSync } = require('node:child_process');

const appHost = path.resolve(__dirname, '../Crucible.AppHost');
const configRoot = path.join(appHost, 'resources/api/config');
const apps = { topomojo: 'TopoMojo', 'player-vm-api': 'Player', 'caster-api': 'Caster' };

function profileName(value) {
  if (!/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(value ?? ''))
    throw new Error('Profile names may contain only letters, digits, "-" and "_".');
  return value;
}

function readConf(file) {
  const values = new Map();
  const keys = new Set();
  fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '').split(/\r?\n/).forEach((line, index) => {
    if (!line.trim() || line.trimStart().startsWith('#')) return;
    const separator = line.indexOf('=');
    const key = line.slice(0, separator).trim();
    const fail = reason => { throw new Error(`${file}, line ${index + 1}: ${reason}`); };
    if (separator < 0) fail('expected KEY=value');
    if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(key)) fail('invalid environment key');
    if (keys.has(key.toLowerCase())) fail('duplicate environment key');
    keys.add(key.toLowerCase());
    values.set(key, line.slice(separator + 1).trim());
  });
  return values;
}

function checkComplete(file) {
  const values = readConf(file);
  const templates = path.join(configRoot, 'templates');
  const placeholders = new Set();
  for (const template of fs.readdirSync(templates)) {
    for (const name of fs.readdirSync(path.join(templates, template)).filter(name => name.endsWith('.conf.template'))) {
      for (const value of readConf(path.join(templates, template, name)).values())
        for (const match of value.matchAll(/<[^>\r\n]+>/g)) placeholders.add(match[0]);
    }
  }
  for (const [key, value] of values) {
    if ([...placeholders].some(placeholder => value.includes(placeholder)))
      throw new Error(`Unfilled template placeholder for ${key} in ${file}. Run guided setup to regenerate, or edit the file.`);
  }
}

// AppHost settings support comments and trailing commas. Strip them only outside
// strings so URLs, passwords and escaped quotes remain intact.
function readJson(file) {
  let text = fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
  let clean = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i], next = text[i + 1];
    if (quoted) {
      clean += ch;
      if (ch === '\\') clean += text[++i] ?? '';
      else if (ch === '"') quoted = false;
    } else if (ch === '"') {
      quoted = true; clean += ch;
    } else if (ch === '/' && next === '/') {
      while (i < text.length && text[i] !== '\n') i++;
      clean += '\n';
    } else if (ch === '/' && next === '*') {
      i += 2;
      while (i < text.length && !(text[i] === '*' && text[i + 1] === '/')) i++;
      if (i >= text.length) throw new Error(`Unterminated comment in ${file}`);
      i++; clean += ' ';
    } else clean += ch;
  }
  text = clean; clean = ''; quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      clean += ch;
      if (ch === '\\') clean += text[++i] ?? '';
      else if (ch === '"') quoted = false;
    } else if (ch === '"') {
      quoted = true; clean += ch;
    } else if (ch !== ',' || !/^\s*[}\]]/.test(text.slice(i + 1))) clean += ch;
  }
  try { return JSON.parse(clean); }
  catch { throw new Error(`Invalid JSON settings: ${file}`); }
}

function get(object, key) {
  return object?.[Object.keys(object).find(k => k.toLowerCase() === key.toLowerCase())];
}

function set(object, key, value) {
  const existing = Object.keys(object).find(k => k.toLowerCase() === key.toLowerCase());
  object[existing ?? key] = value;
}

function merge(base, overlay) {
  const result = structuredClone(base);
  for (const [key, value] of Object.entries(overlay)) {
    const old = get(result, key);
    set(result, key, value && typeof value === 'object' && !Array.isArray(value)
      ? merge(old && typeof old === 'object' && !Array.isArray(old) ? old : {}, value)
      : value);
  }
  return result;
}

function initialize(template, profile = template, replacements = {}, regenerate = false) {
  profileName(template); profileName(profile);
  const source = path.join(configRoot, 'templates', template);
  if (!fs.existsSync(source)) throw new Error(`Unknown template set: ${template}`);
  const destination = path.join(configRoot, 'local', profile);
  const rendered = [];
  for (const file of fs.readdirSync(source).filter(f => f.endsWith('.conf.template')).sort()) {
    const target = path.join(destination, file.replace(/\.template$/, ''));
    if (fs.existsSync(target) && !regenerate) {
      console.log(`Preserved ${target}`);
      continue;
    }
    // One pass prevents literal credentials from being treated as another placeholder.
    const contents = fs.readFileSync(path.join(source, file), 'utf8').split('\n')
      .map(line => line.trimStart().startsWith('#') ? line : line.replace(/<[^>\r\n]+>/g, placeholder => {
        if (Object.hasOwn(replacements, placeholder)) return replacements[placeholder];
        if (Object.keys(replacements).length)
          throw new Error(`Unfilled template placeholder in ${file}: ${placeholder}`);
        return placeholder;
      })).join('\n');
    rendered.push({ target, contents });
  }
  fs.mkdirSync(destination, { recursive: true, mode: 0o700 });
  fs.chmodSync(path.join(configRoot, 'local'), 0o700);
  fs.chmodSync(destination, 0o700);
  for (const { target, contents } of rendered) {
    if (fs.existsSync(target)) {
      const backup = `${target}.${Date.now()}-${process.pid}.bak`;
      fs.copyFileSync(target, backup, fs.constants.COPYFILE_EXCL);
      fs.chmodSync(backup, 0o600);
      console.log(`Backed up ${backup}`);
    }
    writeFile(target, contents);
    console.log(`Created ${target}`);
  }
}

function writeFile(file, contents) {
  const temporary = `${file}.${process.pid}.tmp`;
  try {
    fs.writeFileSync(temporary, contents, { flag: 'wx', mode: 0o600 });
    fs.renameSync(temporary, file);
  } finally {
    if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
  }
}

function writeSettings(file, settings) {
  writeFile(file, `${JSON.stringify(settings, null, 2)}\n`);
}

// Match setup-crucible-proxmox.sh's saved shell config, including printf %q escaping.
function savedProxmox(env = process.env) {
  const candidates = env.PROXMOX_CONFIG_FILE ? [env.PROXMOX_CONFIG_FILE] : [
    path.join(appHost, 'resources/proxmox/config'), path.join(os.homedir(), '.crucible-proxmox'),
  ];
  const file = candidates.find(candidate => fs.existsSync(candidate));
  let saved = [];
  if (file) {
    const result = spawnSync('bash', ['-c',
      'source "$1" >/dev/null && printf "%s\\0%s" "$PROXMOX_HOST" "$PROXMOX_API_TOKEN"', '--', file],
    { encoding: 'utf8', env, timeout: 5000 });
    if (result.status !== 0) throw new Error(`Could not load saved Proxmox configuration: ${file}`);
    saved = result.stdout.split('\0');
  }
  return { host: env.PROXMOX_HOST || saved[0] || '', token: env.PROXMOX_API_TOKEN || saved[1] || '' };
}

async function withPrompts(action) {
  if (!process.stdin.isTTY || !process.stdout.isTTY)
    throw new Error('Guided setup needs a terminal. Use init to create files manually, or select an existing profile.');
  let muted = false;
  const output = new Writable({
    write(chunk, encoding, callback) {
      if (!muted) process.stdout.write(chunk, encoding);
      callback();
    },
  });
  const rl = readline.createInterface({ input: process.stdin, output, terminal: true, historySize: 0 });
  rl.on('SIGINT', () => rl.close());
  const ask = (label, fallback = '', secret = false) => new Promise((resolve, reject) => {
    if (rl.closed) return reject(new Error('Setup cancelled; no profile was generated.'));
    const cancelled = () => reject(new Error('Setup cancelled; no profile was generated.'));
    rl.once('close', cancelled);
    const hint = fallback ? (secret ? ' [saved value; Enter to keep]' : ` [${fallback}]`) : '';
    rl.question(`${label}${hint}: `, answer => {
      rl.removeListener('close', cancelled);
      muted = false;
      if (secret) process.stdout.write('\n');
      resolve(answer);
    });
    muted = secret;
  });
  try { return await action(ask); }
  finally { muted = false; rl.close(); output.end(); }
}

async function value(ask, label, fallback = '', secret = false, validate = () => true) {
  while (true) {
    const answer = await ask(label, fallback, secret);
    const result = answer || fallback;
    if (result && result === result.trim() && !/[\x00-\x1f\x7f]/.test(result) && validate(result))
      return result;
    console.log(`Enter a valid ${label.toLowerCase()} (one line, without surrounding whitespace).`);
  }
}

function validHost(host) {
  try {
    const url = new URL(`https://${host}`);
    return url.hostname === host.toLowerCase() && !url.port && !url.username && !url.password
      && url.pathname === '/' && !url.search && !url.hash;
  } catch { return false; }
}

async function choose(ask, label, choices, fallback) {
  console.log(choices.join(' / '));
  return value(ask, label, fallback, false, answer => choices.includes(answer));
}

async function configure(template, profile, ask, defaults = {}) {
  if (!['proxmox', 'vsphere'].includes(template))
    throw new Error('Guided setup supports proxmox and vsphere. Customize the generated files for other environments.');
  profileName(profile);
  if (profile === 'remove') throw new Error('"remove" is reserved for disabling API configuration.');
  const directory = path.join(configRoot, 'local', profile);
  const existing = fs.existsSync(directory) && fs.readdirSync(directory).some(file => file.endsWith('.conf'));
  if (existing) {
    console.log(`Existing profile: ${directory}`);
    const decision = await choose(ask, 'Keep files or regenerate from templates (backs up existing files)', ['keep', 'regenerate', 'cancel'], 'keep');
    if (decision === 'cancel') throw new Error('Setup cancelled; existing files were kept.');
    if (decision === 'keep') { toggle(profile); return; }
  }

  let replacements;
  if (template === 'proxmox') {
    const saved = defaults.host && defaults.token ? defaults : { ...savedProxmox(), ...defaults };
    replacements = {
      '<proxmox-host>': await value(ask, 'Proxmox host (hostname or IP only)', saved.host, false, validHost),
      '<proxmox-port>': await value(ask, 'Proxmox port', '443', false, port => /^\d+$/.test(port) && +port > 0 && +port <= 65535),
      '<user@realm!token-id=token-secret>': await value(ask, 'Proxmox API token', saved.token, true),
      '<vm-storage>': await value(ask, 'VM and disk storage', 'local-lvm'),
      '<iso-storage>': await value(ask, 'ISO storage', 'local'),
    };
  } else {
    const host = await value(ask, 'vCenter host (hostname or IP only)', '', false, validHost);
    const username = await value(ask, 'vCenter username', 'administrator@vsphere.local');
    const password = await value(ask, 'vCenter password', '', true);
    const datastore = await value(ask, 'Datastore name', 'datastore1', false, name => !/[\[\]]/.test(name));
    const pool = await value(ask, 'Pool path (Datacenter/Cluster[/ResourcePool])',
      'Datacenter/Cluster', false,
      pool => pool.split('/').length >= 2 && pool.split('/').every(part => part.trim()));
    const [datacenter, cluster, ...resourcePool] = pool.split('/');
    replacements = {
      '<vcenter-host>': host, '<username>': username, '<password>': password,
      '<datastore>': datastore, '<pool-path>': pool,
      '<datacenter>': datacenter, '<cluster>': cluster, '<resource-pool>': resourcePool.join('/'),
    };
  }
  initialize(template, profile, replacements, existing);
  toggle(profile);
  console.log(`Advanced settings can be edited in ${directory}/*.conf.`);
  if (template === 'vsphere')
    console.log('ISO uploads use /mnt/isos. Ensure the matching NFS mount is available, or edit the upload settings.');
}

async function menu(ask) {
  const settingsFile = path.join(appHost, 'appsettings.Development.json');
  const api = get(get(fs.existsSync(settingsFile) ? readJson(settingsFile) : {}, 'Launch'), 'ApiConfig');
  console.log(`API profiles: ${get(api, 'Enabled') ? get(api, 'Profile') : 'disabled in local settings'}`);
  const action = await choose(ask, 'Action', ['configure', 'select', 'disable', 'quit'], 'configure');
  if (action === 'quit') return;
  if (action === 'disable') { toggle('remove'); return; }
  if (action === 'select') {
    const local = path.join(configRoot, 'local');
    const profiles = fs.existsSync(local) ? fs.readdirSync(local, { withFileTypes: true })
      .filter(entry => entry.isDirectory()).map(entry => entry.name).sort() : [];
    if (!profiles.length) throw new Error('No local profiles yet. Run configure-hypervisors.sh to create one.');
    toggle(await choose(ask, 'Profile', profiles));
    return;
  }
  const template = await choose(ask, 'Backend', ['proxmox', 'vsphere'], 'proxmox');
  const profile = await value(ask, 'Profile name', template, false, name => /^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(name) && name !== 'remove');
  await configure(template, profile, ask);
}

function toggle(profile) {
  const file = path.join(appHost, 'appsettings.Development.json');
  const settings = fs.existsSync(file) ? readJson(file) : {};
  const launch = get(settings, 'Launch') ?? {};
  const api = get(launch, 'ApiConfig') ?? {};
  if (profile === 'remove') {
    set(api, 'Enabled', false);
  } else {
    profileName(profile);
    const directory = path.join(configRoot, 'local', profile);
    if (!fs.existsSync(directory)) throw new Error(`Initialize the local profile first: ${directory}`);
    const base = readJson(path.join(appHost, 'appsettings.json'));
    const effective = get(merge(base, settings), 'Launch') ?? {};
    const overrides = get(get(effective, 'ApiConfig'), 'Apps') ?? {};
    for (const [app, launchName] of Object.entries(apps)) {
      const launchNames = app === 'topomojo' ? [launchName, 'TopoMojoLaunchpoint'] : [launchName];
      const selected = launchNames.some(name => {
        const env = get(process.env, `Launch__${name}`);
        const flag = env === undefined ? get(effective, name) === true : env.toLowerCase() === 'true';
        const inGroup = ['Dev', 'Prod'].some(group =>
          (get(effective, group) ?? []).some(entry => entry.toLowerCase() === name.toLowerCase()));
        const envGroup = Object.entries(process.env).some(([key, value]) =>
          /^Launch__(Dev|Prod)__\d+$/i.test(key) && value.toLowerCase() === name.toLowerCase());
        return flag || inGroup || envGroup;
      });
      const enabledEnv = get(process.env, `Launch__ApiConfig__Apps__${app}__Enabled`);
      const disabled = enabledEnv === undefined
        ? get(get(overrides, app), 'Enabled') === false : enabledEnv.toLowerCase() === 'false';
      if (selected && !disabled) {
        const conf = path.join(directory, `${app}.conf`);
        if (!fs.existsSync(conf)) throw new Error(`Selected app ${app} requires ${conf}`);
        checkComplete(conf);
      }
    }
    for (const [app, options] of Object.entries(overrides)) {
      for (const key of Object.keys(options)) {
        if (key.toLowerCase() === 'profile') delete options[key];
      }
      // A removed local key would expose a profile override from appsettings.json.
      const baseApp = get(get(get(get(base, 'Launch'), 'ApiConfig'), 'Apps'), app);
      if (get(baseApp, 'Profile') !== undefined)
        set(options, 'Profile', profile);
    }
    set(api, 'Apps', overrides);
    set(api, 'Enabled', true);
    set(api, 'Profile', profile);
  }
  set(launch, 'ApiConfig', api);
  set(settings, 'Launch', launch);
  writeSettings(file, settings);
  console.log(profile === 'remove' ? 'API file configuration disabled.' : `Selected API profile: ${profile}`);
  console.log('Restart Aspire to apply. Environment variables and user secrets can override launch settings.');
}

async function main(args) {
  const [command, action, ...rest] = args;
  if (command === 'configure') {
    if (action === 'list' && !rest.length) {
      console.log(fs.readdirSync(path.join(configRoot, 'templates')).sort().join('\n'));
    } else if (action === 'init' && (rest.length === 1 || (rest.length === 3 && rest[1] === '--profile'))) {
      initialize(rest[0], rest[2] ?? rest[0]);
      console.log(`Edit the local files, then select with: ./scripts/toggle-hypervisor.sh ${rest[2] ?? rest[0]}`);
    } else if (!action && !rest.length) {
      await withPrompts(menu);
    } else if (action === 'help' || action === '--help') {
      console.log('Usage: configure-hypervisors.sh [proxmox|vsphere [--profile NAME]] | list | init TEMPLATE [--profile NAME]');
      console.log('Without arguments, opens a menu. Guided setup fills templates and selects the profile.');
    } else if (['proxmox', 'vsphere'].includes(action) &&
      (!rest.length || (rest.length === 2 && rest[0] === '--profile'))) {
      await withPrompts(ask => configure(action, rest[1] ?? action, ask));
    } else throw new Error('Unknown setup command. Run configure-hypervisors.sh --help.');
  } else if (command === 'toggle') {
    if (!action) await withPrompts(menu);
    else if (action === 'help' || action === '--help')
      console.log('Usage: toggle-hypervisor.sh [PROFILE | remove]. Without arguments, opens a menu.');
    else if (rest.length) throw new Error('Use toggle-hypervisor.sh PROFILE | remove. Edit credentials in local profile files.');
    else if (['proxmox', 'vsphere'].includes(action) &&
      !fs.existsSync(path.join(configRoot, 'local', action)))
      await withPrompts(ask => configure(action, action, ask));
    else toggle(action);
  } else if (command === 'setup-proxmox') {
    const host = process.env.PROXMOX_HOST, token = process.env.PROXMOX_API_TOKEN;
    if (!host || !validHost(host) || !token || token !== token.trim() || /[\x00-\x1f\x7f]/.test(token))
      throw new Error('Proxmox setup requires single-line PROXMOX_HOST and PROXMOX_API_TOKEN values.');
    if (process.stdin.isTTY && process.stdout.isTTY) {
      await withPrompts(ask => configure('proxmox', 'proxmox', ask, { host, token }));
      return;
    }
    initialize('proxmox', 'proxmox', {
      '<proxmox-host>': host, '<proxmox-port>': '443',
      '<user@realm!token-id=token-secret>': token, '<vm-storage>': 'local-lvm', '<iso-storage>': 'local',
    });
    console.log('Existing files were preserved; reconcile their host and token manually if they differ.');
    for (const app of Object.keys(apps)) {
      const conf = path.join(configRoot, 'local/proxmox', `${app}.conf`);
      checkComplete(conf);
    }
    toggle('proxmox');
  } else throw new Error('Unknown API configuration command.');
}

if (require.main === module) {
  main(process.argv.slice(2)).catch(error => { console.error(error.message); process.exitCode = 1; });
}

module.exports = { readConf, readJson, configure, menu, savedProxmox };
