# 开发环境与启动

## 已完成

- 初始化本地 Git 仓库，默认分支 main；配置 `.gitignore` 与 `.gitattributes`，未创建提交，也未连接远程。
- 从 [Godot 官方 Windows 下载](https://godotengine.org/download/windows/) 获取标准版便携 ZIP，冻结 4.7.2，不修改系统 PATH。
- 编辑器位于 `.tools/godot/4.7.2/`，创建 `_sc_` 标记，编辑器配置与缓存使用便携目录。
- 引擎报告版本为 `4.7.2.stable.official.ed1daf0bf`。
- `game/project.godot` 与 `scenes/main.tscn` 已接入首图游戏、界面、权威战斗逻辑和局域网模块。

下载入口为 `https://downloads.godotengine.org/?flavor=stable&platform=windows.64&slug=win64.exe.zip&version=4.7.2`。本地 ZIP SHA256 为 `731980F9608D61333E5BAF54A2EF17210ACC7A538446C0CB9969F002ACA1E953`，记录用于识别本次文件，未将本地哈希当作上游独立签名校验。

## 启动

在项目根目录使用 PowerShell：

```powershell
./tools/run-godot.ps1 -Editor
./tools/run-godot.ps1 -Check
```

第一条打开编辑器，第二条执行无窗口导入及场景启动。直接游玩双击根目录 `Play.cmd`；验证用 `./tools/test-game.ps1`，打包用 `./tools/build-game.ps1`。完整操作见 `docs/07-playable-prototype.md`。

设计校验工具只依赖 Python 标准库：

```powershell
python tools/check_design.py
```

本次实际执行使用 Codex 提供的 Python 运行时，不要求用户先安装全局 Python。脚本重新生成配置检查报告与前 3 波模型结果；它不会修改游戏数值配置。

## 验证边界

GPU 窗口渲染、本机双进程联机和 PCK 便携启动已经验证。两台电脑、macOS 和标准导出模板尚未验证；当前使用官方编辑器二进制承载 PCK。沙箱内检查可能遇到证书库与用户数据目录访问错误，正常权限运行后无此错误。不能因为退出码为 0 就忽略日志。

便携二进制、构建、缓存和 `.work/` 工作日志被 Git 忽略。计划、配置、游戏源码与测试可纳入版本管理。分享可玩包复制整个 `builds/TwinGuardians/`；分享源码时另行提供或下载同版本 Godot。
