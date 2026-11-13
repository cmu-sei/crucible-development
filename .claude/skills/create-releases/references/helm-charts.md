# Consolidating the helm-charts PRs

Each published release runs the repository's `.github/workflows/update-helm-chart.yml`, which opens
a PR on `cmu-sei/helm-charts`:

- **Title** `<app_name> to <version>`, for example "Player VM API to 3.13.0". `app_name` is in
  the repo's workflow file, beside `chart_file`, `parent_chart_file`, `settings_file` and
  `settings_file_kind`.
- **Branch** `update-<app-name-slug>-<version>`, for example `update-player-vm-api-3.13.0`.
- **What it does:** bumps the subchart's `version` and `appVersion`, bumps the parent chart's
  `version`, and adds settings keys that are new in the app to the subchart's and the parent's
  `values.yaml`.

**The bot gives every new key a type zero value: `false`, `""` or `0`, never the app's default.**
It doesn't apply a changed default or remove a deleted key. For example, Vm.Api 3.13.0's Proxmox
settings came through as `0` instead of 30, 8 and 2000. So the bot PRs are only a record of which
charts to bump. This phase rebuilds their content correctly in one PR.

## 1. Collect the bot PRs

For each release from this run, wait until its **Update Helm Chart** run has finished
(`gh run list -R cmu-sei/<repo> -e release`). Then find the PR:

```bash
gh pr list -R cmu-sei/helm-charts --state all --search "\"<app_name> to <version>\" in:title" \
  --json number,state,title,headRefName
```

- **Open:** it gets replaced and closed.
- **Already merged** (the user may merge them as they appear): its version bumps are already on
  `main`, so don't repeat them. Its zero-value settings still need fixing in the consolidated PR.
- **None after the workflow succeeded:** say so in the report, and still make the chart changes.

Also look for **open hand-written PRs** that touch the same charts:
`gh pr list -R cmu-sei/helm-charts --state open --json number,title,isDraft,headRefName,files`.
For example, a draft prepared for this release ("Draft until the Caster release…"). If one exists,
**ask** whether to fold it into the consolidated PR, building on its branch, or to leave it alone.
Its author may intend different chart versions than the bot's.

## 2. Work out every chart change

Work out each change against `origin/main` of helm-charts, for each released repository:

1. **Versions.** Set the subchart's `appVersion` to the release. Bump its `version` at the same
   level as the app version: patch for a patch, minor for a minor. Bump each **parent** chart once,
   at the highest level among its subcharts in this PR. For example, topomojo-api and topomojo-ui
   both at patch give the topomojo chart one patch bump, not two.
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
3. **Keys the bot added with zero values,** in open or already-merged bot PRs: set them to the
   default from `settings-diff.mjs keys <kind> <file at the new tag>`. The bot appends its keys
   at the end of the `env:` block, so move each one next to its related keys, with a comment, as
   for an `ADDED` key. For each key already on `main`, read the app code at the release tag to see
   what the zero value does: many settings treat `0` as unset or clamp it, and others break.
   Blueprint's start-check interval fell back to 30. Vm.Api's guest-agent timeout became 1 ms and
   broke guest-agent queries. The PR body says which, and tells deployments on the published chart
   version whether they need to upgrade.
4. **README:** the chart READMEs have settings tables, usually one table per settings section. Add
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
- **First line:** which releases it covers, with links, and which bot PRs it replaces. Use full
  `cmu-sei/<Repo>#N` references for app PRs: a bare `#N` here is a helm-charts PR.
- **Changes**, one section per chart:
  - versions as `old → new`;
  - each setting added, with its default and where that default comes from;
  - each setting removed;
  - each value corrected from the bot's zero value;
  - any default whose change the user agreed to.
- **Breaking changes** first, if any, in the same words as the app's release notes.
- **Testing:** the four scripts and the `helm template` checks you ran.

Wait for the PR's checks (`gh pr checks <N>`): Chart Version Check, Helm Lint and Template,
Parent/Child Values Sync and README Reminder.

## 4. Close the bot PRs

Only after the consolidated PR is open and its checks pass, close each open bot PR it replaces:

```bash
gh pr close <bot-pr> -R cmu-sei/helm-charts --delete-branch \
  --comment "Superseded by #<new-pr>, which carries this bump and sets <keys> to the app's defaults (<values>) instead of <zero values>."
```

## 5. Getting it reviewed

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

The bot PRs are different, because the release workflow's app opens them, so the user can approve
those. If the user asks to fold a hand-written PR into this one, as in step 1, push to that PR's
branch instead of opening a new one. If someone else opened it, the user can approve it.

The **Crucible umbrella chart** is updated by a separate manual workflow
(`update-crucible-umbrella.yaml`, run by `workflow_dispatch`). Mention it in the report, and don't
run it.
