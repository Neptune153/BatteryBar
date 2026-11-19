# installer

安装包的两个生成入口，产物输出到 `dist/`。

## build-local.ps1

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File installer\build-local.ps1 -Version 1.0.0
```

输出 `dist\BatteryBar-Setup-<版本>.zip`。不依赖 Inno Setup，也不需要网络访问。

| 包内文件 | 说明 |
| --- | --- |
| `BatteryBar.exe` | 主程序，取自 `build\`（`build.bat` 或 `make` 的产物） |
| `headsetcontrol.exe` | 可选，额外的耳机支持，取自 `third_party\` 或既有安装目录 |
| `install.bat` / `install.ps1` | 安装 |
| `uninstall.bat` / `uninstall.ps1` | 卸载 |
| `README.txt` | 使用者说明 |

安装行为：复制到 `%LOCALAPPDATA%\Programs\BatteryBar`，创建开始菜单快捷方式，写入
`HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\BatteryBar`。卸载保留用户设置。

## build-inno.ps1

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File installer\build-inno.ps1 -Version 1.0.0
```

依赖 Inno Setup 6（`ISCC.exe`）与网络访问：脚本下载 HeadsetControl 4.3.0 并校验 SHA-256。
输出 `dist\BatteryBar-Setup-<版本>.exe` 与便携版 zip。安装脚本为 `BatteryBar.iss`，
`Root` 与 `AppVersion` 由该脚本通过 `/D` 传入。

## 约束

- 所有 `.ps1` 保存为 UTF-8 with BOM。Windows PowerShell 5.1 在无 BOM 时按 ANSI 解析，中文会导致
  语法错误（`Missing closing '}'`）。
- 程序未签名，首次运行触发 SmartScreen 提示。
- 分发安装包时同时提供 `THIRD_PARTY_NOTICES.txt`。
