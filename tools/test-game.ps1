$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngine = Join-Path $taskRoot '.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
$taskProject = Join-Path $taskRoot 'game'
$taskLogs = Join-Path $taskRoot '.work\tests'
New-Item -ItemType Directory -Path $taskLogs -Force | Out-Null
& $taskEngine --headless --path $taskProject --script res://tests/core_test.gd --log-file (Join-Path $taskLogs 'core.log')
if ($LASTEXITCODE -ne 0) { throw 'Core tests failed.' }
& $taskEngine --headless --path $taskProject --script res://tests/ui_test.gd --log-file (Join-Path $taskLogs 'ui.log')
if ($LASTEXITCODE -ne 0) { throw 'UI tests failed.' }
& $taskEngine --headless --path $taskProject --script res://tests/content_test.gd --log-file (Join-Path $taskLogs 'content.log')
if ($LASTEXITCODE -ne 0) { throw 'Content tests failed.' }
& $taskEngine --headless --path $taskProject --script res://tests/hero_test.gd --log-file (Join-Path $taskLogs 'hero.log')
if ($LASTEXITCODE -ne 0) { throw 'Hero tests failed.' }
& $taskEngine --headless --path $taskProject --script res://tests/improvements_test.gd --log-file (Join-Path $taskLogs 'improvements.log')
if ($LASTEXITCODE -ne 0) { throw 'Improvement tests failed.' }
& $taskEngine --headless --path $taskProject --script res://tests/strategy_test.gd --log-file (Join-Path $taskLogs 'strategy.log')
if ($LASTEXITCODE -ne 0) { throw 'Strategy tests failed.' }
& $taskEngine --headless --path $taskProject --script res://tests/rating_test.gd --log-file (Join-Path $taskLogs 'rating.log')
if ($LASTEXITCODE -ne 0) { throw 'Rating tests failed.' }
& $taskEngine --headless --path $taskProject --script res://tests/expansion_test.gd --log-file (Join-Path $taskLogs 'expansion.log')
if ($LASTEXITCODE -ne 0) { throw 'Expansion tests failed.' }
& $taskEngine --headless --path $taskProject --script res://tests/release_test.gd --log-file (Join-Path $taskLogs 'release.log')
if ($LASTEXITCODE -ne 0) { throw 'Release preparation tests failed.' }
$taskHostOut = Join-Path $taskLogs 'host.log'
$taskClientOut = Join-Path $taskLogs 'client.log'
$taskHostErr = Join-Path $taskLogs 'host-error.log'
$taskClientErr = Join-Path $taskLogs 'client-error.log'
foreach ($taskVariant in @('growth','challenge')) {
    $taskHost = Start-Process -FilePath $taskEngine -ArgumentList @('--headless','--path',$taskProject,'--script','res://tests/network_test.gd','--log-file',(Join-Path $taskLogs 'network-host-engine.log'),'--','--host',"--$taskVariant") -WindowStyle Hidden -PassThru -RedirectStandardOutput $taskHostOut -RedirectStandardError $taskHostErr
    Start-Sleep -Milliseconds 600
    $taskClient = Start-Process -FilePath $taskEngine -ArgumentList @('--headless','--path',$taskProject,'--script','res://tests/network_test.gd','--log-file',(Join-Path $taskLogs 'network-client-engine.log'),'--','--client',"--$taskVariant") -WindowStyle Hidden -PassThru -RedirectStandardOutput $taskClientOut -RedirectStandardError $taskClientErr
    $taskHost.WaitForExit(25000) | Out-Null
    $taskClient.WaitForExit(25000) | Out-Null
    if (-not $taskHost.HasExited -or -not $taskClient.HasExited) {
        if (-not $taskHost.HasExited) { $taskHost.Kill() }
        if (-not $taskClient.HasExited) { $taskClient.Kill() }
        throw 'Network test process exceeded deadline.'
    }
    Get-Content -LiteralPath $taskHostOut
    Get-Content -LiteralPath $taskClientOut
    Get-Content -LiteralPath $taskHostErr
    Get-Content -LiteralPath $taskClientErr
    if ($taskHost.ExitCode -ne 0 -or $taskClient.ExitCode -ne 0) { throw 'Network tests failed.' }
    if (-not (Select-String -LiteralPath $taskHostOut -Pattern 'NETWORK_HOST_PASS') -or -not (Select-String -LiteralPath $taskClientOut -Pattern 'NETWORK_CLIENT_PASS')) { throw 'Network success markers missing.' }
    foreach ($taskNetworkLog in @('host.log','client.log','host-error.log','client-error.log','network-host-engine.log','network-client-engine.log')) {
        if (Get-Content -LiteralPath (Join-Path $taskLogs $taskNetworkLog) | Where-Object { $_ -match 'SCRIPT ERROR|ERROR:|instances were leaked' -and $_ -ne 'ERROR: Failed to read the root certificate store.' }) { throw "Network errors in $taskNetworkLog ($taskVariant)" }
    }
}
foreach ($taskLog in @('core.log','ui.log','content.log','hero.log','improvements.log','strategy.log','rating.log','expansion.log','release.log','host.log','client.log','host-error.log','client-error.log')) {
    if (Get-Content -LiteralPath (Join-Path $taskLogs $taskLog) | Where-Object { $_ -match 'SCRIPT ERROR|ERROR:|instances were leaked' -and $_ -ne 'ERROR: Failed to read the root certificate store.' }) { throw "Errors in $taskLog" }
}
foreach ($taskLevel in @('confluence_courtyard','frost_pass','ember_ruins','thornwood','skywatch','rift_citadel','moonbrook','sunken_temple','glacier_keep','eclipse_gate')) {
    foreach ($taskMode in @('fresh','max-level','challenge')) {
        $taskLogPath = Join-Path $taskLogs ("playthrough-$taskLevel-$taskMode.log")
        & $taskEngine --headless --path $taskProject --script res://tests/playthrough.gd --log-file $taskLogPath -- "--level=$taskLevel" "--$taskMode"
        if ($LASTEXITCODE -ne 0) { throw "Playthrough failed: $taskLevel $taskMode" }
        if (Get-Content -LiteralPath $taskLogPath | Where-Object { $_ -match 'SCRIPT ERROR|ERROR:|instances were leaked' -and $_ -ne 'ERROR: Failed to read the root certificate store.' }) { throw "Errors in $taskLogPath" }
    }
}
& (Join-Path $PSScriptRoot 'test-auto-network.ps1')
& (Join-Path $PSScriptRoot 'test-rating-network.ps1')
& (Join-Path $PSScriptRoot 'test-formations.ps1')
Write-Output 'GAME_TESTS_PASSED'
