# Converts item icons (PNG with alpha) into 16x16 voxel grids for 3D "extruded sprite" item models.
# Usage: split-sheet... then: sprite-to-voxels.ps1 -Dir assets/icons/items -Out assets/icons/voxels.json
# Output: { "<name>": { "w":16,"h":16, "rows":[ [ [x0,x1,"RRGGBB"], ... ] per row from top ] } }
param([string]$Dir, [string]$Out, [int]$Size = 16)
Add-Type -AssemblyName System.Drawing
$result = @{}
Get-ChildItem $Dir -Filter *.png | ForEach-Object {
  $bmp = [System.Drawing.Bitmap]::FromFile($_.FullName)
  # crop to the opaque bounding box first, then downsample to Size x Size (nearest-ish by block average)
  $minX = $bmp.Width; $minY = $bmp.Height; $maxX = -1; $maxY = -1
  for ($y = 0; $y -lt $bmp.Height; $y++) { for ($x = 0; $x -lt $bmp.Width; $x++) {
    if ($bmp.GetPixel($x, $y).A -gt 100) { if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }; if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y } }
  } }
  if ($maxX -lt 0) { $bmp.Dispose(); return }
  $bw = $maxX - $minX + 1; $bh = $maxY - $minY + 1
  $side = [math]::Max($bw, $bh)
  $ox = $minX - [math]::Floor(($side - $bw) / 2); $oy = $minY - [math]::Floor(($side - $bh) / 2)
  $cell = $side / $Size
  $rows = @()
  for ($gy = 0; $gy -lt $Size; $gy++) {
    $row = @(); $run = $null
    for ($gx = 0; $gx -lt $Size; $gx++) {
      $r = 0; $g = 0; $b = 0; $n = 0
      $x0 = [int]($ox + $gx * $cell); $y0 = [int]($oy + $gy * $cell)
      $x1 = [int]($ox + ($gx + 1) * $cell); $y1 = [int]($oy + ($gy + 1) * $cell)
      for ($y = $y0; $y -lt $y1; $y++) { for ($x = $x0; $x -lt $x1; $x++) {
        if ($x -ge 0 -and $y -ge 0 -and $x -lt $bmp.Width -and $y -lt $bmp.Height) { $p = $bmp.GetPixel($x, $y); if ($p.A -gt 100) { $r += $p.R; $g += $p.G; $b += $p.B; $n++ } }
      } }
      $total = [math]::Max(1, ($x1 - $x0) * ($y1 - $y0))
      if ($n -ge $total * 0.4) {
        $hex = "{0:X2}{1:X2}{2:X2}" -f [int]($r / $n), [int]($g / $n), [int]($b / $n)
        if ($run -and $run[2] -eq $hex -and $run[1] -eq $gx - 1) { $run[1] = $gx } else { if ($run) { $row += ,$run }; $run = @($gx, $gx, $hex) }
      } elseif ($run) { $row += ,$run; $run = $null }
    }
    if ($run) { $row += ,$run }
    $rows += ,$row
  }
  $result[$_.BaseName] = @{ w = $Size; h = $Size; rows = $rows }
  $bmp.Dispose()
  Write-Output "$($_.BaseName): $(($rows | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum) runs"
}
$result | ConvertTo-Json -Depth 6 -Compress | Set-Content -Encoding UTF8 $Out
