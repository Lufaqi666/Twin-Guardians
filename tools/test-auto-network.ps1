$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngine = Join-Path $taskRoot '.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$taskLogs = Join-Path $taskRoot '.work\tests'
$taskProject = Join-Path $taskRoot 'game'
$taskHost = Start-Process -FilePath $taskEngine -ArgumentList @('--headless','--path',$taskProject,'--script','res://tests/auto_network_test.gd','--log-file',(Join-Path $taskLogs 'auto-host-engine.log'),'--','--host') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskLogs 'auto-host.txt') -RedirectStandardError (Join-Path $taskLogs 'auto-host-error.txt')
Start-Sleep -Milliseconds 600
$taskClient = Start-Process -FilePath $taskEngine -ArgumentList @('--headless','--path',$taskProject,'--script','res://tests/auto_network_test.gd','--log-file',(Join-Path $taskLogs 'auto-client-engine.log'),'--','--client') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskLogs 'auto-client.txt') -RedirectStandardError (Join-Path $taskLogs 'auto-client-error.txt')
try {
    $taskHost.WaitForExit(28000) | Out-Null
    $taskClient.WaitForExit(28000) | Out-Null
    if (-not $taskHost.HasExited -or -not $taskClient.HasExited) { throw 'Automatic reconnect test exceeded deadline.' }
    if ($taskHost.ExitCode -ne 0 -or $taskClient.ExitCode -ne 0) { throw 'Automatic reconnect process failed.' }
    foreach ($taskRole in @('host','client')) {
        $taskResult = Get-Content -LiteralPath (Join-Path $taskLogs "auto-$taskRole.txt")
        $taskResult | Write-Output
        if (-not ($taskResult -match "AUTO_NETWORK_$($taskRole.ToUpper())_PASS")) { throw "Automatic reconnect marker missing: $taskRole" }
        foreach ($taskFile in @("auto-$taskRole-error.txt", "auto-$taskRole-engine.log")) {
            if (Get-Content -LiteralPath (Join-Path $taskLogs $taskFile) | Where-Object { $_ -match 'SCRIPT ERROR|ERROR:|instances were leaked' -and $_ -ne 'ERROR: Failed to read the root certificate store.' }) { throw "Errors in $taskFile" }
        }
    }
} finally {
    if (-not $taskHost.HasExited) { $taskHost.Kill() }
    if (-not $taskClient.HasExited) { $taskClient.Kill() }
}
