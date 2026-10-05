$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskSource = Join-Path $taskRoot 'builds/TwinGuardians'
$taskStageRoot = Join-Path $taskRoot ('.work/lan-package-' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss'))
$taskStage = Join-Path $taskStageRoot 'TwinGuardians'
$taskZip = Join-Path $taskRoot 'builds/TwinGuardians-v0.10-Windows-LAN.zip'
New-Item -ItemType Directory -Path $taskStage -Force | Out-Null
foreach ($taskName in @('TwinGuardians.exe','TwinGuardians.pck','Play.cmd','README.txt')) {
    $taskFile = Join-Path $taskSource $taskName
    if (-not (Test-Path -LiteralPath $taskFile)) { throw "Required game file missing: $taskName" }
    Copy-Item -LiteralPath $taskFile -Destination (Join-Path $taskStage $taskName)
}
New-Item -ItemType Directory -Path (Join-Path $taskStage 'licenses') -Force | Out-Null
foreach ($taskName in @('GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt')) {
    Copy-Item -LiteralPath (Join-Path $taskSource "licenses/$taskName") -Destination (Join-Path $taskStage "licenses/$taskName")
}
@'
双子守护者 v0.10 · Windows 64位 · 局域网联机包

启动：
1. 把 ZIP 完整解压到一个文件夹，不能直接在压缩包里运行。
2. 打开 TwinGuardians 文件夹，双击 Play.cmd。
3. TwinGuardians.exe 和 TwinGuardians.pck 必须放在同一文件夹。
无需安装 Godot，不包含开发工具、测试脚本或房主的个人存档。

局域网联机：
1. 两台电脑连接同一个路由器 / Wi-Fi，并使用同一份游戏包。
2. 房主选择关卡与 P1 英雄，点击“邀请队友 / 加入房间”→“创建所选关卡房间”。
3. 房主点击“复制房间码”，把房间码发给队友。
4. 队友选择 P2 英雄，在邀请面板粘贴房间码，点击“加入 / 原席位重连”。
   也可以点击“搜索附近房间并加入”。
5. 连接成功后，双方部署并点击“准备下一波”。

连接失败：
- Windows 防火墙提示时，允许游戏访问专用网络，无需关闭防火墙。
- 避免访客 Wi-Fi，它可能隔离同一网络上的设备。
- 房主运行 ipconfig，找到当前 Wi-Fi / 以太网的 IPv4 地址。
  队友可直接输入，例如 192.168.1.100:24820。不要输入 127.0.0.1。
- VPN 或虚拟网卡可能让房间码选错地址，这时使用上面的真实 IPv4。
- 联机端口 UDP 24820；附近房间发现端口 UDP 24821。
- 当前没有公网中继，不保证不同网络直接连接。

操作：
右键 / WASD 移动英雄，Q 英雄技能，R 共鸣，F 救援，Space 准备。
选中高级塔后，1 / 2 施放塔技能，C 跳到技能就绪的可操作塔。
快捷键可以在设置中修改；本机练习用 Tab 切换玩家。

说明：
这是发布准备与试玩版本，真人平衡、物理双机和低端设备仍需验证。
存档与设置在各自电脑本地保存；试玩反馈不会自动上传。
SHA256.json 是文件校验清单，licenses 文件夹包含引擎许可。
'@ | Set-Content -LiteralPath (Join-Path $taskStage '开始游戏与联机说明.txt') -Encoding utf8
$taskManifest = @{}
Get-ChildItem -LiteralPath $taskStage -Recurse -File | ForEach-Object {
    $taskManifest[[System.IO.Path]::GetRelativePath($taskStage, $_.FullName)] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
}
$taskManifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskStage 'SHA256.json') -Encoding utf8
Compress-Archive -LiteralPath $taskStage -DestinationPath $taskZip -CompressionLevel Optimal -Force
# Verify the archive after extraction; filenames and hashes must match the staged set.
$taskVerifyRoot = Join-Path $taskStageRoot 'verified'
Expand-Archive -LiteralPath $taskZip -DestinationPath $taskVerifyRoot
$taskVerified = Join-Path $taskVerifyRoot 'TwinGuardians'
$taskFiles = @(Get-ChildItem -LiteralPath $taskVerified -Recurse -File)
if ($taskFiles.Count -ne ($taskManifest.Count + 1)) { throw 'ZIP file count mismatch.' }
foreach ($taskName in $taskManifest.Keys) {
    if ((Get-FileHash -LiteralPath (Join-Path $taskVerified $taskName) -Algorithm SHA256).Hash -ne $taskManifest[$taskName]) { throw "ZIP checksum mismatch: $taskName" }
}
$taskAuditLog = Join-Path $taskStageRoot 'package-audit.log'
$taskAudit = Start-Process -FilePath (Join-Path $taskVerified 'TwinGuardians.exe') -ArgumentList @('--headless','--log-file',$taskAuditLog,'--','--release-audit','--silent-preview') -WorkingDirectory $taskVerified -WindowStyle Hidden -PassThru -Wait
if ($taskAudit.ExitCode -ne 0 -or -not (Select-String -LiteralPath $taskAuditLog -Pattern '^RELEASE_AUDIT PASS ')) { throw 'Extracted game failed startup audit.' }
if (Get-Content -LiteralPath $taskAuditLog | Where-Object { $_ -match 'ERROR:|SCRIPT ERROR:|Parse Error' -and $_ -ne 'ERROR: Failed to read the root certificate store.' }) { throw 'Extracted game reported unexpected errors.' }
(Get-FileHash -LiteralPath $taskZip -Algorithm SHA256).Hash | Set-Content -LiteralPath ($taskZip + '.sha256.txt') -Encoding ascii
Get-Item -LiteralPath $taskZip | Select-Object FullName,Length
Write-Output 'LAN_PACKAGE_PASS: exact file list, extracted checksums and release startup audit.'
