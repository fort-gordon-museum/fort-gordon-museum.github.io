param([string]$src, [string]$dst, [int]$width, [int]$quality)
Add-Type -AssemblyName System.Drawing
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [long]$quality)
New-Item -ItemType Directory -Force $dst | Out-Null
Get-ChildItem $src -Filter 'p*.jpg' | ForEach-Object {
  $img = [System.Drawing.Image]::FromFile($_.FullName)
  $w = [Math]::Min($width, $img.Width); $h = [int]($img.Height * $w / $img.Width)
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'HighQuality'; $g.PixelOffsetMode = 'HighQuality'
  $g.DrawImage($img, 0, 0, $w, $h)
  $n = [int]($_.BaseName.Substring(1))
  $bmp.Save((Join-Path $dst ('p{0:D2}.jpg' -f $n)), $codec, $ep)
  $g.Dispose(); $bmp.Dispose(); $img.Dispose()
}
