# installer

两条打包路线，产物都落在 `dist\`。

## 1. 免 Inno Setup 的本地版（推荐，本机可用）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File installer\build-local.ps1 -Version 1.0.0
```

产出 `dist\BatteryBar-Setup-1.0.0.zip`，里面是：

| 文件 | 作用 |
| --- | --- |
| `BatteryBar.exe` | 主程序（取自 `build\msvc\` 或 `build\cmake\Release\`） |
| `headsetcontrol.exe` | 可选，额外的耳机支持（取自 `third_party\` 或上一次安装目录） |
| `install.bat` / `install.ps1` | 安装：复制到 `%LOCALAPPDATA%\Programs\BatteryBar`、建开始菜单快捷方式、登记到"应用和功能" |
| `uninstall.bat` / `uninstall.ps1` | 卸载：结束进程、删文件、删快捷方式和卸载项（个人设置保留在注册表） |
| `README.txt` | 给使用者的说明 |

不需要 Inno Setup，也不需要联网。

## 2. 官方 Inno Setup 版

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File installer\build-inno.ps1 -Version 1.0.0
```

需要：

- **Inno Setup 6**（提供 `ISCC.exe`），常见路径 `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`；
- **能联网**：脚本会下载固定版本的 HeadsetControl 4.3.0 并校验 SHA-256。

产出 `dist\BatteryBar-Setup-1.0.0.exe`（单个安装程序）+ 便携版 zip。安装脚本本体是
`BatteryBar.iss`，`{#Root}`、`{#AppVersion}` 由 `build-inno.ps1` 通过 `/D` 传入。

## 注意

- 所有 `.ps1` 必须保存为 **UTF-8 with BOM**。Windows PowerShell 5.1 在没有 BOM 时按 ANSI 解析，
  中文会变成乱码并报 `Missing closing '}'`。
- 程序未签名，首次运行会有 SmartScreen 提示（更多信息 → 仍要运行）。
- `THIRD_PARTY_NOTICES.txt` 是 HeadsetControl 的许可说明，分发安装包时一起带上。
