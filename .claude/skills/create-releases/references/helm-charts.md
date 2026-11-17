# Opening the helm-charts PR

After the releases, this skill opens one PR on `cmu-sei/helm-charts` that carries every chart change
for the batch: version bumps, and settings added or removed at the app's real default.

The release bot normally stays out of the way. Each published release runs the repository's
`.github/workflows/update-helm-chart.yml`, which calls the shared
`cmu-sei/Crucible-Github-Actions/actions/update-helm-chart@update-helm-chart-v3` action. That
action opens a PR of its own unless the release notes contain `<!-- helm-chart-pr: false -->`
(from v3.3.0), and this skill puts that marker in every release's notes. When a bot PR turns up
anyway, or earlier bot PRs left wrong values on `main`, see the **Fallback** section at the end.

## 1. Before you start

Look for **open hand-written PRs** that touch the same charts:
`gh pr list -R cmu-sei/helm-charts --state open --json number,title,isDraft,headRefName,files`.
For example, a draft prepared for this release ("Draft until the Caster release…"). If one exists,
**ask** whether to fold it into this PR, building on its branch, or to leave it alone. Its author
may intend different chart versions.

Then run the **Fallback** section's checks for bot PRs from this batch and zero values on `main`,
before working out any version. A bot PR from this batch that is already merged has put its
version bump on `main`, so step 2 must not bump that chart again: Chart Version Check only checks
that a changed chart's version moved, so it wouldn't catch a second bump. Anything else the checks
find goes into this same PR.

## 2. Work out every chart change

Work out each change against `origin/main` of helm-charts, for each released repository. The
chart paths are in the repository's `update-helm-chart.yml` (`chart_file`, `parent_chart_file`),
beside its settings file (`settings_file`, `settings_file_kind`).

1. **Versions.** Set the subchart's `appVersion` to the release. Bump its `version` at the same
   level as the app version: patch for a patch, minor for a minor. Bump each **parent** chart once,
   at the highest level among its subcharts in this PR. For example, topomojo-api and topomojo-ui
   both at patch give the topomojo chart one patch bump, not two. Skip any bump that a merged bot
   PR from this batch already put on `main` (step 1).
2. **Settings.** Get the settings file at both tags, then run
   `settings-diff.mjs diff <settings_file_kind> <old> <new>`:
   - `ADDED` scalar key: add it with the printed default, under `env:` in the subchart's
     `values.yaml` and under `<subchart>: env:` in the parent's. Put it next to related keys, not at
     the end of the block, with a one- or two-line comment taken from the app's own comment or
     Options class. Follow the file's quoting: booleans as `"true"`/`"false"`, numbers bare,
     strings quoted.
   - `ADDED` with `[]` or `{}` (connection lists, maps): don't add an empty value. If the app's
     settings file has a commented example, add the same example commented out, as the chart does
     for similar settings.
   - `REMOVED`: delete the key from both values files, whether it's set or commented out, and any
     comment that belongs only to it.
   - `CHANGED` default: if the chart doesn't set the key, nothing changes. If it does, **ask**
     whether the chart should follow the app's new default. Changing it alters what upgraded
     deployments do. The PR body and the release notes must say which the chart does.
   - UI charts (`angular-settings`) keep settings as nested YAML under `settingsYaml:`, mostly as
     commented examples. Add new keys the same way, at their dotted path.
3. **README:** the chart READMEs have settings tables, usually one table per settings section. Add
   a row for every setting you added, beside its siblings, with the same description and default
   as the values comment. Delete rows for removed settings. Correct any row the release made
   wrong. If no section fits, add a short one. CI's README Reminder check only warns, without
   failing, so read the README even when it passes.

## 3. Build, validate and open the PR

```bash
cd /mnt/data/crucible/helm-charts && git fetch -q origin
W=/tmp/helm-charts-releases
git worktree add --no-track -b release/charts-$(date +%Y%m%d) "$W" origin/main
```

Make the changes in `$W`. Check the line endings of each file you edit with `grep -c $'\r'`, and
keep them as they are. **Commit before validating.** The check scripts compare commits with
`origin/main` and report "No changed files detected" for work that isn't committed. Commit with a
message that lists each chart and setting change, then run the four checks CI runs, from `$W`:

```bash
.github/scripts/check-chart-versions.sh origin/main
.github/scripts/lint-charts.sh origin/main
python3 .github/scripts/check-values-sync.py --base-ref origin/main
.github/scripts/check-readme-sync.sh origin/main
```

Also check `helm template t charts/<chart>` for each changed chart. The images should be at the new
`appVersion`s (the image tags in values are empty, so they follow `appVersion`), and every added
setting should render with its default. A chart with optional features, such as Caster's
`certificateMap`, `gitcredentials` and `terraformrc`, should also render with them turned on.

If a check fails or you change something, commit the fix and run the checks again. Then push with
`git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push -u origin <branch>`,
and open the PR. Its body:

- **Title:** `Charts for <date> releases: <App A> X.Y.Z, <App B> …` (or the one app's name).
- **First line:** which releases it covers, with links. Use full `cmu-sei/<Repo>#N` references for
  app PRs: a bare `#N` here is a helm-charts PR.
- **Changes**, one section per chart:
  - versions as `old → new`;
  - each setting added, with its default and where that default comes from;
  - each setting removed;
  - any default whose change the user agreed to;
  - from the fallback, if it applied: the bot PRs this replaces, and each zero value corrected.
- **Breaking changes** first, if any, in the same words as the app's release notes.
- **Testing:** the four scripts and the `helm template` checks you ran.

Wait for the PR's checks (`gh pr checks <N>`): Chart Version Check, Helm Lint and Template,
Parent/Child Values Sync and README Reminder.

## 4. Getting it reviewed

The repo requires an approving review. **The user can't approve this PR**: this session opened it
from the user's account, and GitHub refuses an approval from a PR's own author ("Can not approve
your own pull request"). So:

- Report the PR and ask who should review it, then request them with
  `gh pr edit <N> -R cmu-sei/helm-charts --add-reviewer <login>`. People who have worked on the
  charts are a reasonable suggestion: `gh pr list -R cmu-sei/helm-charts --state merged -L 20
  --json author,mergedBy`.
- Merge only after someone else has approved, and only if the user asks. Use
  `gh pr merge <N> --squash --delete-branch`. Squash and rebase are the repo's merge methods.
- Use `gh pr merge --admin`, which skips the review requirement, only if the user asks for it.

If the user asked to fold a hand-written PR into this one (step 1), push to that PR's branch
instead of opening a new one. If someone else opened it, the user can approve it.

The **Crucible umbrella chart** is updated by a separate manual workflow
(`update-crucible-umbrella.yaml`, run by `workflow_dispatch`). Mention it in the report, and don't
run it.

## Fallback: bot PRs and wrong values on `main`

Two things can still come from the release bot:

- **A bot PR from this batch:** a release's notes lacked the marker or had it mistyped, so its
  Update Helm Chart run opened a PR instead of logging "Helm chart PR skipped".
- **Zero values already on `main`:** bot PRs from earlier releases, merged as they were.

**What the bot does:** it opens a PR titled `<app_name> to <version>` (for example "Player VM API
to 3.13.0", where `app_name` is in the repository's `update-helm-chart.yml`) on a branch
`update-<app-name-slug>-<version>`. It bumps the subchart's `version` and `appVersion` and the
parent chart's `version`. It adds each settings key that is new in the app to both values files,
but with a type zero value (`false`, `""` or `0`), never the app's default. For example, Vm.Api
3.13.0's Proxmox settings came through as `0` instead of 30, 8 and 2000. It doesn't apply a
changed default or remove a deleted key either. So treat a bot PR as a record of which charts it
bumped, and don't trust its values.

### Bot PRs from this batch

For each release, wait until its **Update Helm Chart** run has finished
(`gh run list -R cmu-sei/<repo> -e release`), then look for a PR:

```bash
gh pr list -R cmu-sei/helm-charts --state all --search "\"<app_name> to <version>\" in:title" \
  --json number,state,title,headRefName
```

- **None:** the marker worked. If the run failed instead, say so in the report.
- **Open:** fold its bumps into this PR, at the values worked out in step 2, and close it once this
  PR is open and its checks pass:

  ```bash
  gh pr close <bot-pr> -R cmu-sei/helm-charts --delete-branch \
    --comment "Superseded by #<new-pr>, which carries this bump and sets <keys> to the app's defaults (<values>) instead of <zero values>."
  ```

  If it's the only chart change in the batch and it's already correct (no settings changed, so the
  bot wrote no values), **ask** whether to keep it instead. The user can approve a bot PR, because
  the release workflow's app opened it, but not a PR from this session. So keeping it gets an
  urgent fix merged sooner.
- **Already merged** (the user may merge them as they appear): its version bumps are already on
  `main`, so don't repeat them. Fix its values as below.

### Zero values on `main`

For each key a bot PR added, open or merged, set the value to the default from
`settings-diff.mjs keys <kind> <file at the release tag>`. The bot appends its keys at the end of
the `env:` block, so move each one next to its related keys, with a comment, as for an `ADDED` key
in step 2. Add or correct its README row.

For each wrong value already on `main`, read the app code at that release's tag to see what the
zero value does: many settings treat `0` as unset or clamp it, and others break. Blueprint's
start-check interval fell back to 30. Vm.Api's guest-agent timeout became 1 ms and broke
guest-agent queries. The PR body says which, and tells deployments on the published chart version
whether they need to upgrade.
