# 用本机 MSVC 工具链编译并运行 Makefile 中 TESTS 表列出的全部测试。
# TESTS 表是唯一来源（name|额外源文件），新增测试不需要修改本脚本。
param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    # 本机工具链路径；换机器时只改这两行。
    $vcvars = 'D:\MIcrosoft Visual Studio2022\Community\VC\Auxiliary\Build\vcvars64.bat'
    $sdk = 'D:\Windows Kits\10\Include\10.0.22621.0'
    if (-not (Test-Path $vcvars)) { throw "找不到 vcvars64.bat：$vcvars" }
    if (-not (Test-Path $sdk)) { throw "找不到 Windows SDK 头文件：$sdk" }

    $flags = @('/nologo', '/std:c++17', '/EHsc', '/O1', '/MT', '/W3', '/DNOMINMAX', '/DUNICODE', '/D_UNICODE', '/D_CRT_SECURE_NO_WARNINGS')
    $inc = @('/I', 'src', '/I', 'src\core', '/I', 'src\core\drivers', '/I', 'src\text',
             '/I', "$sdk\ucrt", '/I', "$sdk\shared", '/I', "$sdk\um")

    # 导入 MSVC 环境一次，之后直接调用 cl，避免每次 cmd /c 吞掉编译输出。
    foreach ($line in (cmd /c "call `"$vcvars`" >nul 2>&1 && set")) {
        if ($line -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2]) }
    }

    # 解析 TESTS：从 `TESTS := \` 开始，直到某行不再以反斜杠结尾。
    $makefile = Get-Content Makefile
    $startLine = ($makefile | Select-String -Pattern '^TESTS\s*:=' | Select-Object -First 1)
    if (-not $startLine) { throw 'Makefile 里找不到 TESTS 表' }
    $start = $startLine.LineNumber - 1
    $entries = @()
    $i = $start
    do {
        $line = $makefile[$i].Trim()
        if ($i -eq $start) { $line = ($line -replace '^TESTS\s*:=\s*', '') }
        $continues = $line.EndsWith('\')
        $line = $line.TrimEnd('\').Trim()
        if ($line) { $entries += $line }
        $i++
    } while ($continues -and $i -lt $makefile.Count)
    if (-not $entries) { throw 'TESTS 表为空' }

    New-Item -ItemType Directory -Force build\tests | Out-Null
    $passed = 0
    $failed = @()
    foreach ($entry in $entries) {
        $parts = $entry.Split('|')
        $name = $parts[0].Trim()
        $extras = @()
        if ($parts.Count -gt 1) {
            $extras = @($parts[1].Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) |
                ForEach-Object { $_.Replace('/', '\') })
        }
        $exe = "build\tests\$name.exe"
        $clArgs = @($flags) + @($inc) + @("tests\$name.cpp", "/Fe:$exe", '/Fo:build\tests\') + $extras
        # 编译输出只在失败时打印：cl 把 /Fo 目录形式当作整条命令的选项，成功时也会写一条 D9026 提示。
        # 调用 cl 时临时关闭 Stop，否则 PowerShell 会把 stderr 当成终止性错误。
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $build = & cl.exe @clArgs 2>&1
            $buildCode = $LASTEXITCODE
        }
        finally { $ErrorActionPreference = $previous }
        if ($buildCode -ne 0) {
            $build | ForEach-Object { $_.ToString() } |
                Where-Object { $_ -notmatch 'D9026' } | Select-Object -Last 20
            $failed += $name
            continue
        }
        $ErrorActionPreference = 'Continue'
        try {
            $run = & ".\$exe" 2>&1
            $runCode = $LASTEXITCODE
        }
        finally { $ErrorActionPreference = $previous }
        if ($runCode -eq 0) { $passed++ }
        else {
            $run | ForEach-Object { $_.ToString() } | Select-Object -Last 20
            $failed += $name
        }
    }

    if (-not $Quiet) {
        "passed: $passed"
        if ($failed) { 'failed: ' + ($failed -join ', ') } else { 'failed: none' }
    }
    if ($failed) { exit 1 }
}
finally { Pop-Location }
