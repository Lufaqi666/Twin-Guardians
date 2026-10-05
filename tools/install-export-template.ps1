$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskTemplateDir = Join-Path $taskRoot '.tools/godot/export-templates/4.7.2'
$taskArchive = Join-Path $taskTemplateDir 'templates.tpz'
$taskReleaseExe = Join-Path $taskTemplateDir 'windows_release_x86_64.exe'
New-Item -ItemType Directory -Path $taskTemplateDir -Force | Out-Null
if (Test-Path -LiteralPath $taskReleaseExe) { Write-Output $taskReleaseExe; exit }
$taskBaseUrl = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/'
$taskChecksumFile = Join-Path $taskTemplateDir 'SHA512-SUMS.txt'
Invoke-WebRequest -Uri ($taskBaseUrl + 'SHA512-SUMS.txt') -OutFile $taskChecksumFile
if (-not (Test-Path -LiteralPath $taskArchive)) {
    & curl.exe --fail --location --retry 2 --max-time 600 --output $taskArchive ($taskBaseUrl + 'Godot_v4.7.2-stable_export_templates.tpz')
    if ($LASTEXITCODE -ne 0) { throw 'Official export template download failed.' }
}
$taskLine = Get-Content -LiteralPath $taskChecksumFile | Where-Object { $_ -match ' Godot_v4.7.2-stable_export_templates.tpz$' }
if (-not $taskLine) { throw 'Official template checksum missing.' }
$taskExpected = ($taskLine -split '\s+')[0]
if ((Get-FileHash -LiteralPath $taskArchive -Algorithm SHA512).Hash -ne $taskExpected) { throw 'Template checksum mismatch.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskZip = [System.IO.Compression.ZipFile]::OpenRead($taskArchive)
try {
    $taskEntry = $taskZip.GetEntry('templates/windows_release_x86_64.exe')
    if ($null -eq $taskEntry) { throw 'Windows release template missing from archive.' }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($taskEntry, $taskReleaseExe, $true)
} finally { $taskZip.Dispose() }
Write-Output $taskReleaseExe
