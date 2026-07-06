#!/usr/bin/env bash

set -euo pipefail

# Recovers from a hung `dotnet restore` (symptom: restore sits at
# "Restoring packages for ..." for minutes with no output and no error).
#
# Root cause is almost always orphaned NuGet lock files and/or wedged MSBuild
# build-server nodes left behind when a restore is force-killed (kill -9)
# instead of stopped with Ctrl-C. This clears that debris. It does NOT delete
# downloaded packages, so the next restore is still fast.
#
# Usage: scripts/reset-nuget.sh

echo "==> Shutting down MSBuild / compiler build servers"
dotnet build-server shutdown || true

echo "==> Killing lingering dotnet / MSBuild / VBCSCompiler processes"
pkill -9 -f MSBuild.dll     || true
pkill -9 -f VBCSCompiler    || true
pkill -9 -f "dotnet restore" || true

echo "==> Removing orphaned NuGet lock files and scratch dirs"
find "${HOME}/.nuget/packages" -name "*.lock" -delete 2>/dev/null || true
rm -f "${HOME}/.local/share/NuGet/"*.lock 2>/dev/null || true
rm -rf /tmp/NuGetScratch* "${TMPDIR:-/tmp}"/NuGetScratch* 2>/dev/null || true

echo "==> Clearing the NuGet HTTP cache (forces a fresh index lookup)"
# Fixes the separate 'newly published version not found' symptom that occurs
# right after publishing a package, because the cached registration index is
# stale. Only the HTTP cache is cleared; downloaded packages are kept.
dotnet nuget locals http-cache --clear || true

echo "==> Done. Re-run your restore, e.g.:"
echo "    dotnet restore /workspaces/crucible-dev/Crucible.slnx"
