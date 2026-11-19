# 用法：powershell -NoProfile -File packaging\build-local.ps1 [-Version 1.0.0]
# 产物：dist\BatteryBar-<版本>-portable.zip
param([string]$Version = '1.0.0')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$exe = $null
foreach ($rel in @('build\BatteryBar.exe', 'BatteryBar.exe')) {
    $candidate = Join-Path $root $rel
    if (Test-Path $candidate) { $exe = $candidate; break }
}
if (-not $exe) { throw "还没有编译好的程序，先在仓库根目录运行 make（产物在 build\）" }

$stage = Join-Path $root '.temp\stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item $exe (Join-Path $stage 'BatteryBar.exe')

# 官方安装包里带的 headsetcontrol.exe（额外耳机支持）如果本机有，就一起打进去
$hsc = Join-Path $root 'third_party\headsetcontrol\headsetcontrol.exe'
if (-not (Test-Path $hsc)) { $hsc = Join-Path $env:LOCALAPPDATA 'Programs\BatteryBar\headsetcontrol.exe' }
if (Test-Path $hsc) {
    Copy-Item $hsc (Join-Path $stage 'headsetcontrol.exe')
    Write-Host '已带上 headsetcontrol.exe'
} else {
    Write-Host '没有找到 headsetcontrol.exe，压缩包只带主程序'
}


Set-Content -Path (Join-Path $stage 'README.txt') -Value $readme -Encoding UTF8

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist ("BatteryBar-$Version-portable.zip")
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal

Write-Host ''
Write-Host "打包完成: $zip"
Get-ChildItem $stage | ForEach-Object { '  ' + $_.Name + '  ' + [math]::Round($_.Length / 1KB, 1) + ' KB' }
'  ---'
'  zip  ' + [math]::Round((Get-Item $zip).Length / 1KB, 1) + ' KB'
