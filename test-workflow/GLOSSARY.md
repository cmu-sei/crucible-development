# Crucible test workflow

The shared vocabulary of the API and UI test standards, their agents, and the orchestrator's reports to the user. Agent definitions and reports use these terms and avoid the listed alternatives.

## Language

### Gates

**Gate**:
One place in an application where a permission is checked before something is allowed: an authorization call in an API, or a component, directive, guard or route that reads a permission in a UI.
_Avoid_: permission gate, auth check, authorization point

**Allowed case**:
A test in which a user holding exactly the permission a gate reads, and nothing broader such as Root, gets through.
_Avoid_: positive test, happy path

**Near miss**:
A test in which a user who is almost allowed (a neighbouring permission, or the right one on another resource) is refused by the gate; a user with no permissions is never a near miss.
_Avoid_: denied test, negative test, empty-grant denial

**Covered gate**:
A gate with at least one allowed case and one near miss.
_Avoid_: tested gate, gate coverage

**Missing gate**:
A gate that is not covered and has no recorded reason; it blocks delivery.
_Avoid_: untested gate, gap, follow-up

**Allow-listed gate**:
A gate left uncovered because the test harness cannot reach it, with the reason recorded outside the repo and named in the pull request.
_Avoid_: accepted gap, exemption

**Provisional gate**:
A gate that a newly tightened check no longer counts as covered; it warns for one standard version and then becomes a missing gate.
_Avoid_: soft gap, pending gate

**Broken-gate check**:
A proof that a gate's near misses really exercise it: the writer temporarily disables the gate, confirms the near misses fail, and restores the code unchanged.
_Avoid_: gate break, mutation check

### Process

**Standard version**:
One dated entry in a test standard's CHANGELOG; the unit in which the standard changes.
_Avoid_: re-sync, standard update

**Round**:
One standard version taken through writer, reviewer and delivery across a chosen set of repos.
_Avoid_: wave, pass, re-sync wave

**Writer mode**:
What a writer is asked to do in a repo: setup (bring the shared harness in), create (write tests) or audit (bring existing tests up to the current standard version).
_Avoid_: audit round, adoption audit

**Green**:
A PR whose branch contains the current origin/main, merges cleanly, and passed every CI check on its latest push; `orchestration/ci-check.sh status` prints the verdict. Ready is about the tests; green is about the PR as GitHub tests it, merged with today's main.
_Avoid_: passing, CI ok

**Ready**:
A repo whose verify run passes with no missing gate, no provisional gate and no unaccounted removed test, whose review has no blocking finding, and whose broken-gate check passed; bookkeeping notes never block it.
_Avoid_: done, finished, clean

**Removed-test accounting**:
The record that matches every test a branch removed to where its behaviour is still asserted, or gives the reason it was let go.
_Avoid_: removed-test list, loss list

**Verify log**:
The output of one `verify.sh` run, stamped with the worktree's tree hash; it is current while the tree hash is unchanged, and a reviewer reads it instead of running verify again.
_Avoid_: test log, verify output

**Bookkeeping note**:
A NOTE line from a check about doc hygiene (a stale allow-list id, an unused import, an accounting format); it never blocks ready.
_Avoid_: WARN, soft failure

**Pre-push summary**:
What `deliver.sh` prints per batch before anything is committed or pushed (files deleted, tests added and removed, unmatched removals, the gates line, the commit body and the PR comment); the user approves it before the push.
_Avoid_: dry run, delivery preview
