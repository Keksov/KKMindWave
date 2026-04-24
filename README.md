# KKMindWave

Umbrella repository scaffold for the full MindWave workspace.

Intended submodules:
- `MindWaveCore`
- `BodyMonitorCore`
- `GnauralCore`
- `SharedPasCore`

Suggested bootstrap flow:
1. Replace `<org>` in `.gitmodules.example` with the final GitHub owner or organization.
2. Rename `.gitmodules.example` to `.gitmodules` after the remote repos exist.
3. Run `./init-submodules.ps1`.
4. Open `KKMindWave.code-workspace` in VS Code.

This scaffold mirrors the renamed local core layout in `c:/projects/MindWave`.
