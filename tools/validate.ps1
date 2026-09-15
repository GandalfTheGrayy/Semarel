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
    'scripts\world\world_change_set.gd',
    'scripts\world\world_grid.gd',
    'scripts\generation\world_generator.gd',
    'scripts\generation\world_fingerprint.gd',
    'scripts\simulation\simulation_clock.gd',
    'scripts\simulation\prototype_aging_system.gd',
    'scripts\simulation\prototype_entity_movement.gd',
    'scripts\simulation\prototype_lifecycle_transition.gd',
    'scripts\entities\entity_store.gd',
    'scripts\entities\living_state_store.gd',
    'scripts\entities\remains_state_store.gd',
    'scripts\entities\prototype_owner_reference_store.gd',
    'scripts\presentation\world_presentation_config.gd',
    'scripts\presentation\debug_entity_renderer.gd',
    'scripts\presentation\elevation_rasterizer.gd',
    'scripts\presentation\elevation_overlay_renderer.gd',
    'scripts\presentation\terrain_palette.gd',
    'scripts\presentation\terrain_rasterizer.gd',
    'scripts\presentation\terrain_renderer.gd',
    'scripts\presentation\world_inspector.gd',
    'scripts\presentation\world_preview_fixture.gd',
    'tests\world_data_test.gd',
    'tests\terrain_visualization_test.gd',
    'tests\world_change_set_test.gd',
    'tests\world_layer_extensibility_test.gd',
    'tests\elevation_visualization_test.gd',
    'tests\world_generation_test.gd',
    'tests\simulation_clock_test.gd',
    'tests\entity_store_test.gd',
    'tests\living_state_store_test.gd',
    'tests\remains_state_store_test.gd',
    'tests\prototype_owner_reference_store_test.gd',
    'tests\prototype_aging_system_test.gd',
    'tests\debug_entity_renderer_test.gd',
    'tests\entity_movement_test.gd',
    'benchmarks\world_generation_sanity.gd',
    'benchmarks\entity_store_sanity.gd',
    'benchmarks\entity_movement_sanity.gd',
    'benchmarks\lifecycle_simulation_sanity.gd',
    'docs\PLANNING_GUARDRAILS.md',
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

$terrainVisualizationTest = Join-Path $repositoryRoot 'tests\terrain_visualization_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $terrainVisualizationTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/terrain_visualization_test.gd'
    )
    $testPassed = $testResult.Output -match '(?m)^TERRAIN_VISUALIZATION_TESTS_PASSED assertions=\d+\s*$'
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'Terrain visualization tests' 'headless presentation suite completed'
    } else {
        Write-Fail 'Terrain visualization tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'Terrain visualization tests' 'test script or Godot executable is missing'
}

$worldChangeSetTest = Join-Path $repositoryRoot 'tests\world_change_set_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $worldChangeSetTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/world_change_set_test.gd'
    )
    $testPassed = $testResult.Output -match '(?m)^WORLD_CHANGE_SET_TESTS_PASSED assertions=\d+\s*$'
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'World change-set tests' 'headless multi-consumer suite completed'
    } else {
        Write-Fail 'World change-set tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'World change-set tests' 'test script or Godot executable is missing'
}

$worldLayerExtensibilityTest = Join-Path $repositoryRoot 'tests\world_layer_extensibility_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $worldLayerExtensibilityTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/world_layer_extensibility_test.gd'
    )
    $testPassed = $testResult.Output -match '(?m)^WORLD_LAYER_EXTENSIBILITY_TESTS_PASSED assertions=\d+\s*$'
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'World layer extensibility tests' 'headless multi-layer suite completed'
    } else {
        Write-Fail 'World layer extensibility tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'World layer extensibility tests' 'test script or Godot executable is missing'
}

$elevationVisualizationTest = Join-Path $repositoryRoot 'tests\elevation_visualization_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $elevationVisualizationTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/elevation_visualization_test.gd'
    )
    $testPassed = $testResult.Output -match '(?m)^ELEVATION_VISUALIZATION_TESTS_PASSED assertions=\d+\s*$'
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'Elevation visualization tests' 'headless secondary-presentation suite completed'
    } else {
        Write-Fail 'Elevation visualization tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'Elevation visualization tests' 'test script or Godot executable is missing'
}

$worldGenerationTest = Join-Path $repositoryRoot 'tests\world_generation_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $worldGenerationTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/world_generation_test.gd'
    )
    $testPassed = $testResult.Output -match '(?m)^WORLD_GENERATION_TESTS_PASSED assertions=\d+\s*$'
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'World generation tests' 'headless deterministic generation suite completed'
    } else {
        Write-Fail 'World generation tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'World generation tests' 'test script or Godot executable is missing'
}

$simulationClockTest = Join-Path $repositoryRoot 'tests\simulation_clock_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $simulationClockTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/simulation_clock_test.gd'
    )
    $testPassed = $testResult.Output -match '(?m)^SIMULATION_CLOCK_TESTS_PASSED assertions=\d+\s*$'
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'Simulation clock tests' 'headless fixed-step timing suite completed'
    } else {
        Write-Fail 'Simulation clock tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'Simulation clock tests' 'test script or Godot executable is missing'
}

$entityStoreTest = Join-Path $repositoryRoot 'tests\entity_store_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $entityStoreTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/entity_store_test.gd'
    )
    $testPassed = $testResult.Output -match '(?m)^ENTITY_STORE_TESTS_PASSED assertions=\d+\s*$'
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'Entity store tests' 'headless compact lifecycle suite completed'
    } else {
        Write-Fail 'Entity store tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'Entity store tests' 'test script or Godot executable is missing'
}

$livingStateStoreTest = Join-Path $repositoryRoot 'tests\living_state_store_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $livingStateStoreTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/living_state_store_test.gd'
    )
    $testPassed = $testResult.Output -match '(?m)^LIVING_STATE_STORE_TESTS_PASSED assertions=\d+\s*$'
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'Living state store tests' 'headless optional-state suite completed'
    } else {
        Write-Fail 'Living state store tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'Living state store tests' 'test script or Godot executable is missing'
}

$remainsStateStoreTest = Join-Path $repositoryRoot 'tests\remains_state_store_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $remainsStateStoreTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/remains_state_store_test.gd'
    )
    $testPassed = $testResult.Output -match '(?m)^REMAINS_STATE_STORE_TESTS_PASSED assertions=\d+\s*$'
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'Remains state store tests' 'headless lifecycle-transition suite completed'
    } else {
        Write-Fail 'Remains state store tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'Remains state store tests' 'test script or Godot executable is missing'
}

$prototypeOwnerReferenceStoreTest = Join-Path $repositoryRoot 'tests\prototype_owner_reference_store_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $prototypeOwnerReferenceStoreTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/prototype_owner_reference_store_test.gd'
    )
    $testPassed = (
        ($testResult.Output -match '(?m)^PROTOTYPE_OWNER_REFERENCE_STORE_TESTS_PASSED assertions=[1-9]\d*\s*$') -and
        ($testResult.Output -notmatch '(?m)^(SCRIPT ERROR|ERROR):')
    )
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'Prototype owner reference store tests' 'headless stable-reference suite completed'
    } else {
        Write-Fail 'Prototype owner reference store tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'Prototype owner reference store tests' 'test script or Godot executable is missing'
}

$debugEntityRendererTest = Join-Path $repositoryRoot 'tests\debug_entity_renderer_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $debugEntityRendererTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/debug_entity_renderer_test.gd'
    )
    $testPassed = $testResult.Output -match '(?m)^DEBUG_ENTITY_RENDERER_TESTS_PASSED assertions=\d+\s*$'
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'Debug entity renderer tests' 'headless single-node presentation suite completed'
    } else {
        Write-Fail 'Debug entity renderer tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'Debug entity renderer tests' 'test script or Godot executable is missing'
}

$entityMovementTest = Join-Path $repositoryRoot 'tests\entity_movement_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $entityMovementTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/entity_movement_test.gd'
    )
    $testPassed = $testResult.Output -match '(?m)^ENTITY_MOVEMENT_TESTS_PASSED assertions=\d+\s*$'
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'Entity movement tests' 'headless deterministic movement suite completed'
    } else {
        Write-Fail 'Entity movement tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'Entity movement tests' 'test script or Godot executable is missing'
}

$prototypeAgingSystemTest = Join-Path $repositoryRoot 'tests\prototype_aging_system_test.gd'
if ($script:godotExecutable -and (Test-Path -LiteralPath $prototypeAgingSystemTest -PathType Leaf)) {
    $testResult = Invoke-GodotCapturedCheck -Arguments @(
        '--headless',
        '--path',
        $repositoryRoot,
        '--script',
        'res://tests/prototype_aging_system_test.gd'
    )
    $testPassed = (
        ($testResult.Output -match '(?m)^PROTOTYPE_AGING_SYSTEM_TESTS_PASSED assertions=[1-9]\d*\s*$') -and
        ($testResult.Output -notmatch '(?m)^(SCRIPT ERROR|ERROR):')
    )
    if ($testResult.ExitCode -eq 0 -and $testPassed) {
        Write-Pass 'Prototype aging system tests' 'headless autonomous-lifecycle suite completed'
    } else {
        Write-Fail 'Prototype aging system tests' "success marker missing or Godot exited with code $($testResult.ExitCode)"
    }
} else {
    Write-Fail 'Prototype aging system tests' 'test script or Godot executable is missing'
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "VALIDATION FAILED ($($failures.Count) check(s))" -ForegroundColor Red
    exit 1
}

Write-Host 'VALIDATION PASSED' -ForegroundColor Green
exit 0
