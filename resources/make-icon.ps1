[CmdletBinding()]
param(
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $OutFile = Join-Path $PSScriptRoot 'app.ico'
}

Add-Type -AssemblyName System.Drawing

$sizes = @(16, 24, 32, 48, 256)

$colors = @{
    Shell      = [System.Drawing.ColorTranslator]::FromHtml('#172D40')
    ShellLight = [System.Drawing.ColorTranslator]::FromHtml('#29475B')
    Interior   = [System.Drawing.ColorTranslator]::FromHtml('#EAF4F0')
    GreenStart = [System.Drawing.ColorTranslator]::FromHtml('#55E6A5')
    GreenEnd   = [System.Drawing.ColorTranslator]::FromHtml('#12B76A')
    Lightning  = [System.Drawing.Color]::White
}


function New-RoundedRect {
    param(
        [System.Drawing.RectangleF]$Rect,
        [double]$Radius
    )

    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()

    $r = [Math]::Max(
        0.1,
        [Math]::Min($Radius, [Math]::Min($Rect.Width, $Rect.Height) / 2)
    )

    $d = [single]($r * 2)

    $path.AddArc($Rect.X, $Rect.Y, $d, $d, 180, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Y, $d, $d, 270, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $d, $d, $d, 90, 90)

    $path.CloseFigure()
    return $path
}


function New-IconBitmap {
    param([int]$Size)

    $u = $Size / 16.0

    $bmp = [System.Drawing.Bitmap]::new(
        $Size,
        $Size,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )

    $g = [System.Drawing.Graphics]::FromImage($bmp)

    $body = $null
    $inner = $null
    $bolt = $null
    $shellBrush = $null
    $innerBrush = $null
    $gradient = $null
    $boltBrush = $null
    $outlinePen = $null

    try {
        # Rendering quality
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

        # Transparent background
        $g.Clear([System.Drawing.Color]::Transparent)

        $tipRect = [System.Drawing.RectangleF]::new(
            [single](12.8 * $u),
            [single](6.1 * $u),
            [single](2.2 * $u),
            [single](3.8 * $u)
        )

        $tip = New-RoundedRect $tipRect (0.8 * $u)

        $shellBrush = [System.Drawing.SolidBrush]::new($colors.Shell)

        $g.FillPath($shellBrush, $tip)
        $tip.Dispose()
        $tip = $null


        $bodyRect = [System.Drawing.RectangleF]::new(
            [single](0.8 * $u),
            [single](3.5 * $u),
            [single](12.4 * $u),
            [single](9.0 * $u)
        )

        $body = New-RoundedRect $bodyRect (2.0 * $u)

        $g.FillPath($shellBrush, $body)


        $innerRect = [System.Drawing.RectangleF]::new(
            [single](1.9 * $u),
            [single](4.6 * $u),
            [single](10.2 * $u),
            [single](6.8 * $u)
        )

        $inner = New-RoundedRect $innerRect (1.0 * $u)

        $innerBrush = [System.Drawing.SolidBrush]::new($colors.Interior)

        $g.FillPath($innerBrush, $inner)

        $levelRect = [System.Drawing.RectangleF]::new(
            $innerRect.X,
            $innerRect.Y,
            [single]($innerRect.Width * 0.82),
            $innerRect.Height
        )

        $gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $levelRect,
            $colors.GreenStart,
            $colors.GreenEnd,
            [single]0
        )
        $g.SetClip($inner)

        $g.FillRectangle($gradient, $levelRect)

        $g.ResetClip()


        $points = [System.Drawing.PointF[]]@(
            [System.Drawing.PointF]::new(
                [single](7.8 * $u),
                [single](5.25 * $u)
            ),
            [System.Drawing.PointF]::new(
                [single](5.45 * $u),
                [single](8.15 * $u)
            ),
            [System.Drawing.PointF]::new(
                [single](6.95 * $u),
                [single](8.15 * $u)
            ),
            [System.Drawing.PointF]::new(
                [single](6.15 * $u),
                [single](10.75 * $u)
            ),
            [System.Drawing.PointF]::new(
                [single](9.2 * $u),
                [single](7.35 * $u)
            ),
            [System.Drawing.PointF]::new(
                [single](7.65 * $u),
                [single](7.35 * $u)
            )
        )

        $bolt = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $bolt.AddPolygon($points)

        $boltBrush = [System.Drawing.SolidBrush]::new($colors.Lightning)

        $g.FillPath($boltBrush, $bolt)


        $outlinePen = [System.Drawing.Pen]::new(
            $colors.Shell,
            [single](0.35 * $u)
        )

        $outlinePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

        $g.DrawPath($outlinePen, $body)

    }
    catch {
        $bmp.Dispose()
        throw
    }
    finally {
        # Release GDI+ resources
        if ($body) { $body.Dispose() }
        if ($inner) { $inner.Dispose() }
        if ($bolt) { $bolt.Dispose() }
        if ($shellBrush) { $shellBrush.Dispose() }
        if ($innerBrush) { $innerBrush.Dispose() }
        if ($gradient) { $gradient.Dispose() }
        if ($boltBrush) { $boltBrush.Dispose() }
        if ($outlinePen) { $outlinePen.Dispose() }

        $g.Dispose()
    }

    return $bmp
}


$frames = [System.Collections.Generic.List[object]]::new()

foreach ($size in $sizes) {
    Write-Host "Rendering ${size}x${size}..."

    $bmp = New-IconBitmap $size
    $ms = [System.IO.MemoryStream]::new()

    try {
        $bmp.Save(
            $ms,
            [System.Drawing.Imaging.ImageFormat]::Png
        )

        $frames.Add(
            [pscustomobject]@{
                Size  = $size
                Bytes = $ms.ToArray()
            }
        )
    }
    finally {
        $bmp.Dispose()
        $ms.Dispose()
    }
}

$out = [System.IO.MemoryStream]::new()
$writer = [System.IO.BinaryWriter]::new($out)

try {
    # ICONDIR
    $writer.Write([UInt16]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]$frames.Count)

    # First image offset
    $offset = 6 + 16 * $frames.Count

    # ICONDIRENTRY records
    foreach ($frame in $frames) {
        $dim = if ($frame.Size -ge 256) {
            0
        }
        else {
            [byte]$frame.Size
        }

        $writer.Write([byte]$dim)
        $writer.Write([byte]$dim)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]32)
        $writer.Write([UInt32]$frame.Bytes.Length)
        $writer.Write([UInt32]$offset)

        $offset += $frame.Bytes.Length
    }

    # PNG payloads
    foreach ($frame in $frames) {
        $writer.Write($frame.Bytes)
    }

    $writer.Flush()
    $icoBytes = $out.ToArray()
}
finally {
    $writer.Dispose()
    $out.Dispose()
}


$OutFile = [System.IO.Path]::GetFullPath($OutFile)

$directory = Split-Path -Parent $OutFile

if (-not (Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory -Force |
    Out-Null
}

$tempFile = "$OutFile.tmp"

try {
    [System.IO.File]::WriteAllBytes($tempFile, $icoBytes)

    Move-Item -LiteralPath $tempFile -Destination $OutFile -Force
}
catch {
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }

    throw
}


$total = (Get-Item $OutFile).Length

Write-Host ""
Write-Host "====================================" -ForegroundColor DarkGreen
Write-Host " BatteryBar Icon Generated!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor DarkGreen

Write-Host "Output : $OutFile"
Write-Host "Size   : $total bytes"
Write-Host "Frames : $($sizes -join ', ')"

Write-Host ""
