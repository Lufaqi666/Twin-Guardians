param([string[]]$Formations = @('ranged','arcane','skills'))
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngine = Join-Path $taskRoot '.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$taskProject = Join-Path $taskRoot 'game'
$taskLogs = Join-Path $taskRoot '.work\tests'
foreach ($taskFormation in $Formations) {
    foreach ($taskLevel in @('confluence_courtyard','frost_pass','ember_ruins','thornwood','skywatch','rift_citadel','moonbrook','sunken_temple','glacier_keep','eclipse_gate')) {
        $taskLog = Join-Path $taskLogs "formation-$taskFormation-$taskLevel.log"
        & $taskEngine --headless --path $taskProject --script res://tests/playthrough.gd --log-file $taskLog -- "--level=$taskLevel" '--challenge' "--formation=$taskFormation"
        if ($LASTEXITCODE -ne 0) { throw "Formation failed: $taskFormation $taskLevel" }
        if (Get-Content -LiteralPath $taskLog | Where-Object { $_ -match 'SCRIPT ERROR|ERROR:|instances were leaked' -and $_ -ne 'ERROR: Failed to read the root certificate store.' }) { throw "Errors in $taskLog" }
    }
}
Write-Output 'FORMATION_TESTS_PASSED'
