Add-Type -AssemblyName System.Drawing
$root = 'D:\electrical_shop_manager'
$brandDir = Join-Path $root 'assets\brand'
New-Item -ItemType Directory -Path $brandDir -Force | Out-Null

$forest = [System.Drawing.ColorTranslator]::FromHtml('#24352F')
$cream = [System.Drawing.ColorTranslator]::FromHtml('#F4F1E8')
$gold = [System.Drawing.ColorTranslator]::FromHtml('#D5A25F')
$muted = [System.Drawing.ColorTranslator]::FromHtml('#78847B')

function Draw-Mark {
    param([System.Drawing.Graphics]$Graphics,[single]$X,[single]$Y,[single]$Size,[System.Drawing.Color]$Foreground,[System.Drawing.Color]$Accent)
    $matrix = [System.Drawing.Drawing2D.Matrix]::new([single]($Size / 1024),0,0,[single]($Size / 1024),$X,$Y)
    $oldTransform = $Graphics.Transform
    $Graphics.Transform = $matrix
    $matrix.Dispose()
    $main = [System.Drawing.SolidBrush]::new($Foreground)
    $trim = [System.Drawing.SolidBrush]::new($Accent)
    $bulb = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $bulb.StartFigure()
    $bulb.AddBezier([System.Drawing.PointF]::new(512,96),[System.Drawing.PointF]::new(710,96),[System.Drawing.PointF]::new(842,248),[System.Drawing.PointF]::new(820,420))
    $bulb.AddBezier([System.Drawing.PointF]::new(820,420),[System.Drawing.PointF]::new(808,520),[System.Drawing.PointF]::new(720,572),[System.Drawing.PointF]::new(668,640))
    $bulb.AddLine(668,640,620,700)
    $bulb.AddLine(620,700,620,742)
    $bulb.AddLine(620,742,404,742)
    $bulb.AddLine(404,742,404,700)
    $bulb.AddLine(404,700,356,640)
    $bulb.AddBezier([System.Drawing.PointF]::new(356,640),[System.Drawing.PointF]::new(304,572),[System.Drawing.PointF]::new(216,520),[System.Drawing.PointF]::new(204,420))
    $bulb.AddBezier([System.Drawing.PointF]::new(204,420),[System.Drawing.PointF]::new(182,248),[System.Drawing.PointF]::new(314,96),[System.Drawing.PointF]::new(512,96))
    $Graphics.FillPath($main,$bulb)
    $bulb.Dispose()
    $rayPen = [System.Drawing.Pen]::new($Accent,34)
    $rayPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $rayPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $Graphics.DrawLine($rayPen,512,18,512,62)
    $Graphics.DrawLine($rayPen,260,116,300,156)
    $Graphics.DrawLine($rayPen,764,116,724,156)
    $Graphics.DrawLine($rayPen,148,352,202,352)
    $Graphics.DrawLine($rayPen,876,352,822,352)
    $filamentPen = [System.Drawing.Pen]::new($Accent,30)
    $filamentPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $filamentPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $Graphics.DrawLine($filamentPen,414,516,512,408)
    $Graphics.DrawLine($filamentPen,512,408,610,516)
    $Graphics.DrawLine($filamentPen,414,516,610,516)
    $basePen = [System.Drawing.Pen]::new($Foreground,34)
    $basePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $basePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $Graphics.DrawLine($basePen,414,786,610,786)
    $Graphics.DrawLine($basePen,432,836,592,836)
    $Graphics.DrawLine($basePen,456,886,568,886)
    $rayPen.Dispose(); $filamentPen.Dispose(); $basePen.Dispose()
    $main.Dispose(); $trim.Dispose()
    $Graphics.Transform = $oldTransform
    $oldTransform.Dispose()
}
function New-LogoBitmap {
    param([System.Drawing.Color]$Foreground,[System.Drawing.Color]$Accent,[System.Drawing.Color]$Subtitle)
    $bitmap = [System.Drawing.Bitmap]::new(1540,400,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.Clear([System.Drawing.Color]::Transparent)
    Draw-Mark -Graphics $graphics -X 22 -Y 20 -Size 360 -Foreground $Foreground -Accent $Accent
    $titleFont = [System.Drawing.Font]::new('Segoe UI',98,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
    $subFont = [System.Drawing.Font]::new('Segoe UI',42,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
    $tagFont = [System.Drawing.Font]::new('Segoe UI',28,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
    $titleBrush = [System.Drawing.SolidBrush]::new($Foreground)
    $accentBrush = [System.Drawing.SolidBrush]::new($Accent)
    $subtitleBrush = [System.Drawing.SolidBrush]::new($Subtitle)
    $graphics.DrawString('NANAKAY',$titleFont,$titleBrush,426,58)
    $graphics.DrawString('ELECTRICAL SHOP',$subFont,$accentBrush,432,184)
    $graphics.DrawString('STOCK  ·  SALES  ·  FINANCE',$tagFont,$subtitleBrush,435,258)
    $titleFont.Dispose(); $subFont.Dispose(); $tagFont.Dispose()
    $titleBrush.Dispose(); $accentBrush.Dispose(); $subtitleBrush.Dispose()
    $graphics.Dispose()
    return $bitmap
}

function Save-ResizedPng {
    param([string]$SourcePath,[string]$DestinationPath,[int]$Width,[int]$Height)
    $source = [System.Drawing.Image]::FromFile($SourcePath)
    $bitmap = [System.Drawing.Bitmap]::new($Width,$Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.DrawImage($source,[System.Drawing.Rectangle]::new(0,0,$Width,$Height))
    New-Item -ItemType Directory -Path (Split-Path $DestinationPath) -Force | Out-Null
    $bitmap.Save($DestinationPath,[System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose(); $source.Dispose()
}

foreach ($variant in @(
    @{Name='nanakay_mark_light.png'; Foreground=$cream},
    @{Name='nanakay_mark_dark.png'; Foreground=$forest}
)) {
    $bitmap = [System.Drawing.Bitmap]::new(1024,1024,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)
    Draw-Mark -Graphics $graphics -X 0 -Y 0 -Size 1024 -Foreground $variant.Foreground -Accent $gold
    $bitmap.Save((Join-Path $brandDir $variant.Name),[System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()
}

$icon = [System.Drawing.Bitmap]::new(1024,1024,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$iconGraphics = [System.Drawing.Graphics]::FromImage($icon)
$iconGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$iconGraphics.Clear($forest)
Draw-Mark -Graphics $iconGraphics -X 0 -Y 0 -Size 1024 -Foreground $cream -Accent $gold
$iconPath = Join-Path $brandDir 'nanakay_app_icon.png'
$icon.Save($iconPath,[System.Drawing.Imaging.ImageFormat]::Png)
$iconGraphics.Dispose(); $icon.Dispose()

$logo = New-LogoBitmap -Foreground $forest -Accent $gold -Subtitle $muted
$logo.Save((Join-Path $brandDir 'nanakay_logo.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$logo.Dispose()
$preview = [System.Drawing.Bitmap]::new(1540,400,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$previewGraphics = [System.Drawing.Graphics]::FromImage($preview)
$previewGraphics.Clear($cream)
$previewSource = [System.Drawing.Image]::FromFile((Join-Path $brandDir 'nanakay_logo.png'))
$previewGraphics.DrawImage($previewSource,0,0,1540,400)
$previewSource.Dispose(); $previewGraphics.Dispose()
$preview.Save((Join-Path $brandDir 'nanakay_logo_preview.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$preview.Dispose()
$splashLogo = New-LogoBitmap -Foreground $cream -Accent $gold -Subtitle $cream
$splashLogo.Save((Join-Path $brandDir 'nanakay_splash_branding.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$splashLogo.Dispose()

$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="1540" height="400" viewBox="0 0 1540 400">
  <g transform="translate(22 20) scale(.3515625)">
    <path fill="#24352F" d="M512 96c198 0 330 152 308 324-12 100-100 152-152 220l-48 60v42H404v-42l-48-60c-52-68-140-120-152-220C182 248 314 96 512 96z"/>
    <g fill="none" stroke="#D5A25F" stroke-width="34" stroke-linecap="round"><path d="M512 18v44M260 116l40 40m464-40-40 40M148 352h54m674 0h-54M414 516l98-108 98 108H414z"/></g>
    <g fill="none" stroke="#24352F" stroke-width="34" stroke-linecap="round"><path d="M414 786h196m-178 50h160m-136 50h112"/></g>
  </g>
  <text x="426" y="158" fill="#24352F" font-family="Segoe UI, Arial, sans-serif" font-size="98" font-weight="700" letter-spacing="4">NANAKAY</text>
  <text x="432" y="232" fill="#D5A25F" font-family="Segoe UI, Arial, sans-serif" font-size="42" font-weight="700" letter-spacing="1.5">ELECTRICAL SHOP</text>
  <text x="435" y="302" fill="#78847B" font-family="Segoe UI, Arial, sans-serif" font-size="28" letter-spacing="1">STOCK · SALES · FINANCE</text>
</svg>
"@
[System.IO.File]::WriteAllText((Join-Path $brandDir 'nanakay_logo.svg'),$svg,[System.Text.UTF8Encoding]::new($false))

$androidSizes = @{'mipmap-mdpi'=48;'mipmap-hdpi'=72;'mipmap-xhdpi'=96;'mipmap-xxhdpi'=144;'mipmap-xxxhdpi'=192}
foreach ($entry in $androidSizes.GetEnumerator()) {
    Save-ResizedPng -SourcePath $iconPath -DestinationPath (Join-Path $root "android\app\src\main\res\$($entry.Key)\ic_launcher.png") -Width $entry.Value -Height $entry.Value
}
$catalogPath = Join-Path $root 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Contents.json'
$catalog = Get-Content -Raw $catalogPath | ConvertFrom-Json
foreach ($image in $catalog.images) {
    if ($image.filename) {
        $dimensions = $image.size -split 'x'
        $pixels = [int][Math]::Round(([double]$dimensions[0]) * ([double]($image.scale -replace 'x','')))
        Save-ResizedPng -SourcePath $iconPath -DestinationPath (Join-Path (Split-Path $catalogPath) $image.filename) -Width $pixels -Height $pixels
    }
}
foreach ($size in @(192,512)) {
    Save-ResizedPng -SourcePath $iconPath -DestinationPath (Join-Path $root "web\icons\Icon-$size.png") -Width $size -Height $size
    Save-ResizedPng -SourcePath $iconPath -DestinationPath (Join-Path $root "web\icons\Icon-maskable-$size.png") -Width $size -Height $size
}
Save-ResizedPng -SourcePath $iconPath -DestinationPath (Join-Path $root 'web\favicon.png') -Width 32 -Height 32
Write-Output 'Created NanaKay logo, icon, iOS/Android launcher images, and web icons.'