# Splits a sprite sheet into cells: split-sheet.ps1 -Sheet <png> -Cols 8 -Rows 4 -Names a,b,c,... -OutDir <dir> [-Trim 6]
# Cells are named in reading order; names "-" are skipped. Keeps alpha (PNG 32bpp).
param([string]$Sheet, [int]$Cols, [int]$Rows, [string[]]$Names, [string]$OutDir, [int]$Trim = 0)
Add-Type -AssemblyName System.Drawing
if ($Names.Count -eq 1 -and $Names[0] -match ",") { $Names = $Names[0].Split(",") }
$bmp = [System.Drawing.Bitmap]::FromFile($Sheet)
$cw = [math]::Floor($bmp.Width / $Cols); $ch = [math]::Floor($bmp.Height / $Rows)
New-Item -ItemType Directory -Force $OutDir | Out-Null
$i = 0
for ($r = 0; $r -lt $Rows; $r++) { for ($c = 0; $c -lt $Cols; $c++) {
  $name = $Names[$i]; $i++
  if (-not $name -or $name -eq '-') { continue }
  $rect = New-Object System.Drawing.Rectangle (($c * $cw) + $Trim), (($r * $ch) + $Trim), ($cw - 2 * $Trim), ($ch - 2 * $Trim)
  $cell = $bmp.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $cell.Save((Join-Path $OutDir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png); $cell.Dispose()
  Write-Output "$name ${cw}x${ch}"
} }
$bmp.Dispose()
