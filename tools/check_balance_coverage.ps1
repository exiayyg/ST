param(
    [string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent),
    [switch]$Report
)
$ErrorActionPreference = 'Stop'
$exemptFiles = @{
    'scripts/config/presentation_schema.gd' = 'Versioned migration defaults and field metadata; runtime consumers only receive validated JSON values.'
    'scripts/config/balance_schema.gd' = 'Historical migration defaults and schema validation bounds, not live gameplay defaults.'
    'scripts/config/balance_field_catalog.gd' = 'Field editor bounds, integer/type metadata, and validation limits.'
}
$findings = [System.Collections.Generic.List[object]]::new()
$paths = Get-ChildItem (Join-Path $ProjectRoot 'scripts') -Recurse -File -Filter '*.gd'
foreach ($file in $paths) {
    $relative = [IO.Path]::GetRelativePath($ProjectRoot, $file.FullName).Replace('\', '/')
    if ($exemptFiles.ContainsKey($relative)) { continue }
    $lineNumber = 0
    foreach ($line in [IO.File]::ReadAllLines($file.FullName)) {
        $lineNumber++
        # Strip strings before comments; numbers in names, text and paths aren't tuning literals.
        $code = [regex]::Replace($line, '"(?:\\.|[^"\\])*"|''(?:\\.|[^''\\])*''', '""')
        $code = ($code -split '#', 2)[0].Trim()
        $numbers = @([regex]::Matches($code, '(?<![\w])\d+(?:\.\d+)?(?:[eE][+-]?\d+)?(?![\w])') | Where-Object { [double]::Parse($_.Value, [Globalization.CultureInfo]::InvariantCulture) -notin @(0, 1) })
        if ($numbers.Count -gt 0) {
            $findings.Add([ordered]@{ path=$relative; code=$code; line=$lineNumber })
        }
    }
}
if ($Report) { $findings | ConvertTo-Json -Depth 4; exit 0 }
$manifest = Get-Content (Join-Path $ProjectRoot 'config/balance/numeric_literal_allowlist.json') -Raw | ConvertFrom-Json
$unknown = @($findings | Where-Object {
    $entry = $_
    -not @($manifest.entries | Where-Object { $_.path -ceq $entry.path -and $_.code -ceq $entry.code -and $_.reason }).Count
})
if ($unknown.Count -gt 0) {
    $unknown | Format-Table -Wrap | Out-String | Write-Output
    throw 'New numeric literals need Balance schema registration or a specific reviewed exemption.'
}
Write-Output "Numeric coverage passed: $($findings.Count) reviewed literals; schema/control/runtime-field coverage runs in Godot."
