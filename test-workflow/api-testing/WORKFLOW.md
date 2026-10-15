# Crucible API testing workflow

The workflow, the agents and their hand-offs, ready, the file formats, the check vocabulary, the severity scale and the usage of every script are shared by both stacks and live in [../testing/README.md](../testing/README.md). This file holds only what is particular to the API stack.

## Running the suites

- **Docker.** Every suite starts its own PostgreSQL container (`postgres:16-alpine`, Testcontainers), so several repos' suites can run at once. Tests that take no database run without Docker; every database test fails at once with one message naming the missing daemon.
- **One build per worktree.** Two `dotnet build`s in one tree race on `obj/`: one agent per worktree, and no `verify.sh` while a writer builds there.
- **Duration.** `verify.sh` runs the suite three times (tests, self-tests, coverage) plus two probes; blueprint.api's suite alone took 3m49s on 2026-10-09. Give the call a long timeout or run it in the background (../testing/README.md, "Harnesses").
- **One test.** `dotnet test <Tests> --filter "FullyQualifiedName~.<Class>.<Method>"`; the leading dot keeps `RoleRequestTests` from also matching `TeamRoleRequestTests`. Pass `-- xUnit.DiagnosticMessages=true` to see the provider banner.

## The work list

The commands a task's work list comes from, and that the writer reruns until they are clean (`<app>` is needed when the worktree folder is named otherwise):

```sh
node /mnt/data/crucible/agent-docs/api-testing/check-repo.js gates   <worktree> <app> [--covered]
node /mnt/data/crucible/agent-docs/api-testing/check-repo.js removed <worktree> <app>
node /mnt/data/crucible/agent-docs/api-testing/check-repo.js defects <worktree> <app>
node /mnt/data/crucible/agent-docs/api-testing/check-repo.js tests   <worktree>
/mnt/data/crucible/agent-docs/api-testing/sync.sh --check <worktree>
```

`gates --covered` names, per covered gate, the allowed case and the near miss it credited (and both tiers of a two-tier site); the reviewer reads those credits (CONVENTIONS section 4, "The gates check"). `removed` run without `--base` writes the script's own accounting lines (../testing/README.md, "Removed-test accounting"); the reviewer passes `--base <last ready commit>`.

## What verify.sh checks

`verify.sh [--clean] [--app <app>] [--base <ref>] [--log-dir <dir>] <worktree>`, in order: the shared files and harness (`sync.sh --check`); the test sources (`check-repo.js tests`: no defect phrase in a test comment, read across wrapped comment lines, no static `Skip`, no EF InMemory or SQLite, no inline `NewContext()` read, the three harness self-test classes present); the defect document (`check-repo.js defects`: a test an entry names carries at most a one-line `/// <summary>`); the gates (`check-repo.js gates`); the removed tests (`check-repo.js removed`); `TreatWarningsAsErrors` in force; `dotnet build` with no warning from the test project beyond the NuGet restore codes (application projects' warnings are listed under the PASS line, never failed: the standard does not change application code); `dotnet test` passing with the PostgreSQL provider banner; the harness self-tests ran and passed; a coverage run whose cobertura file excludes the migrations; the CI workflow present; a probe that a failing test fails the run; a probe that a `[Fact(Skip = ...)]` fails the build. `--clean` deletes the test project's `bin/` and `obj/` and restores first, as CI does. The step logs stay in a temp folder only when something failed; the run's own output is the verify log.

## The broken-gate check on an API

`../testing/break-gate.sh` builds the test project with the gate broken, runs the named tests through `dotnet test --filter` with a TRX logger, restores, and rebuilds. Near misses are named `Class.Method`. The edit must build under `TreatWarningsAsErrors`: `true || await ...` and `... || true` keep the collaborator referenced (CS9113), and the form that matters for a gate that throws, a negated gate, a two-tier gate, a gate assigned to a variable, a data gate, an inverted gate, a hub mapping and the doubled scope requirement is in CONVENTIONS section 5. A build that fails with the gate broken is reported, with the compiler's errors, and the file is restored.

## Delivery of an API

API branches had no PR before the 2026-10-12 final pass; `deliver.sh push` opens one for a branch that has none (decision 28 of the 2026-10-12 workflow review), with the same generated sections as the UI PRs, and CI is `build-and-test.yml`, whose provider-banner step must pass.
