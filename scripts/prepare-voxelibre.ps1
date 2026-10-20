# Prepares the VoxeLibre (Pixel Perfection, CC BY-SA 4.0) textures for the game:
#  1. tool textures  → assets/icons/items/<tool>_<material>.png (16×16 upscaled ×8, nearest neighbour)
#  2. armor inv icons → assets/icons/items/<piece>_<material>.png (material keys: wood=leather, stone=chain)
#  3. armor layer textures (64×32, Minecraft skin layout) → per-limb face images for Decals,
#     assets/armor/<piece>_<material>_<limb>_<face>.png (upscaled ×8 so Decals stay crisp)
# Usage: powershell -File scripts/prepare-voxelibre.ps1
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root "assets\thirdparty\voxelibre"
$items = Join-Path $root "assets\icons\items"
$armorOut = Join-Path $root "assets\armor"
New-Item -ItemType Directory -Force $items, $armorOut | Out-Null

function Upscale([System.Drawing.Bitmap]$bmp, [int]$factor) {
  $out = New-Object System.Drawing.Bitmap ($bmp.Width * $factor), ($bmp.Height * $factor), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($out)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $g.DrawImage($bmp, 0, 0, $out.Width, $out.Height)
  $g.Dispose()
  return $out
}
function Crop([System.Drawing.Bitmap]$bmp, [int]$x, [int]$y, [int]$w, [int]$h) {
  $rect = New-Object System.Drawing.Rectangle $x, $y, $w, $h
  return $bmp.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}
function Load([string]$name) {
  $raw = [System.Drawing.Bitmap]::FromFile((Join-Path $src $name))
  $copy = New-Object System.Drawing.Bitmap $raw   # drop the palette: plain 32bpp
  $raw.Dispose()
  return $copy
}

# 1. tools
$materials = @{ wood = "wood"; stone = "stone"; steel = "iron"; diamond = "diamond" }
$tools = @{ pick = "pickaxe"; shovel = "shovel"; axe = "axe"; sword = "sword" }
foreach ($m in $materials.Keys) { foreach ($t in $tools.Keys) {
  $bmp = Load "default_tool_$m$t.png"
  $up = Upscale $bmp 8
  $up.Save((Join-Path $items "$($tools[$t])_$($materials[$m]).png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $up.Dispose(); $bmp.Dispose()
} }
$bmp = Load "default_tool_shears.png"; $up = Upscale $bmp 8; $up.Save((Join-Path $items "shears.png"), [System.Drawing.Imaging.ImageFormat]::Png); $up.Dispose(); $bmp.Dispose()

# 2. armor inventory icons
$armorMat = @{ leather = "wood"; chain = "stone"; iron = "iron"; diamond = "diamond" }
foreach ($p in @("helmet", "chestplate", "leggings", "boots")) { foreach ($m in $armorMat.Keys) {
  $bmp = Load "mcl_armor_inv_${p}_$m.png"
  $up = Upscale $bmp 8
  $up.Save((Join-Path $items "${p}_$($armorMat[$m]).png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $up.Dispose(); $bmp.Dispose()
} }

# 3. armor layer faces. Minecraft layer layout (64×32): head at (0,0) block 8; body/arms/legs at y 16.
# box(ox, oy, w, h, d): faces top (ox+d, oy, w, d), bottom (ox+d+w, oy, w, d), right (ox, oy+d, d, h),
# front (ox+d, oy+d, w, h), left (ox+d+w, oy+d, d, h), back (ox+d+w+d, oy+d, w, h)
function Faces([System.Drawing.Bitmap]$bmp, [string]$prefix, [int]$ox, [int]$oy, [int]$w, [int]$h, [int]$d, [int]$rowFrom, [int]$rowTo) {
  # rowFrom/rowTo limit the side faces to a vertical slice (for upper/lower limb halves)
  $faces = @{
    top    = @(($ox + $d), $oy, $w, $d)
    bottom = @(($ox + $d + $w), $oy, $w, $d)
    right  = @($ox, ($oy + $d + $rowFrom), $d, ($rowTo - $rowFrom))
    front  = @(($ox + $d), ($oy + $d + $rowFrom), $w, ($rowTo - $rowFrom))
    left   = @(($ox + $d + $w), ($oy + $d + $rowFrom), $d, ($rowTo - $rowFrom))
    back   = @(($ox + $d + $w + $d), ($oy + $d + $rowFrom), $w, ($rowTo - $rowFrom))
  }
  foreach ($f in $faces.Keys) {
    $r = $faces[$f]
    $c = Crop $bmp $r[0] $r[1] $r[2] $r[3]
    # skip fully transparent faces
    $opaque = $false
    for ($y = 0; $y -lt $c.Height -and -not $opaque; $y++) { for ($x = 0; $x -lt $c.Width; $x++) { if ($c.GetPixel($x, $y).A -gt 0) { $opaque = $true; break } } }
    if ($opaque) {
      $up = Upscale $c 8
      $up.Save((Join-Path $armorOut "${prefix}_$f.png"), [System.Drawing.Imaging.ImageFormat]::Png)
      $up.Dispose()
    }
    $c.Dispose()
  }
}
foreach ($m in $armorMat.Keys) {
  $mk = $armorMat[$m]
  $helm = Load "mcl_armor_helmet_$m.png"
  Faces $helm "helmet_${mk}_head" 32 0 8 8 8 0 8
  $helm.Dispose()
  $chest = Load "mcl_armor_chestplate_$m.png"
  Faces $chest "chestplate_${mk}_torsoupper" 16 16 8 12 4 0 8
  Faces $chest "chestplate_${mk}_torsolower" 16 16 8 12 4 8 12
  Faces $chest "chestplate_${mk}_upperarm" 40 16 4 12 4 0 6
  Faces $chest "chestplate_${mk}_lowerarm" 40 16 4 12 4 6 12
  $chest.Dispose()
  $legs = Load "mcl_armor_leggings_$m.png"
  Faces $legs "leggings_${mk}_torso" 16 16 8 12 4 6 12
  Faces $legs "leggings_${mk}_upperleg" 0 16 4 12 4 0 6
  Faces $legs "leggings_${mk}_lowerleg" 0 16 4 12 4 6 12
  $legs.Dispose()
  $boots = Load "mcl_armor_boots_$m.png"
  Faces $boots "boots_${mk}_foot" 0 16 4 12 4 9 12
  $boots.Dispose()
}
Write-Output ("items: " + (Get-ChildItem $items -Filter *.png).Count + ", armor faces: " + (Get-ChildItem $armorOut -Filter *.png).Count)
