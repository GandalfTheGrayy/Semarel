[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

function Resolve-Tool {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
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

$definitions = @(
    @{ Name='Godot'; Candidates=@('godot'); Args=@('--version') },
    @{ Name='Git'; Candidates=@('C:\Dev\Toolchain\PortableGit\cmd\git.exe', 'git'); Args=@('--version') },
    @{ Name='Git LFS'; Candidates=@('C:\Dev\Toolchain\PortableGit\mingw64\bin\git-lfs.exe', 'git-lfs'); Args=@('version') },
    @{ Name='Python'; Candidates=@((Join-Path $repositoryRoot '.venv\Scripts\python.exe'), 'python'); Args=@('--version') },
    @{ Name='pip'; Candidates=@((Join-Path $repositoryRoot '.venv\Scripts\pip.exe'), 'pip'); Args=@('--version') },
    @{ Name='ImageMagick'; Candidates=@('magick'); Args=@('--version') },
    @{ Name='FFmpeg'; Candidates=@('ffmpeg'); Args=@('-version') },
    @{ Name='ffprobe'; Candidates=@('ffprobe'); Args=@('-version') },
    @{ Name='SoX'; Candidates=@('sox'); Args=@('--version') },
    @{ Name='Inkscape'; Candidates=@('inkscape'); Args=@('--version') },
    @{ Name='ripgrep'; Candidates=@('rg'); Args=@('--version') },
    @{ Name='jq'; Candidates=@('jq'); Args=@('--version') },
    @{ Name='7-Zip'; Candidates=@('7z'); Args=@() },
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
