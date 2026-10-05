param([switch]$Editor, [switch]$Check)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngine = Join-Path $taskRoot '.tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $taskEngine)) {
    throw 'Portable Godot is missing. See docs/06-environment.md.'
}
$taskProject = Join-Path $taskRoot 'game'
if ($Check) {
    & $taskEngine --headless --path $taskProject --editor --quit
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $taskEngine --headless --path $taskProject --quit-after 5
    exit $LASTEXITCODE
}
if ($Editor) {
    Start-Process -FilePath $taskEngine -ArgumentList @('--path', $taskProject, '--editor') -WindowStyle Hidden
} else {
    Start-Process -FilePath $taskEngine -ArgumentList @('--path', $taskProject) -WindowStyle Hidden
}
