# Devcontainer CI

The `.github/workflows/devcontainer-ci.yml` workflow builds the dev container on every PR and `main` push (amd64 and arm64), runs `postCreateCommand`, then executes `.devcontainer/ci-verify-tools.sh` to confirm each expected tool is on `PATH`. Repo cloning is skipped in CI via `CRUCIBLE_CI_SKIP_CLONE=1`, forwarded into the container through `containerEnv` in `devcontainer.json`.

**IMPORTANT:** When adding a new tool to the dev container — whether via a new devcontainer Feature, a Dockerfile `RUN`, or a `postcreate.sh` install step — add a matching `check` line to `.devcontainer/ci-verify-tools.sh`. Prefer the shortest version command that doesn't touch the network or a server (e.g. `kubectl version --client=true`, not `kubectl version`).
