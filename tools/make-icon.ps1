# Generates res\app.ico: a battery outline with a green level bar, on a transparent background so the
# icon does not carry a plate of its own colour into the taskbar or the desktop.
# Needs only PowerShell and the GDI+ types that ship with Windows.
[CmdletBinding()]
param([string]$OutFile = (Join-Path (Split-Path $PSScriptRoot -Parent) 'res\app.ico'))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$sizes = 16, 24, 32, 48, 256
$bodyColor  = [System.Drawing.ColorTranslator]::FromHtml('#FBFCFD')
$edgeColor  = [System.Drawing.ColorTranslator]::FromHtml('#8C96A5')
$levelFrom  = [System.Drawing.ColorTranslator]::FromHtml('#3DDC97')
$levelTo    = [System.Drawing.ColorTranslator]::FromHtml('#1FAF5F')

function New-RoundedRect([System.Drawing.RectangleF]$r, [double]$radius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = [Math]::Max(0.5, $radius) * 2
    $path.AddArc($r.X, $r.Y, $d, $d, 180, 90)
    $path.AddArc($r.Right - $d, $r.Y, $d, $d, 270, 90)
    $path.AddArc($r.Right - $d, $r.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($r.X, $r.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-IconBitmap([int]$size) {
    # Everything is laid out on a 16 unit grid so the small sizes stay crisp.
    $u = $size / 16.0
    $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $bodyRect = New-Object System.Drawing.RectangleF (1.2 * $u), (4.2 * $u), (11.6 * $u), (7.6 * $u)
    $body = New-RoundedRect $bodyRect (1.5 * $u)
    $g.FillPath((New-Object System.Drawing.SolidBrush $bodyColor), $body)

    $levelRect = New-Object System.Drawing.RectangleF (2.2 * $u), (5.2 * $u), (7.2 * $u), (5.6 * $u)
    $level = New-Object System.Drawing.Drawing2D.LinearGradientBrush $levelRect, $levelFrom, $levelTo, 90.0
    $g.SetClip($body)
    $g.FillRectangle($level, $levelRect)
    $g.ResetClip()

    $pen = New-Object System.Drawing.Pen ((New-Object System.Drawing.SolidBrush $edgeColor)), ([float][Math]::Max(0.9, 1.15 * $u))
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($pen, $body)

    $tipRect = New-Object System.Drawing.RectangleF (12.9 * $u), (6.6 * $u), (1.9 * $u), (2.8 * $u)
    $tip = New-RoundedRect $tipRect (0.6 * $u)
    $g.FillPath((New-Object System.Drawing.SolidBrush $edgeColor), $tip)

    $g.Dispose()
    return $bmp
}

$frames = New-Object System.Collections.Generic.List[object]
foreach ($size in $sizes) {
    $bmp = New-IconBitmap $size
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $frames.Add([pscustomobject]@{ Size = $size; Bytes = $ms.ToArray() })
    $bmp.Dispose()
    $ms.Dispose()
}

# ICONDIR + ICONDIRENTRY records + PNG payloads.
$out = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter $out
$w.Write([UInt16]0)
$w.Write([UInt16]1)
$w.Write([UInt16]$frames.Count)
$offset = 6 + 16 * $frames.Count
foreach ($frame in $frames) {
    $dim = if ($frame.Size -ge 256) { 0 } else { $frame.Size }
    $w.Write([Byte]$dim)
    $w.Write([Byte]$dim)
    $w.Write([Byte]0)
    $w.Write([Byte]0)
    $w.Write([UInt16]1)
    $w.Write([UInt16]32)
    $w.Write([UInt32]$frame.Bytes.Length)
    $w.Write([UInt32]$offset)
    $offset += $frame.Bytes.Length
}
foreach ($frame in $frames) { $w.Write($frame.Bytes) }
$w.Flush()
[System.IO.File]::WriteAllBytes($OutFile, $out.ToArray())
$w.Dispose()
$out.Dispose()

$total = (Get-Item $OutFile).Length
Write-Host ("wrote {0} ({1} bytes, sizes {2})" -f $OutFile, $total, ($sizes -join ' '))