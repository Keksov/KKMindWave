# KKMindWave

Thin workspace/bootstrap repository for the full MindWave workspace.

Child repositories are regular sibling clones described by `workspace-repos.txt`. They are no longer managed as git submodules.

Workspace folders:
- `MindWaveCore`
- `BodyMonitorCore`
- `GnauralCore`
- `SharedPasCore`
- `VendorsCore`

Bootstrap on Windows x64:
1. Open a terminal in the repository root.
2. Run `win_x64-bootstrap.bat`.
3. Open `KKMindWave.code-workspace` in VS Code.

Default bootstrap behavior:
- Ensures the child repositories from `workspace-repos.txt` are cloned.
- Prepares the FPC toolchain via `VendorsCore\fpc\scripts\win_x64\fpc_release_setup.bat`.
- Downloads and stages the MindWave runtime DLLs.
- Attempts BodyMonitor NeuroSky source/import-lib setup via auto-discovery.
- Installs MindWaveCore server and UI dependencies.
- Builds `BodyMonitorCore` and `GnauralCore`.

Optional flags:
- `--fpc-source` forces the full FPC source build. This can take 1-2 hours.
- `--fpc-any` tries the FPC release setup first and falls back to a source build if needed.
- `--skip-build` skips the final Pascal product builds.

Daily workspace helpers:
- `clone-workspace.bat` clones any missing child repositories from `workspace-repos.txt`.
- `pull-workspace.bat` validates every repo first, then runs `git pull --ff-only` on the current branch of each repo if the full workspace passes preflight.
- `push-workspace.bat` validates every repo first, then pushes only repos that are strictly ahead of upstream.

Migrating an old submodule-based checkout:
1. Run `precheck-reclone.bat` in the existing `KKMindWave` root.
2. If it reports blocking repos, push, commit, stash, or otherwise back up that work first.
3. Delete the old checkout and clone `KKMindWave` again.
4. Run `win_x64-bootstrap.bat`.

Notes:
- BodyMonitor NeuroSky source/import-lib setup is best-effort. If auto-discovery fails, the bootstrap continues and prints a manual follow-up command.
- `SharedPasCore` is source-only and has no standalone bootstrap step.
