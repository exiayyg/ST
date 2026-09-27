param([string]$GodotPath, [string]$ProjectPath)
$ErrorActionPreference = 'Stop'
# APPDATA is already isolated by run_validation.ps1. All children inherit it.
$probeRoot = Join-Path $env:APPDATA 'process-probe'
New-Item -ItemType Directory -Path $probeRoot -Force | Out-Null
function Start-Probe([string]$Name, [string[]]$Options) {
    $arguments = @('--headless', '--path', $ProjectPath, '--script', 'res://tools/playtest_process_probe.gd', '--') + $Options
    $quoted = @($arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' })
    $out = Join-Path $probeRoot ($Name + '.out.log')
    $err = Join-Path $probeRoot ($Name + '.err.log')
    $process = Start-Process -FilePath $GodotPath -ArgumentList $quoted -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
    return @{ Process=$process; Out=$out; Err=$err }
}
function Finish-Probe($Probe) {
    if (-not $Probe.Process.WaitForExit(30000)) {
        $Probe.Process.Kill($true)
        $Probe.Process.WaitForExit()
        throw 'Process probe timed out'
    }
    $Probe.Process.Refresh()
    $log = (Get-Content $Probe.Out, $Probe.Err -Raw) -join "`n"
    if ($Probe.Process.ExitCode -ne 0 -or $log -match 'SCRIPT ERROR:|ERROR:|Parse Error:') { throw $log }
    return $log
}
$normal = Start-Probe 'normal' @()
$log = Finish-Probe $normal
$match = [regex]::Match($log, 'PLAYTEST_DIRECTORY=([^\r\n]+)')
if (-not $match.Success) { throw 'No report directory marker' }
$reportRoot = $match.Groups[1].Value.Trim()
$normalReport = @(Get-ChildItem -LiteralPath $reportRoot -Directory)[0]
$normalSummary = Get-Content (Join-Path $normalReport.FullName 'summary.json') -Raw | ConvertFrom-Json
if (-not $normalSummary.finished -or $normalSummary.reason -ne 'normal_close') { throw 'Normal process shutdown failed to finish exactly once' }
$abrupt = Start-Probe 'abrupt' @('--abrupt')
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ((Get-Content $abrupt.Out -Raw -ErrorAction SilentlyContinue) -match 'PLAYTEST_PROCESS_READY') { break }
        if ($abrupt.Process.HasExited) { throw 'Abrupt probe exited before readiness' }
        Start-Sleep -Milliseconds 50
    }
    if ((Get-Content $abrupt.Out -Raw) -notmatch 'PLAYTEST_PROCESS_READY') { throw 'Abrupt probe never became ready' }
    # Kill only this explicitly-created isolated test child, simulating an OS crash.
    $abrupt.Process.Kill($true)
    $abrupt.Process.WaitForExit()
} finally {
    if (-not $abrupt.Process.HasExited) { $abrupt.Process.Kill($true); $abrupt.Process.WaitForExit() }
}
$abruptReport = @(Get-ChildItem -LiteralPath $reportRoot -Directory | Where-Object Name -ne $normalReport.Name)[0]
$summaryPath = Join-Path $abruptReport.FullName 'summary.json'
if ((Get-Content $summaryPath -Raw | ConvertFrom-Json).finished) { throw 'Killed process falsely reported a normal end' }
$journalPath = Join-Path $abruptReport.FullName 'events.jsonl'
$journalHash = (Get-FileHash -LiteralPath $journalPath).Hash
$recovery = Start-Probe 'recovery' @('--recover-only')
Finish-Probe $recovery | Out-Null
$recovered = Get-Content $summaryPath -Raw | ConvertFrom-Json
if (-not $recovered.finished -or $recovered.reason -ne 'interrupted') { throw 'Next startup did not recover abandoned report' }
if ((Get-FileHash -LiteralPath $journalPath).Hash -ne $journalHash) { throw 'Recovery altered original journal' }
if (@(Get-ChildItem -LiteralPath $reportRoot -Directory).Count -ne 2) { throw 'Recovery without consent created a new run' }
Write-Output 'Playtest real process lifecycle passed: normal close, forced crash, next-start recovery, journal preservation.'
