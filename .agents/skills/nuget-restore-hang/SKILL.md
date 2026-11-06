---
name: nuget-restore-hang
description: Diagnose and fix a hung `dotnet restore` or `aspire run` stuck at "Restoring packages for ...", or a stale "Unable to find package" error right after publishing. Use whenever a restore hangs with no output or a just-published package version is not found.
---

# Troubleshooting: hung `dotnet restore`

If `dotnet restore` (or `aspire run`) hangs for minutes at `Restoring packages for ...` with no output and no error, the cause is almost always orphaned NuGet lock files and/or wedged MSBuild build-server nodes left behind when a previous restore was force-killed (`kill -9`) instead of stopped with Ctrl-C.

- Fix: run `scripts/reset-nuget.sh`, then re-run the restore.
- Prevention: stop a slow restore with **Ctrl-C** (SIGINT lets NuGet release its locks); never `kill -9` it.
- Separate symptom: right after publishing a new package version, restore may report `Unable to find package ... (>= x.y.z)` even though it is on nuget.org — that is a stale cached registration index. Run `dotnet nuget locals http-cache --clear` (also done by `scripts/reset-nuget.sh`).
