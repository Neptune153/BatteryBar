# Compiles and runs every test listed in the Makefile's TESTS table with the local MSVC toolchain.
# The table is the single source of truth (name|extra sources), so adding a test needs no edit here.
param([switch]$Quiet)
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')

$vcvars = 'D:\MIcrosoft Visual Studio2022\Community\VC\Auxiliary\Build\vcvars64.bat'
$sdk = 'D:\Windows Kits\10\Include\10.0.22621.0'
$flags = '/nologo /std:c++17 /EHsc /O1 /MT /W3 /DNOMINMAX /DUNICODE /D_UNICODE /D_CRT_SECURE_NO_WARNINGS'
$inc = "/I src /I src\core /I src\core\drivers /I src\text /I $sdk\ucrt /I $sdk\shared /I $sdk\um"

# Read the TESTS table: entry lines are `name|extra sources` and end with a trailing backslash.
$table = Select-String -Path Makefile -Pattern '^TESTS\s*:=' | Select-Object -First 1
$start = $table.LineNumber
$entries = @()
$i = $start - 1   # the TESTS line itself may already carry the first entry
do {
    $line = (Get-Content Makefile)[$i].TrimEnd('\').Trim()
    if ($i -ne ($start - 1)) { $entries += $line }
    if ($i -eq ($start - 1) -and $line -match '^TESTS\s*:=\s*(.*)$') {
        $first = $matches[1].Trim()
        if ($first) { $entries += $first }
    }
    $i++
} while ((Get-Content Makefile)[$i - 1].TrimEnd().EndsWith('\'))

# Import the MSVC environment once, then call cl directly (one cmd /c per test hid its errors).
foreach ($l in (cmd /c "call `"$vcvars`" >nul 2>&1 && set")) {
    if ($l -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2]) }
}

New-Item -ItemType Directory -Force build\tests | Out-Null
$ok = 0; $failed = @()
foreach ($entry in $entries) {
    if (-not $entry) { continue }
    $parts = $entry.Split('|')
    $name = $parts[0].Trim()
    $extras = if ($parts.Count -gt 1) { $parts[1].Replace('/', '\').Trim() } else { '' }
    $exe = "build\tests\$name.exe"
    $clArgs = @($flags.Split(' '), $inc.Split(' '), "tests\$name.cpp", '/Fe:' + $exe, '/Fo:build\tests\')
    if ($extras) { $clArgs += $extras.Split(' ') }
    & cl.exe @clArgs | Out-Null
    if ($LASTEXITCODE -ne 0) { $failed += $name; continue }
    & ".\$exe" | Out-Null
    if ($LASTEXITCODE -eq 0) { $ok++ } else { $failed += $name }
}

if (-not $Quiet) {
    "passed: $ok"
    if ($failed) { "failed: " + ($failed -join ', ') } else { "failed: none" }
}
if ($failed) { exit 1 }
Pop-Location
