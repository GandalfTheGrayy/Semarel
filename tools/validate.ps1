[CmdletBinding()]
param(
    [string]$GodotPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
$failures = [Collections.Generic.List[string]]::new()

function Write-Pass {
    param([string]$Name, [string]$Detail)
    $suffix = if ($Detail) { " - $Detail" } else { '' }
    Write-Host "[PASS] $Name$suffix"
}

function Write-Fail {
    param([string]$Name, [string]$Detail)
    $script:failures.Add($Name)
    Write-Host "[FAIL] $Name - $Detail" -ForegroundColor Red
}

function Resolve-GodotExecutable {
    $command = Get-Command godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }

    $fallbacks = [Collections.Generic.List[string]]::new()
    if ($GodotPath) { $fallbacks.Add($GodotPath) }
    if ($env:GODOT_EXECUTABLE) { $fallbacks.Add($env:GODOT_EXECUTABLE) }
    if ($env:LOCALAPPDATA) {
        $fallbacks.Add((Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\godot.exe'))
    }

    foreach ($candidate in $fallbacks) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
}

function Invoke-GodotCheck {
    param([string[]]$Arguments)
    $quotedArguments = @($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + $_.Replace('"', '\"') + '"' } else { $_ }
    })
    $process = Start-Process -FilePath $script:godotExecutable -ArgumentList $quotedArguments -NoNewWindow -Wait -PassThru
    return $process.ExitCode
}

function Invoke-GodotCapturedCheck {
    param([string[]]$Arguments)
    $quotedArguments = @($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + $_.Replace('"', '\"') + '"' } else { $_ }
    })
    $standardOutputPath = [IO.Path]::GetTempFileName()
    $standardErrorPath = [IO.Path]::GetTempFileName()
    try {
        $process = Start-Process `
            -FilePath $script:godotExecutable `
            -ArgumentList $quotedArguments `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $standardOutputPath `
            -RedirectStandardError $standardErrorPath
        $standardOutput = Get-Content -LiteralPath $standardOutputPath -Raw
        $standardError = Get-Content -LiteralPath $standardErrorPath -Raw
        if ($standardOutput) { Write-Host $standardOutput.TrimEnd() }
        if ($standardError) { Write-Host $standardError.TrimEnd() }
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Output = $standardOutput + $standardError
        }
    } finally {
        Remove-Item -LiteralPath $standardOutputPath, $standardErrorPath -Force -ErrorAction SilentlyContinue
    }
}

$script:godotExecutable = Resolve-GodotExecutable
if (-not $script:godotExecutable) {
    Write-Fail 'Godot executable' 'godot was not found on PATH or in configured fallback locations'
} else {
    $versionExitCode = Invoke-GodotCheck -Arguments @('--version')
    if ($versionExitCode -eq 0) {
        Write-Pass 'Godot executable' $script:godotExecutable
    } else {
        Write-Fail 'Godot executable' "could not run $script:godotExecutable"
        $script:godotExecutable = $null
    }
}

$requiredFiles = @(
    'project.godot',
    'scenes\main.tscn',
    'scripts\world\terrain_types.gd',
    'scripts\world\world_chunk_data.gd',
    'scripts\world\world_grid.gd',
    'tests\world_data_test.gd',
    'PROJECT_CONTEXT.md',
    'NEXT.md',
    'AGENTS.md'
)
$missingFiles = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $repositoryRoot $_) -PathType Leaf) })
if ($missingFiles.Count -eq 0) {
    Write-Pass 'Required repository files' "$($requiredFiles.Count) files found"
} else {
    Write-Fail 'Required repository files' ($missingFiles -join ', ')
}

$mainSceneValid = $false
$projectFile = Join-Path $repositoryRoot 'project.godot'
if (Test-Path -LiteralPath $projectFile -PathType Leaf) {
    $projectText = Get-Content -LiteralPath $projectFile -Raw
    $mainSceneMatch = [regex]::Match($projectText, '(?m)^run/main_scene="res://([^\"]+)"')
    if ($mainSceneMatch.Success) {
        $mainSceneResource = $mainSceneMatch.Groups[1].Value
        $mainScenePath = Join-Path $repositoryRoot ($mainSceneResource.Replace('/', [IO.Path]::DirectorySeparatorChar))
        if (Test-Path -LiteralPath $mainScenePath -PathType Leaf) {
            $mainSceneValid = $true
            Write-Pass 'Main scene' "res://$mainSceneResource"
        } else {
            Write-Fail 'Main scene' "configured scene does not exist: res://$mainSceneResource"
        }
    } else {
        Write-Fail 'Main scene' 'run/main_scene is not configured in project.godot'
    }
} else {
    Write-Fail 'Main scene' 'project.godot is missing'
}

if ($script:godotExecutable -and (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
    $parseExitCode = Invoke-GodotCheck -Arguments @('--headless', '--path', $repositoryRoot, '--editor', '--quit')
    if ($parseExitCode -eq 0) {
        Write-Pass 'Project parse' 'headless import/parser validation completed'
    } else {
        Write-Fail 'Project parse' "Godot exited with code $parseExitCode"
    }
} else {
    Write-Fail 'Project parse' 'prerequisites failed'
}

if ($script:godotExecutable -and $mainSceneValid) {
    $runtimeExitCode = Invoke-GodotCheck -Arguments @('--headless', '--path', $repositoryRoot, '--quit-after', '30')
    if ($runtimeExitCode -eq 0) {
        Write-Pass 'Runtime smoke test' 'main scene completed a bounded headless run'
    } else {
        Write-Fail 'Runtime smoke test' "Godot exited with code $runtimeExitCode"
    }
} else {
    Write-Fail 'Runtime smoke test' 'prerequisites failed'
}

$worldDataTest = Join-Path $repositoryRoot 'tests\world_data_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $worldDataTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/world_data_test.gd'
    )
    $testPassed = $testResult.Output -match '(?m)^WORLD_DATA_TESTS_PASSED assertions=\d+\s*$'
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'World data tests' 'headless data-only suite completed'
    } else {
        Write-Fail 'World data tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'World data tests' 'test script or Godot executable is missing'
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "VALIDATION FAILED ($($failures.Count) check(s))" -ForegroundColor Red
    exit 1
}

Write-Host 'VALIDATION PASSED' -ForegroundColor Green
exit 0
