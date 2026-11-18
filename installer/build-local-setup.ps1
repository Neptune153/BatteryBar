# 生成可以直接双击安装的压缩包（不需要 Inno Setup、不需要联网）。
# 用法：powershell -NoProfile -File installer\build-local-setup.ps1 [-Version 1.0.0]
# 产物：dist\WirelessBattery-Setup-<版本>.zip
param([string]$Version = '1.0.0')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'build\msvc\WirelessBattery.exe'
if (-not (Test-Path $exe)) { throw "还没有编译好的程序，先运行 temp\rebuild.bat" }

$stage = Join-Path $root 'temp\stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item $exe (Join-Path $stage 'WirelessBattery.exe')

# 官方安装包里带的 headsetcontrol.exe（额外耳机支持）如果本机有，就一起打进去
$hsc = Join-Path $root 'third_party\headsetcontrol\headsetcontrol.exe'
if (-not (Test-Path $hsc)) { $hsc = 'D:\a_downloads\software\Wireless Battery\headsetcontrol.exe' }
if (Test-Path $hsc) {
    Copy-Item $hsc (Join-Path $stage 'headsetcontrol.exe')
    Write-Host '已带上 headsetcontrol.exe'
} else {
    Write-Host '没有找到 headsetcontrol.exe，安装包只带主程序'
}

$install = @'
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = Join-Path $env:LOCALAPPDATA 'Programs\Wireless Battery'

Write-Host "安装到 $dest"
Get-Process WirelessBattery -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item (Join-Path $here 'WirelessBattery.exe') -Destination $dest -Force
foreach ($f in @('headsetcontrol.exe', 'uninstall.ps1', 'uninstall.bat')) {
    $s = Join-Path $here $f
    if (Test-Path $s) { Copy-Item $s -Destination $dest -Force }
}

$ws = New-Object -ComObject WScript.Shell
$lnkPath = Join-Path ([Environment]::GetFolderPath('Programs')) 'Wireless Battery.lnk'
$lnk = $ws.CreateShortcut($lnkPath)
$lnk.TargetPath = Join-Path $dest 'WirelessBattery.exe'
$lnk.WorkingDirectory = $dest
$lnk.Description = 'Wireless Battery'
$lnk.Save()

$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\WirelessBattery'
New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name DisplayName -Value 'Wireless Battery'
Set-ItemProperty -Path $key -Name DisplayVersion -Value '__VERSION__'
Set-ItemProperty -Path $key -Name Publisher -Value '个人构建，基于 krisgfx9/Wireless-Device-Battery-Monitor'
Set-ItemProperty -Path $key -Name DisplayIcon -Value (Join-Path $dest 'WirelessBattery.exe')
Set-ItemProperty -Path $key -Name InstallLocation -Value $dest
Set-ItemProperty -Path $key -Name UninstallString -Value ('powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $dest 'uninstall.ps1') + '"')
New-ItemProperty -Path $key -Name NoModify -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $key -Name NoRepair -Value 1 -PropertyType DWord -Force | Out-Null

Start-Process (Join-Path $dest 'WirelessBattery.exe')
Write-Host ''
Write-Host '安装完成：任务栏右侧应该出现电量组件，开始菜单里也有快捷方式。'
Write-Host '如果弹出 SmartScreen（未知发布者），点“更多信息 / 仍要运行”即可。'
'@
$install = $install.Replace('__VERSION__', $Version)
# 带 BOM 写出，Windows PowerShell 5.1 才会按 UTF-8 读中文
$utf8bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText((Join-Path $stage 'install.ps1'), $install, $utf8bom)

$uninstall = @'
$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:LOCALAPPDATA 'Programs\Wireless Battery'

Write-Host '关闭程序并删除文件...'
Get-Process WirelessBattery -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$lnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'Wireless Battery.lnk'
if (Test-Path $lnk) { Remove-Item $lnk -Force }

Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\WirelessBattery' -Recurse -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WirelessBattery' -ErrorAction SilentlyContinue

if (Test-Path $dest) {
    Start-Sleep -Milliseconds 400
    Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host '已卸载。个人设置仍保留在 HKCU\Software\WirelessBattery，需要彻底清掉可以手动删除。'
'@
[System.IO.File]::WriteAllText((Join-Path $stage 'uninstall.ps1'), $uninstall, $utf8bom)

$bat = @'
@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
'@
Set-Content -Path (Join-Path $stage 'install.bat') -Value $bat -Encoding UTF8

$unbat = @'
@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
pause
'@
Set-Content -Path (Join-Path $stage 'uninstall.bat') -Value $unbat -Encoding UTF8

$readme = @"
Wireless Battery $Version（个人自用构建）
==========================================

安装：双击 install.bat
  - 程序复制到 %LOCALAPPDATA%\Programs\Wireless Battery
  - 在开始菜单建快捷方式，并写一条“应用和功能”里的卸载项
  - 安装完成后自动启动一次

卸载：双击 uninstall.bat，或从“设置 → 应用 → 已安装的应用”里卸载

说明
  - 这是未签名的个人构建，首次运行时 Windows 可能提示“未知发布者”，
    点“更多信息 → 仍要运行”即可。
  - 请从开始菜单或资源管理器启动；用其他低权限程序转启动的话，
    程序没有权限把组件放进任务栏，会弹一次提示。
  - 首次打开会出现在任务栏右侧；右键任务栏上的组件可以调整外观、
    背景不透明度、刷新和语言。
  - 基于 krisgfx9/Wireless-Device-Battery-Monitor（GPL-3.0），源码见该项目。
"@
Set-Content -Path (Join-Path $stage 'README.txt') -Value $readme -Encoding UTF8

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist ("WirelessBattery-Setup-$Version.zip")
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal

Write-Host ''
Write-Host "打包完成: $zip"
Get-ChildItem $stage | ForEach-Object { '  ' + $_.Name + '  ' + [math]::Round($_.Length / 1KB, 1) + ' KB' }
'  ---'
'  zip  ' + [math]::Round((Get-Item $zip).Length / 1KB, 1) + ' KB'
