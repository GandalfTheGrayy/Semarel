# Development Setup

Verified on Windows on 2026-09-14. Commands below are run from the Semarel repository root; no fixed clone location is required.

## Verified versions and discovery

| Tool | Verified version | Portable discovery method |
| --- | --- | --- |
| Godot Standard | 4.7.2 stable | `Get-Command godot`; CI/fallback: `$env:GODOT_EXECUTABLE`; WinGet alias: `%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe` |
| Git for Windows | 2.55.0.windows.3 | `Get-Command git`; optional portable root: `$env:SEMAREL_TOOLCHAIN_ROOT\PortableGit\cmd\git.exe` |
| Git LFS | 3.7.1 | `Get-Command git-lfs`; optional portable root: `$env:SEMAREL_TOOLCHAIN_ROOT\PortableGit\mingw64\bin\git-lfs.exe` |
| Python | 3.14.7 | Repository-local `.venv\Scripts\python.exe`, then `Get-Command python` |
| pip | 26.2.1 | Repository-local `.venv\Scripts\pip.exe`, then `Get-Command pip` |
| ImageMagick | 7.1.2-31 Q16-HDRI | `Get-Command magick`; optional portable root: `$env:SEMAREL_TOOLCHAIN_ROOT\ImageMagick\magick.exe` |
| FFmpeg / ffprobe | 9.0.1 full build | `Get-Command ffmpeg`; `Get-Command ffprobe` |
| SoX | 14.4.2 | `Get-Command sox` |
| Inkscape CLI | 1.4.4 | `Get-Command inkscape`; optional portable root: `$env:SEMAREL_TOOLCHAIN_ROOT\Inkscape\PFiles64\Inkscape\bin\inkscape.com` |
| ripgrep | 15.2.0 | `Get-Command rg` |
| jq | 1.8.2 | `Get-Command jq` |
| 7-Zip CLI | 26.03 | `Get-Command 7z`; optional portable root: `$env:SEMAREL_TOOLCHAIN_ROOT\7-Zip\Files\7-Zip\7z.exe` |
| hyperfine | 1.20.0 | `Get-Command hyperfine` |

The current workstation exposes shared portable fallbacks through the user-level `SEMAREL_TOOLCHAIN_ROOT` environment variable. This variable is optional: standard PATH installations and the repository-local Python environment remain supported.

Refresh PATH inside a shell opened before tools were installed:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
```

Create the local Python environment when needed:

```powershell
py -3.14 -m venv .venv
.\.venv\Scripts\python.exe -m pip --version
```

## Standard project commands

```powershell
Set-Location <Semarel repository root>

# Required after meaningful code or Godot project changes
.\tools\validate.ps1

# Optional, non-gating world-data sanity baseline
godot --headless --path . --script res://benchmarks/world_data_sanity.gd

# Environment inventory; use when setup problems are suspected
.\tools\toolcheck.ps1

# Open the editor when interactive work is needed
godot --editor --path .
```

`validate.ps1` finds the repository from its own path and does not require the current directory to be the repository root. It checks required files, main-scene configuration, headless project import/parser health, a bounded runtime launch, the headless world-data suite, and the headless terrain-visualization suite. Any failed check returns a non-zero process exit code suitable for CI.

GitHub Actions uses the official Godot 4.7.2 Standard Windows release and verifies SHA-256 before executing the same validation script. Local executable paths are never used by CI.
