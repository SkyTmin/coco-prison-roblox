# Exact 16×16 pixel grids for the VoxeLibre tool textures → runs JSON (merged into assets/icons/voxels.json by node).
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root "assets\thirdparty\voxelibre"
$materials = @{ wood = "wood"; stone = "stone"; steel = "iron"; diamond = "diamond" }
$tools = @{ pick = "pickaxe"; shovel = "shovel"; axe = "axe"; sword = "sword" }
$result = @{}
$files = @{}
foreach ($m in $materials.Keys) { foreach ($t in $tools.Keys) { $files["$($tools[$t])_$($materials[$m])"] = "default_tool_$m$t.png" } }
$files["shears"] = "default_tool_shears.png"
foreach ($name in $files.Keys) {
  $raw = [System.Drawing.Bitmap]::FromFile((Join-Path $src $files[$name]))
  $bmp = New-Object System.Drawing.Bitmap $raw; $raw.Dispose()
  $rows = @()
  for ($y = 0; $y -lt $bmp.Height; $y++) {
    $row = @()
    for ($x = 0; $x -lt $bmp.Width; $x++) {
      $p = $bmp.GetPixel($x, $y)
      if ($p.A -gt 100) { $row += ,@($x, ("{0:X2}{1:X2}{2:X2}" -f $p.R, $p.G, $p.B)) }
    }
    $rows += ,$row
  }
  $result[$name] = @{ w = $bmp.Width; h = $bmp.Height; px = $rows }
  $bmp.Dispose()
}
$result | ConvertTo-Json -Depth 6 -Compress | Set-Content -Encoding UTF8 (Join-Path $root "assets\icons\voxels-tools.json")
Write-Output ("tools: " + $result.Count)
