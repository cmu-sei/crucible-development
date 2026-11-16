# Validate locally with e2e before merging on GitHub

Merge the approved PRs together in the repo's clone, rebuild what Aspire serves from it, run
the e2e suites once on the combined result, and merge on GitHub only if they pass. The clone
under `/mnt/data/crucible/` is the user's working copy, so `scripts/local-merge.sh` refuses a
dirty clone and puts the original checkout back.

`bash scripts/app-map.sh OWNER/REPO` prints the clone (`clone=`), its resources
(`resource=<name> kind=<kind> dist=<distPath>`) and the e2e suites that cover it (`suites=`).

## Steps

0. **Check the stack is up:** the AppHost must be running with every `resource=` that app-map.sh
   lists (and the apps its suites need) healthy. List the resources with the Aspire MCP tools or
   `aspire describe`. If the AppHost isn't running, start it as AGENTS.md describes. If an app
   isn't enabled in the launch configuration, ask the user rather than changing it.
1. **Choose the PR set:** the plan's `merge` PRs for this repo, right after `plan.sh check <plan>`
   (handle stale PRs as [applying.md](applying.md) says). The batch is per repo: a plan that
   covers several repos gets one local run per repo.
2. **Merge locally:** `bash scripts/local-merge.sh start OWNER/REPO --clone <clone> N [N ...]`.
   It merges each PR head into a new `dependabot-e2e/<timestamp>` branch off
   `origin/<default>`, resolves conflicts that are only in `package-lock.json` with npm, and
   skips any PR with another conflict. Note the skipped PRs: they aren't validated by this run.
   If the summary says a PR merged "with npm-resolved lockfile", that PR conflicts with an earlier
   one on GitHub. Restore, defer it in the plan, and start again without it, so the suites test
   exactly what will land.
3. **Rebuild each affected resource**, by the `kind=` app-map.sh prints:
   - `dotnet-project`: `aspire resource <name> rebuild`.
   - `angular-ui`, `js-app|executable`, `executable` (UIs, in dev or production mode): `npm ci`
     in the clone, delete `<clone>/<dist>` if a `dist=` is given, then
     `aspire resource <name> restart`. A dependency bump changes only `package.json` and the
     lockfile, and production mode rebuilds only when `dist` is missing or `src/` is newer.
   - `container` (bind-mounted sources, e.g. Moodle plugins): `aspire resource <name> restart`.

   Then `aspire wait <name>` until each is healthy. **REQUIRED SUB-SKILL:** use
   aspire-orchestration for anything beyond these commands (starting, file locks, ports).
4. **Run the e2e suites:** in `/mnt/data/crucible/crucible-tests`, `./run-tests.sh <suite>` for
   each suite app-map.sh lists (options and logs: that repo's `README.md`). If it lists
   `suites=none`, tell the user that no e2e suite covers the repo.
5. **If they pass:** merge on GitHub only the PRs that merged locally, before restoring:
   `bash scripts/merge-when-green.sh --expect-heads "$(git -C <clone> rev-parse --absolute-git-dir)/dependabot-e2e.state" OWNER/REPO N [N ...]`.
   It skips any PR whose head moved since it was merged locally (e.g. Dependabot rebased it),
   so nothing untested is merged. Then
   `bash scripts/local-merge.sh restore --clone <clone>` and rebuild again as in step 3, so the
   app serves the user's code. Validate the skipped PRs in a later run, after Dependabot
   rebases them.
6. **If anything fails: STOP.** Merge nothing on GitHub. Report the failing specs and ask the
   user whether to isolate the culprit. If they agree:
   1. Rerun only the failing specs (`./run-tests.sh <suite> --filter <pattern>`) to rule out
      flakiness.
   2. Check the baseline: `restore`, then `local-merge.sh start OWNER/REPO --clone <clone>`
      with no PRs (checks out `origin/<default>` alone), rebuild, and run the failing specs.
      If they fail there too, the PRs aren't the cause: report that.
   3. Only then bisect: `restore`, `start` with half of the PR set, rebuild, run just the
      failing specs, and repeat on the failing half.
   4. Report the culprit PR(s), then restore and rebuild.
7. **Don't run the full e2e suite once per PR** unless the user asked for that.

## Always restore

Run `local-merge.sh restore` at the end of every run, including after a failure or an
interruption, then rebuild (step 3). `local-merge.sh status --clone <clone>` shows a run in
progress and what it merged. Restore refuses changes that aren't build output; build changes
to tracked files on the e2e branch (e.g. the `package-lock.json` a production-mode
`npm install` rewrites) are discarded. The script never pushes.
