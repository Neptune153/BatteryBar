# BatteryBar 打包教程

这个目录负责把 `build\BatteryBar.exe` 变成安装包。有两种方式，**二选一**：

| 方式 | 脚本 | 产物 |
| --- | --- | --- |
| 标准 Windows 安装向导 | `build-inno.ps1` | `dist\BatteryBar-Setup-<版本>.exe` |
| 压缩包安装版| `build-local.ps1` | `dist\BatteryBar-Setup-<版本>.zip` |


---

## 第 0 步：先构建主程序

打包脚本不会替你编译。先在仓库根目录构建：

```powershell
cd 安装目录
make
```

构建完成后确认产物存在，并且能正常列出设备：

```powershell
build\BatteryBar.exe --list
```
---

## 方式 1：生成压缩包安装版

不生成 `.exe` 安装程序，而是生成一个 zip，解压后双击 `install.bat` 安装。

### 执行打包

在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File packaging\build-local.ps1 
```

### 检查产物

```powershell
Get-ChildItem dist
```

应该看到：

```text
dist\BatteryBar-Setup-<版本>.zip
```

zip 里的  `BatteryBar.exe`  即为主程序

---


## 方式 2：生成标准安装包

适合正式发给用户：有安装向导、开始菜单快捷方式、卸载项和可选的开机自启。

###  安装 Inno Setup

安装 **Inno Setup 6 或 7**：<https://jrsoftware.org/isdl.php>

装完后 `ISCC.exe` 通常在这些位置之一，脚本会自动查找：

```text
C:\Program Files (x86)\Inno Setup 6\ISCC.exe
C:\Program Files\Inno Setup 7\ISCC.exe
```

如果脚本提示 `Inno Setup not found`，先确认安装的是 6 或 7，再重新打开 PowerShell。

### 执行打包

在仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File packaging\build-inno.ps1
```


脚本会依次做这些事：

1. 检查 `third_party\headsetcontrol\headsetcontrol.exe`；没有就下载 HeadsetControl 4.3.0，并校验 SHA-256。**这一步需要联网。**
2. 检查 `build\BatteryBar.exe` 是否存在。
3. 找到 `ISCC.exe`，把版本号通过 `/DAppVersion=...` 传给 [BatteryBar.iss](BatteryBar.iss)。
4. 在 `dist\` 生成安装包。

###  检查产物

```powershell
Get-ChildItem dist
```

应该看到：

```text
dist\BatteryBar-Setup-1.0.1.exe
```

双击安装包，按向导走一遍。安装程序的行为：

- **默认按当前用户安装**：装到 `%LOCALAPPDATA%\Programs\BatteryBar`，不需要管理员权限。
- 安装向导里有目录页，可以改路径；如果当前账户对目标目录没有写权限，安装程序会拦下并提示换目录。
- 也支持“为所有用户安装”，这时需要管理员权限，默认目录会变成 `Program Files`。
- 创建开始菜单快捷方式，登记到“应用和功能”，并提供卸载项。
- 安装向导里的“开机启动”任务默认勾选；安装完成后会自动启动 BatteryBar。
- 升级安装时，会先让正在运行的旧版本退出，再覆盖文件。

> 安装包没有代码签名，首次运行会触发 SmartScreen“未知发布者”。点“更多信息 → 仍要运行”即可。

---
