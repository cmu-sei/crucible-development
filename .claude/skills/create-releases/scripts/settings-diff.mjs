#!/usr/bin/env node
// Copyright 2026 Carnegie Mellon University. All Rights Reserved.
// Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.
//
// Compare an app's settings file between two releases, or list one file's settings, as flat
// keys with their default values. The keys are in the form the Helm charts use:
//   dotnet-appsettings  appsettings.json (comments and trailing commas allowed) -> Terraform__Secrets__Patterns__0
//   dotnet-conf         TopoMojo's appsettings.conf, commented "# Key = value" lines included
//   angular-settings    a UI's settings.json -> OIDCSettings.client_id (the chart's settingsYaml path)
//
// The kind and the file path come from the repo's .github/workflows/update-helm-chart.yml
// (settings_file_kind, settings_file).
//
// Usage:
//   settings-diff.mjs diff <kind> <old-file> <new-file>   ADDED / REMOVED / CHANGED lines, tab-separated
//   settings-diff.mjs keys <kind> <file>                  every key and its default
//
// Values print as JSON, so "true" (a string) and true (a boolean) are told apart. An empty
// array or object prints as [] or {}: it has no leaf keys of its own.

import { readFileSync } from "node:fs";

function stripJsonc(text) {
  let out = "";
  let inString = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    const next = text[i + 1];
    if (inString) {
      out += c;
      if (c === "\\") { out += next ?? ""; i++; }
      else if (c === '"') inString = false;
      continue;
    }
    if (c === '"') { inString = true; out += c; continue; }
    if (c === "/" && next === "/") { while (i < text.length && text[i] !== "\n") i++; out += "\n"; continue; }
    if (c === "/" && next === "*") { i += 2; while (i < text.length && !(text[i] === "*" && text[i + 1] === "/")) i++; i++; continue; }
    out += c;
  }
  // Drop trailing commas before a closing bracket, outside strings.
  let result = "";
  inString = false;
  for (let i = 0; i < out.length; i++) {
    const c = out[i];
    if (inString) {
      result += c;
      if (c === "\\") { result += out[i + 1] ?? ""; i++; }
      else if (c === '"') inString = false;
      continue;
    }
    if (c === '"') { inString = true; result += c; continue; }
    if (c === ",") {
      let j = i + 1;
      while (j < out.length && /\s/.test(out[j])) j++;
      if (out[j] === "}" || out[j] === "]") continue;
    }
    result += c;
  }
  return result;
}

function flatten(value, sep, prefix = "", into = new Map()) {
  if (Array.isArray(value)) {
    if (value.length === 0 && prefix) into.set(prefix, []);
    value.forEach((v, i) => flatten(v, sep, prefix ? `${prefix}${sep}${i}` : String(i), into));
  } else if (value !== null && typeof value === "object") {
    const keys = Object.keys(value);
    if (keys.length === 0 && prefix) into.set(prefix, {});
    for (const k of keys) flatten(value[k], sep, prefix ? `${prefix}${sep}${k}` : k, into);
  } else if (prefix) {
    into.set(prefix, value);
  }
  return into;
}

function parseConf(text) {
  // "Key = value" lines, commented or not. In the sample conf a commented line is the
  // default; an uncommented one is a value the file sets.
  const into = new Map();
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*#?\s*([A-Za-z][A-Za-z0-9_]*(?:__[A-Za-z0-9_]+)*)\s*=\s*(.*?)\s*$/);
    if (m && !line.trim().startsWith("##")) into.set(m[1], m[2]);
  }
  return into;
}

function load(kind, file) {
  const text = readFileSync(file, "utf8").replace(/^﻿/, "");
  switch (kind) {
    case "dotnet-appsettings": return flatten(JSON.parse(stripJsonc(text)), "__");
    case "angular-settings": return flatten(JSON.parse(stripJsonc(text)), ".");
    case "dotnet-conf": return parseConf(text);
    default: throw new Error(`unknown kind '${kind}' (dotnet-appsettings, dotnet-conf, angular-settings)`);
  }
}

const show = (v) => JSON.stringify(v);
const [mode, kind, a, b] = process.argv.slice(2);

try {
  if (mode === "keys" && kind && a) {
    for (const [k, v] of load(kind, a)) console.log(`${k}\t${show(v)}`);
  } else if (mode === "diff" && kind && a && b) {
    const before = load(kind, a);
    const after = load(kind, b);
    for (const [k, v] of after) if (!before.has(k)) console.log(`ADDED\t${k}\t${show(v)}`);
    for (const [k, v] of before) if (!after.has(k)) console.log(`REMOVED\t${k}\t${show(v)}`);
    for (const [k, v] of after) {
      if (before.has(k) && show(before.get(k)) !== show(v)) console.log(`CHANGED\t${k}\t${show(before.get(k))} -> ${show(v)}`);
    }
  } else {
    console.error("usage: settings-diff.mjs diff <kind> <old-file> <new-file> | keys <kind> <file>");
    process.exit(2);
  }
} catch (err) {
  console.error(`error: ${err.message}`);
  process.exit(1);
}
