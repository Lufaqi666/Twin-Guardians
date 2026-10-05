$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskLogDir = Join-Path $taskRoot '.work/tests'
New-Item -ItemType Directory -Path $taskLogDir -Force | Out-Null
foreach ($taskVariant in @('root','package')) {
    $taskLauncher = if ($taskVariant -eq 'root') { Join-Path $taskRoot 'Play.cmd' } else { Join-Path $taskRoot 'builds/TwinGuardians/Play.cmd' }
    $taskLog = Join-Path $taskLogDir ("launcher-$taskVariant.log")
    if (Test-Path -LiteralPath $taskLog) { Remove-Item -LiteralPath $taskLog }
    & cmd.exe /d /c call $taskLauncher --headless --log-file $taskLog -- --release-audit --silent-preview
    if ($LASTEXITCODE -ne 0) { throw "$taskVariant launcher command failed." }
    $taskDeadline = [DateTime]::UtcNow.AddSeconds(12)
    $taskPassed = $false
    while ([DateTime]::UtcNow -lt $taskDeadline) {
        if (Test-Path -LiteralPath $taskLog) {
            $taskLines = Get-Content -LiteralPath $taskLog
            if ($taskLines | Where-Object { $_ -match 'ERROR:|SCRIPT ERROR:|Parse Error' -and $_ -ne 'ERROR: Failed to read the root certificate store.' }) { throw "$taskVariant launcher reported an error." }
            if ($taskLines -match '^RELEASE_AUDIT PASS ') { $taskPassed = $true; break }
        }
        Start-Sleep -Milliseconds 200
    }
    if (-not $taskPassed) { throw "$taskVariant launcher failed to load the game within 12 seconds." }
    Write-Output "LAUNCHER_PASS $taskVariant"
}
