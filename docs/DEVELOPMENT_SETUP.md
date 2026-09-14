# Development Setup

Verified on Windows on 2026-09-14. Repository root: `C:\Dev\Semarelrepo`.

| Tool | Version | Executable path | Useful command / notes |
| --- | --- | --- | --- |
| Godot Standard | 4.7.2 stable | `C:\Users\Muharrem Pehlevan\AppData\Local\Microsoft\WinGet\Links\godot.exe` | `godot --headless --path . --editor --quit` |
| Git for Windows | 2.55.0.windows.3 | `C:\Dev\Toolchain\PortableGit\cmd\git.exe` | Preferred Git for this repository |
| Git LFS | 3.7.1 | `C:\Dev\Toolchain\PortableGit\mingw64\bin\git-lfs.exe` | `git lfs version`; use only for targeted large binaries |
| Python | 3.14.7 | `C:\Dev\Semarelrepo\.venv\Scripts\python.exe` | `.\.venv\Scripts\python.exe --version` |
| pip | 26.2.1 | `C:\Dev\Semarelrepo\.venv\Scripts\pip.exe` | `.\.venv\Scripts\python.exe -m pip --version` |
| ImageMagick | 7.1.2-31 Q16-HDRI | `C:\Dev\Toolchain\ImageMagick\magick.exe` | `magick --version` |
| FFmpeg | 9.0.1 full build | `C:\Users\Muharrem Pehlevan\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe` | `ffmpeg -version` |
| ffprobe | 9.0.1 full build | `C:\Users\Muharrem Pehlevan\AppData\Local\Microsoft\WinGet\Links\ffprobe.exe` | `ffprobe -version` |
| SoX | 14.4.2 | `C:\Users\Muharrem Pehlevan\AppData\Local\Microsoft\WinGet\Packages\ChrisBagwell.SoX_Microsoft.Winget.Source_8wekyb3d8bbwe\sox-14.4.2\sox.exe` | `sox --version` |
| Inkscape CLI | 1.4.4 | `C:\Dev\Toolchain\Inkscape\PFiles64\Inkscape\bin\inkscape.com` | `inkscape --version` |
| ripgrep | 15.2.0 | `C:\Users\Muharrem Pehlevan\AppData\Local\Microsoft\WinGet\Links\rg.exe` | `rg --version` |
| jq | 1.8.2 | `C:\Users\Muharrem Pehlevan\AppData\Local\Microsoft\WinGet\Links\jq.exe` | `jq --version` |
| 7-Zip CLI | 26.03 | `C:\Dev\Toolchain\7-Zip\Files\7-Zip\7z.exe` | `7z` |
| hyperfine | 1.20.0 | `C:\Users\Muharrem Pehlevan\AppData\Local\Microsoft\WinGet\Links\hyperfine.exe` | `hyperfine --version` |

Refresh PATH inside a shell opened before the tools were installed:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
```

Open or validate the project:

```powershell
Set-Location C:\Dev\Semarelrepo
godot --editor --path .
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 30
.\tools\toolcheck.ps1
```

The machine also contains older global Git and Python installations. Repository automation uses the explicit portable Git and local Python 3.14 virtual environment above for reproducibility.
