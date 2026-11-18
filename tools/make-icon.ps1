# 用 GDI+ 绘制电池图标，生成 res\app.ico（16/24/32/48/256 五个尺寸）。
# 只在需要修改图标时运行：powershell -NoProfile -ExecutionPolicy Bypass -File tools\make-icon.ps1
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$sizes = 16, 24, 32, 48, 256
$pngs = foreach ($s in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap $s, $s
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $u = $s / 16.0
    $body = New-Object System.Drawing.RectangleF (1 * $u), (4 * $u), (12.5 * $u), (8 * $u)
    $edge = [System.Drawing.Color]::FromArgb(255, 60, 60, 60)
    $fill = [System.Drawing.Color]::FromArgb(255, 30, 190, 90)
    $pen = New-Object System.Drawing.Pen $edge, ([Math]::Max(1, 1.2 * $u))
    $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)), $body)
    $g.DrawRectangle($pen, $body.X, $body.Y, $body.Width, $body.Height)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush $edge), (13.5 * $u), (6.5 * $u), (1.5 * $u), (3 * $u))
    $g.FillRectangle((New-Object System.Drawing.SolidBrush $fill), (2.5 * $u), (5.5 * $u), (7 * $u), (5 * $u))
    $g.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    , $ms.ToArray()
}

$out = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter $out
$w.Write([UInt16]0); $w.Write([UInt16]1); $w.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]
    $d = if ($s -ge 256) { 0 } else { $s }
    $w.Write([byte]$d); $w.Write([byte]$d); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([UInt16]1); $w.Write([UInt16]32)
    $w.Write([UInt32]$pngs[$i].Length); $w.Write([UInt32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $w.Write($p) }
$target = Join-Path $root 'res\app.ico'
[System.IO.File]::WriteAllBytes($target, $out.ToArray())
"wrote $target ($($out.Length) bytes, sizes $($sizes -join ' '))"