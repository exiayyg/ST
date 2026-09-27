param(
    [ValidateSet('Fast', 'Full', 'Visual', 'Interaction', 'Performance', 'Playthrough', 'Audio')][string]$Suite = 'Fast',
    [string]$GodotPath = 'E:\Godot\godot.exe',
    [string]$Label = 'current',
    [int]$TimeoutSeconds = 300
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$runRoot = Join-Path $projectRoot ('artifacts/qa/' + $Label + '-' + [Guid]::NewGuid().ToString('N'))
$sandboxProject = Join-Path $runRoot 'project'
New-Item -ItemType Directory -Path $sandboxProject -Force | Out-Null
# A disposable project and application-data directory protect the editor and real progress.
& robocopy $projectRoot $sandboxProject /E /NFL /NDL /NJH /NJS /NP /XD .git .godot .fennara .agents artifacts native | Out-Null
if ($LASTEXITCODE -ge 8) { throw 'Could not create isolated validation project' }
New-Item -ItemType Directory -Path (Join-Path $sandboxProject 'artifacts') -Force | Out-Null
$balancePath = Join-Path $sandboxProject 'config/balance/balance.json'
$balanceBytes = [IO.File]::ReadAllBytes($balancePath)
$results = [System.Collections.Generic.List[object]]::new()
$previousAppData = $env:APPDATA
$env:APPDATA = Join-Path $runRoot 'appdata'
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
function Invoke-Check([string]$Name, [string]$Executable, [string[]]$Arguments) {
    # Non-audio suites isolate output-device changes. The Audio suite explicitly
    # exercises the real device; Dummy results are never listening acceptance.
    if ($Executable -eq $GodotPath -and $Name -ne 'audio_device') { $Arguments = @('--audio-driver', 'Dummy') + $Arguments }
    # Each executable receives the same authored defaults, even if a save regression writes them.
    [IO.File]::WriteAllBytes($balancePath, $balanceBytes)
    $env:APPDATA = Join-Path $runRoot ('appdata/' + $Name)
    New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
    $out = Join-Path $runRoot ($Name + '.out.log')
    $err = Join-Path $runRoot ($Name + '.err.log')
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $quotedArguments = @($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' })
    $process = Start-Process -FilePath $Executable -ArgumentList $quotedArguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
    $process.Refresh()
    $log = (Get-Content $out, $err -Raw -ErrorAction SilentlyContinue) -join "`n"
    $passed = -not $timedOut -and $process.ExitCode -eq 0 -and $log -notmatch '(?m)(SCRIPT ERROR:|ERROR:|FAILED:|FAIL:|Parse Error:)'
    $metrics = [ordered]@{}
    $budgets = switch ($Name) {
        'pipeline' { @{ simulation_60hz_p95_ms = 8.0; frame_p95_ms = (1000.0 / 60.0) } }
        'enemy_ai' { @{ p95_ms = 2.0 } }
        default { @{} }
    }
    foreach ($metric in $budgets.Keys) {
        $sample = [regex]::Match($log, '(?<![\w])' + $metric + '=([0-9.]+)')
        if (-not $sample.Success) { $passed = $false; continue }
        $measurement = [double]::Parse($sample.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
        $metrics[$metric] = @{ value=$measurement; limit=$budgets[$metric] }
        if ($measurement -gt $budgets[$metric]) { $passed = $false }
    }
    $results.Add([ordered]@{ name=$Name; passed=$passed; exit_code=$process.ExitCode; timeout=$timedOut; seconds=$timer.Elapsed.TotalSeconds; metrics=$metrics; stdout=$out; stderr=$err })
    Write-Output "$Name : $passed ($($process.ExitCode))"
    if (-not $passed) { Write-Output $log }
}
try {
    Invoke-Check 'import' $GodotPath @('--headless', '--path', $sandboxProject, '--editor', '--import')
    if (-not $results[-1].passed) { throw 'Import failed; tests were not run' }
    if ($Suite -in @('Fast', 'Full')) {
        Invoke-Check 'numeric_coverage' (Get-Process -Id $PID).Path @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'check_balance_coverage.ps1'), '-ProjectRoot', $sandboxProject)
        $scenes = @('balance_config', 'prototype_logic', 'runtime_ux_regressions', 'v03_tutorial', 'campaign_framework', 'frontend_navigation', 'native_lifecycle')
        foreach ($test in $scenes) {
            Invoke-Check $test $GodotPath @('--headless', '--path', $sandboxProject, "res://scenes/tests/${test}_test.tscn")
        }
        foreach ($test in @('test_combat_skeleton', 'test_endless_mode', 'trace_world_runtime', 'test_balance_reset', 'test_v05_tutorial', 'test_v051_playtest', 'test_v06_presentation', 'test_mouse_interactions', 'report_v05_reachability')) {
            Invoke-Check $test $GodotPath @('--headless', '--path', $sandboxProject, '--script', "res://tools/$test.gd")
        }
        if (Test-Path (Join-Path $sandboxProject 'tools/test_framework_modules.gd')) {
            Invoke-Check 'framework_modules' $GodotPath @('--headless', '--path', $sandboxProject, '--script', 'res://tools/test_framework_modules.gd')
        }
    }
    if ($Suite -eq 'Full') {
        Invoke-Check 'playtest_process_lifecycle' (Get-Process -Id $PID).Path @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'test_playtest_process_lifecycle.ps1'), '-GodotPath', $GodotPath, '-ProjectPath', $sandboxProject)
        $ctest = (Get-Command ctest -ErrorAction Stop).Source
        Invoke-Check 'native' $ctest @('--test-dir', (Join-Path $projectRoot 'native/build-debug'), '--output-on-failure')
    }
    if ($Suite -eq 'Visual') {
        Invoke-Check 'frontend_capture' $GodotPath @('--path', $sandboxProject, '--rendering-method', 'mobile', '--rendering-driver', 'd3d12', 'res://scenes/tests/capture_frontend_stage.tscn')
        Invoke-Check 'v06_ui' $GodotPath @('--path', $sandboxProject, '--script', 'res://tools/test_v06_ui.gd')
        Invoke-Check 'v06_catalog' $GodotPath @('--path', $sandboxProject, '--windowed', '--resolution', '1600x1000', '--script', 'res://tools/capture_v06_catalog.gd')
    }
    if ($Suite -eq 'Interaction') {
        Invoke-Check 'drag_runtime' $GodotPath @('--path', $sandboxProject, '--rendering-method', 'mobile', '--rendering-driver', 'd3d12', '--script', 'res://tools/test_drag_runtime.gd')
    }
    if ($Suite -eq 'Audio') {
        Invoke-Check 'audio_bake' $GodotPath @('--headless', '--path', $sandboxProject, '--script', 'res://tools/bake_energy_audio.gd')
        Invoke-Check 'audio_import' $GodotPath @('--headless', '--path', $sandboxProject, '--editor', '--import')
        Invoke-Check 'audio_device' $GodotPath @('--path', $sandboxProject, '--windowed', '--resolution', '1280x720', '--script', 'res://tools/test_v06_audio.gd')
    }
    if ($Suite -eq 'Performance') {
        Invoke-Check 'pipeline' $GodotPath @('--path', $sandboxProject, '--windowed', '--resolution', '1152x648', '--rendering-method', 'mobile', '--rendering-driver', 'd3d12', 'res://scenes/tests/pipeline_benchmark.tscn')
        Invoke-Check 'enemy_ai' $GodotPath @('--headless', '--path', $sandboxProject, '--script', 'res://tools/benchmark_enemy_ai.gd')
    }
    if ($Suite -eq 'Playthrough') {
        Invoke-Check 'v051_real_ui' $GodotPath @('--path', $sandboxProject, '--rendering-method', 'mobile', '--rendering-driver', 'd3d12', '--script', 'res://tools/test_v051_ui.gd')
        Invoke-Check 'v05_real_input' $GodotPath @('--path', $sandboxProject, '--rendering-method', 'mobile', '--rendering-driver', 'd3d12', '--script', 'res://tools/playthrough_v05.gd')
        Invoke-Check 'v051_recorded_input' $GodotPath @('--path', $sandboxProject, '--rendering-method', 'mobile', '--rendering-driver', 'd3d12', '--script', 'res://tools/playthrough_v05.gd', '--', '--playtest')
        Invoke-Check 'v05_feedback_input' $GodotPath @('--path', $sandboxProject, '--rendering-method', 'mobile', '--rendering-driver', 'd3d12', '--script', 'res://tools/playthrough_v05.gd', '--', '--feedback-probe')
    }
} finally {
    $env:APPDATA = $previousAppData
    $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runRoot 'summary.json') -Encoding utf8
    Write-Output "REPORT: $runRoot"
}
if (@($results | Where-Object { -not $_.passed }).Count -gt 0) { exit 1 }
