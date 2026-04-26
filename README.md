# KKMindWave

Umbrella repository scaffold for the full MindWave workspace.

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
- Syncs and initializes git submodules.
- Prepares the FPC toolchain via `VendorsCore\fpc\scripts\win_x64\fpc_release_setup.bat`.
- Downloads and stages the MindWave runtime DLLs.
- Attempts BodyMonitor NeuroSky source/import-lib setup via auto-discovery.
- Installs MindWaveCore server and UI dependencies.
- Builds `BodyMonitorCore` and `GnauralCore`.

Optional flags:
- `--fpc-source` forces the full FPC source build. This can take 1-2 hours.
- `--fpc-any` tries the FPC release setup first and falls back to a source build if needed.
- `--skip-build` skips the final Pascal product builds.

Notes:
- BodyMonitor NeuroSky source/import-lib setup is best-effort. If auto-discovery fails, the bootstrap continues and prints a manual follow-up command.
- `SharedPasCore` is source-only and has no standalone bootstrap step.
