$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngine = Join-Path $taskRoot '.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$taskLogs = Join-Path $taskRoot '.work\tests'
$taskProject = Join-Path $taskRoot 'game'
$taskHost = Start-Process -FilePath $taskEngine -ArgumentList @('--headless','--path',$taskProject,'--script','res://tests/rating_network_test.gd','--log-file',(Join-Path $taskLogs 'rating-net-host-engine.log'),'--','--host') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskLogs 'rating-net-host.txt') -RedirectStandardError (Join-Path $taskLogs 'rating-net-host-error.txt')
Start-Sleep -Milliseconds 600
$taskClient = Start-Process -FilePath $taskEngine -ArgumentList @('--headless','--path',$taskProject,'--script','res://tests/rating_network_test.gd','--log-file',(Join-Path $taskLogs 'rating-net-client-engine.log'),'--','--client') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskLogs 'rating-net-client.txt') -RedirectStandardError (Join-Path $taskLogs 'rating-net-client-error.txt')
try {
    $taskHost.WaitForExit(28000) | Out-Null
    $taskClient.WaitForExit(28000) | Out-Null
    if (-not $taskHost.HasExited -or -not $taskClient.HasExited) { throw 'Rating network test exceeded deadline.' }
    if ($taskHost.ExitCode -ne 0 -or $taskClient.ExitCode -ne 0) { throw 'Rating network process failed.' }
    foreach ($taskRole in @('host','client')) {
        $taskResult = Get-Content -LiteralPath (Join-Path $taskLogs "rating-net-$taskRole.txt")
        $taskResult | Write-Output
        if (-not ($taskResult -match "RATING_NETWORK_$($taskRole.ToUpper())_PASS")) { throw "Rating network marker missing: $taskRole" }
        foreach ($taskFile in @("rating-net-$taskRole-error.txt", "rating-net-$taskRole-engine.log")) {
            if (Get-Content -LiteralPath (Join-Path $taskLogs $taskFile) | Where-Object { $_ -match 'SCRIPT ERROR|ERROR:|instances were leaked' -and $_ -ne 'ERROR: Failed to read the root certificate store.' }) { throw "Errors in $taskFile" }
        }
    }
} finally {
    if (-not $taskHost.HasExited) { $taskHost.Kill() }
    if (-not $taskClient.HasExited) { $taskClient.Kill() }
}
