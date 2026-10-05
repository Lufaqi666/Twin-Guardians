$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskEngineDir = Join-Path $taskRoot '.tools\godot\4.7.2'
$taskEngine = Join-Path $taskEngineDir 'Godot_v4.7.2-stable_win64_console.exe'
$taskOutput = Join-Path $taskRoot 'builds\TwinGuardians'
New-Item -ItemType Directory -Path $taskOutput -Force | Out-Null
$taskTemplate = Join-Path $taskRoot '.tools/godot/export-templates/4.7.2/windows_release_x86_64.exe'
if (-not (Test-Path -LiteralPath $taskTemplate)) { throw 'Install official release template first: ./tools/install-export-template.ps1' }
& $taskEngine --headless --path (Join-Path $taskRoot 'game') --editor --import --quit --log-file (Join-Path $taskRoot '.work\import-release.log')
if ($LASTEXITCODE -ne 0) { throw 'Release import failed.' }
& $taskEngine --headless --path (Join-Path $taskRoot 'game') --export-release 'Windows Release' (Join-Path $taskOutput 'TwinGuardians.exe') --log-file (Join-Path $taskRoot '.work\build.log')
if ($LASTEXITCODE -ne 0) { throw 'Release export failed.' }
if (Test-Path -LiteralPath (Join-Path $taskRoot 'third_party\godot')) {
    New-Item -ItemType Directory -Path (Join-Path $taskOutput 'licenses') -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $taskRoot 'third_party\godot') -File | Copy-Item -Destination (Join-Path $taskOutput 'licenses') -Force
}
@'
@echo off
cd /d "%~dp0"
if not exist "%~dp0TwinGuardians.exe" goto missing
if not exist "%~dp0TwinGuardians.pck" goto missing
start "" "%~dp0TwinGuardians.exe" %*
exit /b
:missing
echo Game files are missing. Extract the full game folder, then try again.
pause
'@ | Set-Content -LiteralPath (Join-Path $taskOutput 'Play.cmd') -Encoding ascii
@'
Twin Guardians v0.10

Double-click Play.cmd or TwinGuardians.exe to play.
Official Windows x86_64 release export; editor binary is not included.
Three stage-based tutorials, remappable tower skills (1/2) and ready tower cycling (C).
Settings include low/medium/high effects. Enemy danger warnings remain visible.
Optional local playtest logs and manual feedback export never upload data.
Ten stages, four base towers, eight tier-3 routes, sixteen branches and six heroes.
All six heroes now share fantasy chibi portraits and battlefield artwork.
New stages: Moonbrook, Sunken Temple, Glacier Keep and Eclipse Gate.
Fair Challenge is recommended by default (level 4, skill rank 3, no XP writes).
Growth Campaign remains available and preserves old hero progress.
Victory rating: 0-2 crystal HP lost = 3 stars; 3-10 = 2; 11-19 = 1.
Every clear earns at least 1 star. Failures earn none. Maximum is 3.
Results display for 3 seconds, then automatically return to the main menu.
Campaign flags show each stage's best rating. Lower clears never reduce it.
Stars save in both Growth and Challenge; Challenge still does not write XP.

Click a node or tower for a nearby menu. Hover choices to preview range.
Expand Details to read stats and specializations. Escape/close dismisses it.
Build, upgrade, targeting, rally points and confirmed sale use that menu.
New towers: Ballista (long-range armor penetration), Storm (chain attacks),
Beacon (nonstacking healing and partner tower support).
Only Archer, Barracks, Mage and Cannon can be built at empty nodes.
Upgrade to level 2, then level 3. Once construction completes, choose a route:
Archer -> Ranger or Ballista; Barracks -> Paladin or Beacon;
Mage -> Frost or Storm; Cannon -> Heavy Cannon or Alchemy.
Each route offers two committed ability branches. Conversion takes 2 seconds.
Branch prices show extra investment; sale includes the full investment.
Converting Barracks to Beacon withdraws its soldiers.
Each final tower has two purchasable active skills, each with two ranks.
Skill ranks cost 70 then 100 gold. Learn and cast beside the selected tower.
Owners can authorize partners to upgrade, cast, target and rally.
Partners spend their own gold. Only owners can sell or revoke permission.
Sale refunds include all investments and go to the owner.
Thornwood: change incoming roads. Moonbrook: stay near the escort cart.
Glacier Keep: temporary foundation locks; approach the crystal to unseal.
Saboteurs jam towers after a warning. Splitters spawn two infantry on death.
Rift Lord: different players attack within 3 seconds to open its seal.
Watch its fixed-position pulse warning and move out before impact.
Targeting: exit, highest HP, air, fastest or armored priority.

WASD/right-click: move. Q: hero skill. U: upgrade skill. R: team resonance.
Space: ready. Tab: switch local player. F: hold to rescue. G: map ping.
Choose Support or Assault hero specialization during preparation.
Your skill leaves a 4-second weakness: a partner skill can trigger a relay.
Events warn for 6 seconds; hold two separate beacons for 3 seconds to solve.
Snow, embers, thorns, wind and rift reinforcements change the battlefield.
New events add tides, quicksand, crystal shields and periodic starfall.
Wardens have shields; Menders heal nearby enemies.
Tactical Tools expands diversion, flame traps and gold aid.
Settings retain volume, rebinding, shake, damage numbers and tutorial.

Host first, then copy a TG room code for your partner. Joining accepts codes
and IP:port. Default UDP port: 24820; LAN discovery: 24821.
Same build required. Codes simplify addresses; they do not provide a relay
or NAT traversal. Works on LAN or directly reachable endpoints.
Original clients automatically retry reconnecting for up to 60 seconds.

1066 rule/UI/content checks passed for v0.10.
60 economic playthroughs previously passed on v0.9; economy rules are unchanged.
308 tower-menu GPU checks and 14 release-interface GPU checks passed.
Both growth and challenge localhost networking, manual reconnection,
room-code joining and automatic reconnection were checked.
Reliable final results, both local star saves and auto lobby return passed.
Physical two-PC LAN, human balance, packet loss and macOS are unverified.
See docs/16-v10-release-preparation.md for the full update.

Runtime: official Godot 4.7.2 Windows release template, verified using the
official SHA512 checksum. Art is original procedural vector art.
Godot and third-party licenses are in licenses/.

'@ | Set-Content -LiteralPath (Join-Path $taskOutput 'README.txt') -Encoding utf8
$taskManifest = @{}
Get-ChildItem -LiteralPath $taskOutput -Recurse -File | Where-Object { $_.Name -ne 'SHA256.json' } | ForEach-Object {
    $taskRelative = [System.IO.Path]::GetRelativePath($taskOutput, $_.FullName)
    $taskManifest[$taskRelative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
}
$taskManifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskOutput 'SHA256.json') -Encoding utf8
Write-Output $taskOutput
