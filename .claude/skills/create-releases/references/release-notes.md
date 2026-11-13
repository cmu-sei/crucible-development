# Release notes for Crucible repositories

## Layout

Copy the layout of the repository's previous release. Most current releases use this one:

```markdown
## ⚠️ Breaking changes        <- only when an upgrade breaks something without action; first if present

* **What breaks.** What to do about it, and how to keep the old behavior if there is a way.

## Highlights

* **Short bold claim.** One or two sentences on what users or operators get.

## Upgrade notes

* **Ship with <Other.Repo X.Y.Z>** (link). Which features need it, and what fails without it.
* **<N> database migrations run on startup:** each by name, with what it adds.
* **New settings**, with defaults: `Section:Key` (default …) and what it does.
* **New permissions**, **response codes that changed**, **renamed labels** (for UIs), **removed routes**.
* `@cmusei/crucible-common` moves from A to B.
* No database migrations, configuration changes or API changes.   <- say so when true

## What's Changed

* <PR title> in https://github.com/cmu-sei/<Repo>/pull/<N>
  * One sub-bullet per detail a reader needs, taken from the PR body.

**Full Changelog**: https://github.com/cmu-sei/<Repo>/compare/<old>...<new>

<!-- helm-charts: skip -->
```

The last line is the helm skip marker. It stops the release's Update Helm Chart run from opening
a bot PR, because this skill charts the whole batch in one PR. Keep it as the last line, after a
blank line, and keep it when editing published notes.

- **Authors:** write `by @login in <url>` only if the previous release did. Dependabot is
  `@dependabot[bot]`.
- **Order:** features first, then fixes, then refactors, dependency updates and CI. Within a PR,
  lead with what changes for users.
- **Grouping:** two Dependabot bumps of the same package can share one entry
  (`node-forge 1.4.0 to 1.4.3 in …/213 and …/223`). Mark CI-, test- and refactor-only PRs
  "No runtime change" or "No functional change".
- **A maintenance release** (nothing users see) gets one Highlights bullet saying so.
- **Pairs:** when an API and UI ship together, each set of notes links the other's release, once
  it exists. Release the API first so the UI notes can link it.

## Content rules

- **Back every claim.** Each sentence comes from a PR body, a diff, a check you ran or the previous
  notes. Leave out anything you assumed: what an older client does with a new response, which
  release an old PR shipped in, whether a dependency is bundled. If it matters, check it; if you
  can't, leave it out.
- **Dev-only dependencies:** say a package "isn't in the published image" only when the package-lock
  entry has `"dev": true`.
- **Numbers and names exactly:** migration names, setting keys with their section
  (`Proxmox:GuestAgentTimeoutMilliseconds`), defaults, permission names and enum values, routes,
  status codes, and UI labels in **bold** as the UI shows them.
- **Response codes:** say "answers **409** … It used to answer 500." Give the old behavior
  whenever a code changes.
- **Changed 500 messages** from a mapping library swap are worth one bullet, because tests and
  clients can match on them.
- **Links:** inside the same repository, `#N` links itself. A PR in another repository is
  `cmu-sei/<Repo>#N`, or a full URL. A bare `#N` in a helm-charts PR points at helm-charts#N.
- **Companion PRs not yet merged:** name them, say they aren't merged, and say what doesn't work
  until they are.
- **Client packages:** if an API adds endpoints or fields, say the NuGet client isn't republished.
  Don't claim that a consumer needs it without checking how the consumer calls the API.

## Style

Plain, short, active sentences. No "we", no exclamation marks, no filler such as "various
improvements". Name the thing: "Deleting an in-use template answered 500" rather than "fixed an
error". Prefer what a user sees ("The Rating lists were empty") to what the code did.
