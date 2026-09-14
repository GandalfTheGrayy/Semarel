[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
$toolchainRoot = $env:SEMAREL_TOOLCHAIN_ROOT
if (-not $toolchainRoot) {
    $toolchainRoot = [Environment]::GetEnvironmentVariable('SEMAREL_TOOLCHAIN_ROOT', 'User')
}

function Resolve-Tool {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        if ([IO.Path]::IsPathRooted($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
        $command = Get-Command $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Source }
    }
    return $null
}

function Read-Version {
    param([string]$Executable, [string[]]$Arguments)
    try {
        $lines = @(& $Executable @Arguments 2>&1 | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
        if ($lines) { return $lines[0] }
        return 'version output unavailable'
    } catch {
        return "version check failed: $($_.Exception.Message)"
    }
}

$portableGit = if ($toolchainRoot) { Join-Path $toolchainRoot 'PortableGit\cmd\git.exe' } else { '' }
$portableGitLfs = if ($toolchainRoot) { Join-Path $toolchainRoot 'PortableGit\mingw64\bin\git-lfs.exe' } else { '' }
$portableImageMagick = if ($toolchainRoot) { Join-Path $toolchainRoot 'ImageMagick\magick.exe' } else { '' }
$portableInkscape = if ($toolchainRoot) { Join-Path $toolchainRoot 'Inkscape\PFiles64\Inkscape\bin\inkscape.com' } else { '' }
$portableSevenZip = if ($toolchainRoot) { Join-Path $toolchainRoot '7-Zip\Files\7-Zip\7z.exe' } else { '' }

$definitions = @(
    @{ Name='Godot'; Candidates=@('godot'); Args=@('--version') },
    @{ Name='Git'; Candidates=@($portableGit, 'git'); Args=@('--version') },
    @{ Name='Git LFS'; Candidates=@($portableGitLfs, 'git-lfs'); Args=@('version') },
    @{ Name='Python'; Candidates=@((Join-Path $repositoryRoot '.venv\Scripts\python.exe'), 'python'); Args=@('--version') },
    @{ Name='pip'; Candidates=@((Join-Path $repositoryRoot '.venv\Scripts\pip.exe'), 'pip'); Args=@('--version') },
    @{ Name='ImageMagick'; Candidates=@($portableImageMagick, 'magick'); Args=@('--version') },
    @{ Name='FFmpeg'; Candidates=@('ffmpeg'); Args=@('-version') },
    @{ Name='ffprobe'; Candidates=@('ffprobe'); Args=@('-version') },
    @{ Name='SoX'; Candidates=@('sox'); Args=@('--version') },
    @{ Name='Inkscape'; Candidates=@($portableInkscape, 'inkscape'); Args=@('--version') },
    @{ Name='ripgrep'; Candidates=@('rg'); Args=@('--version') },
    @{ Name='jq'; Candidates=@('jq'); Args=@('--version') },
    @{ Name='7-Zip'; Candidates=@($portableSevenZip, '7z'); Args=@() },
    @{ Name='hyperfine'; Candidates=@('hyperfine'); Args=@('--version') }
)

foreach ($definition in $definitions) {
    $executable = Resolve-Tool -Candidates $definition.Candidates
    if (-not $executable) {
        Write-Host "[MISSING] $($definition.Name)"
        continue
    }
    $version = Read-Version -Executable $executable -Arguments $definition.Args
    Write-Host "[OK] $($definition.Name) - $version"
    Write-Host "     $executable"
}
