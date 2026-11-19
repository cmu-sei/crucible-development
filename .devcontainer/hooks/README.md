# Personal Startup Scripts

Put shell scripts here to customize the dev container for yourself. On every container start, `.devcontainer/poststart.sh` runs each `*.sh` file in this directory in name order, using `bash -l` from the repository root. Prefix names with numbers (`10-foo.sh`, `20-bar.sh`) to control the order.

Everything in this directory except this README and the `*.example` files is git-ignored, so your scripts stay local. They live in the repository folder on your machine, so they survive container rebuilds.

- Scripts run on every start, not only after a rebuild, so make each one safe to repeat: check whether the work is already done before doing it.
- A failing script prints a warning and does not stop container start or the scripts after it.
- Scripts run in the foreground, so container start waits for them. Background anything slow, as `poststart.sh` does for `scripts/restore-skills.sh`.

## Example: Install a VS Code Extension

[`install-extension.sh.example`](install-extension.sh.example) installs a VS Code extension if it is not already installed. Copy it to a `.sh` name to enable it:

```bash
cp .devcontainer/hooks/install-extension.sh.example .devcontainer/hooks/10-install-extension.sh
```

Extensions installed this way are removed on every rebuild and reinstalled on the next start. The `--install-extension` option also accepts a path to a `.vsix` file, for extensions that are not on the Marketplace; the example's comments show how.

For Marketplace extensions you want in every dev container, not only this one, you can instead list them in the `dev.containers.defaultExtensions` setting of VS Code on your own machine.
