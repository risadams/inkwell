#requires -Version 7
<#
.SYNOPSIS
  Paints terminal/wash.png, the watercolor bleed that sits in the bottom-right corner
  of the terminal. Windows only (System.Drawing). The PNG is committed, so other
  machines never need to run this; re-run it only to change the wash.
.PARAMETER Preview
  Also writes a copy composited over the Ink Parchment ground at the given path,
  so you can judge the strength without opening a terminal.
#>
param(
    [int]$Width = 900,
    [int]$Height = 620,
    [int]$Seed = 7,
    [string]$Preview
)

Add-Type -AssemblyName System.Drawing

$out = Join-Path $PSScriptRoot 'wash.png'
$bmp = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)
$rng = [System.Random]::new($Seed)

# One soft-edged pool of pigment: opaque-ish in the middle, fully clear at the rim.
function Add-Pool([double]$cx, [double]$cy, [double]$rx, [double]$ry, [string]$hex, [int]$alpha) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddEllipse([single]($cx - $rx), [single]($cy - $ry), [single](2 * $rx), [single](2 * $ry))
    $brush = [System.Drawing.Drawing2D.PathGradientBrush]::new($path)
    $rgb = [System.Drawing.ColorTranslator]::FromHtml($hex)
    $brush.CenterColor = [System.Drawing.Color]::FromArgb($alpha, $rgb)
    $brush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $rgb))
    $blend = [System.Drawing.Drawing2D.Blend]::new(5)
    $blend.Positions = [single[]](0, 0.25, 0.5, 0.75, 1)
    $blend.Factors = [single[]](0, 0.08, 0.32, 0.72, 1)
    $brush.Blend = $blend
    $g.FillPath($brush, $path)
    $brush.Dispose(); $path.Dispose()
}

# A bleed is several overlapping pools nudged off-centre, so no edge is a clean ellipse.
function Add-Bleed([double]$cx, [double]$cy, [double]$r, [string]$hex, [int]$alpha) {
    foreach ($i in 1..7) {
        $dx = ($rng.NextDouble() - 0.5) * $r * 0.9
        $dy = ($rng.NextDouble() - 0.5) * $r * 0.7
        $rx = $r * (0.55 + $rng.NextDouble() * 0.5)
        $ry = $r * (0.45 + $rng.NextDouble() * 0.45)
        Add-Pool ($cx + $dx) ($cy + $dy) $rx $ry $hex $alpha
    }
}

# Rose in the corner, teal running along the bottom edge, plum up the right side.
Add-Bleed ($Width * 0.50) ($Height * 1.02) ($Width * 0.26) '#3d8a9f' 70
Add-Bleed ($Width * 1.00) ($Height * 0.42) ($Width * 0.20) '#9a5e9e' 62
Add-Bleed ($Width * 0.92) ($Height * 0.98) ($Width * 0.34) '#e24a8a' 84

$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
"wrote $out ($Width x $Height)"

if ($Preview) {
    $pv = [System.Drawing.Bitmap]::new($Width, $Height)
    $pg = [System.Drawing.Graphics]::FromImage($pv)
    $pg.Clear([System.Drawing.ColorTranslator]::FromHtml('#1a1614'))
    $pg.DrawImage($bmp, 0, 0, $Width, $Height)
    $pg.Dispose()
    $pv.Save($Preview, [System.Drawing.Imaging.ImageFormat]::Png)
    $pv.Dispose()
    "wrote preview $Preview"
}
$bmp.Dispose()
