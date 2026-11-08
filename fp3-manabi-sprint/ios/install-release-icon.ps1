# Run on the owner's Windows PC; source is never regenerated or modified.
# PowerShell 5.1+ on Windows. Use: powershell -ExecutionPolicy Bypass -File .\fp3-manabi-sprint\ios\install-release-icon.ps1
[CmdletBinding()]
param(
  [string]$Source = 'C:\Users\PC\Documents\アプリ開発\fp3-kakomon-coach\fp3-kakomon-coach\ios-app\assets\icon.png'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$catalog = Join-Path $PSScriptRoot 'Assets.xcassets\AppIcon.appiconset'
$target = Join-Path $catalog 'AppIcon-1024.png'
$manifest = Join-Path $catalog 'Contents.json'
if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { throw "AppIcon source not found: $Source" }
$sourceFull = (Resolve-Path -LiteralPath $Source).Path
if (-not [String]::Equals([IO.Path]::GetExtension($sourceFull), '.png', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Source must be PNG.'
}
$bytes = [IO.File]::ReadAllBytes($sourceFull)
$signature = [byte[]](137,80,78,71,13,10,26,10)
if ($bytes.Length -lt 33) { throw 'Invalid/truncated PNG.' }
for ($i=0; $i -lt 8; $i++) { if ($bytes[$i] -ne $signature[$i]) { throw 'Not a PNG.' } }
$bitmap = $null
try {
  $bitmap = New-Object System.Drawing.Bitmap($sourceFull)
  if ($bitmap.Width -ne 1024 -or $bitmap.Height -ne 1024) {
    throw "Icon must be 1024x1024, actual $($bitmap.Width)x$($bitmap.Height). No automatic resizing."
  }
  # Scan every pixel: a fully opaque image has no transparent pixel, including all edges.
  for ($y=0; $y -lt 1024; $y++) {
    for ($x=0; $x -lt 1024; $x++) {
      if ($bitmap.GetPixel($x,$y).A -ne 255) {
        throw "Non-opaque pixel at ($x,$y); release icon must have no transparency."
      }
    }
  }
}
finally { if ($bitmap) { $bitmap.Dispose() } }
# Checks dimensions and opacity only. Artistic full-bleed (no intentional white/solid padding)
# requires a human visual check; never crop, regenerate, or stretch the source.
New-Item -Path $catalog -ItemType Directory -Force | Out-Null
Copy-Item -LiteralPath $sourceFull -Destination $target -Force
$contents = @'
{
  "images": [
    {
      "filename": "AppIcon-1024.png",
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024"
    }
  ],
  "info": { "author": "xcode", "version": 1 }
}
'@
[IO.File]::WriteAllText($manifest, $contents, (New-Object System.Text.UTF8Encoding($false)))
$sourceHash = (Get-FileHash -LiteralPath $sourceFull -Algorithm SHA256).Hash.ToLowerInvariant()
$destHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sourceHash -ne $destHash) { throw 'SHA256 mismatch after copy.' }
Write-Host "PASS: 1024x1024 PNG, pixel alpha 255 everywhere, source/destination SHA256 match."
Write-Host "SOURCE: $sourceFull"
Write-Host "DEST: $target"
Write-Host "SHA256: $destHash"
Write-Host 'HUMAN CHECK: Open source and ensure design fills all edges without unintended padding; this cannot be guaranteed by size/alpha checks.'
Write-Host 'NEXT: git add fp3-manabi-sprint/ios/Assets.xcassets/AppIcon.appiconset && run FP3 Preflight before Release.'
