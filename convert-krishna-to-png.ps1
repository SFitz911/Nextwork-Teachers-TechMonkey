# PowerShell script to convert Krishna's image from JPG to PNG
# This will download, convert, and re-upload the image

$VastPort = 41428
$VastHost = "50.217.254.161"
$VastUser = "root"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Converting Krishna's Image to PNG" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Download the current image from VAST
Write-Host "Downloading current Krishna image from VAST..." -ForegroundColor Yellow
scp -P $VastPort ${VastUser}@${VastHost}:~/Nextwork-Teachers-TechMonkey/services/animation/avatars/teacher_c.* ./krishna_temp.*

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error downloading image. Trying to find the file..." -ForegroundColor Red
    exit 1
}

# Find which file was downloaded
$sourceFile = Get-ChildItem -Path . -Filter "krishna_temp.*" | Select-Object -First 1

if (-not $sourceFile) {
    Write-Host "Could not find downloaded file" -ForegroundColor Red
    exit 1
}

Write-Host "Found file: $($sourceFile.Name)" -ForegroundColor Green

# Step 2: Convert to PNG using PowerShell (requires .NET)
Write-Host "Converting to PNG..." -ForegroundColor Yellow

try {
    # Load the image
    $image = [System.Drawing.Image]::FromFile($sourceFile.FullName)
    
    # Create PNG version
    $pngPath = ".\teacher_c.png"
    $image.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $image.Dispose()
    
    Write-Host "Converted to: $pngPath" -ForegroundColor Green
    
    # Step 3: Upload the PNG version
    Write-Host "Uploading PNG version to VAST..." -ForegroundColor Yellow
    scp -P $VastPort $pngPath ${VastUser}@${VastHost}:~/Nextwork-Teachers-TechMonkey/services/animation/avatars/teacher_c.png
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully uploaded teacher_c.png!" -ForegroundColor Green
        
        # Step 4: Remove old JPG file on VAST (if it exists)
        Write-Host "Removing old JPG file from VAST..." -ForegroundColor Yellow
        ssh -p $VastPort ${VastUser}@${VastHost} "rm -f ~/Nextwork-Teachers-TechMonkey/services/animation/avatars/teacher_c.jpg"
        
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host "Conversion complete!" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Krishna's image is now in PNG format." -ForegroundColor Cyan
        Write-Host "You may need to refresh the frontend to see the update." -ForegroundColor Yellow
    } else {
        Write-Host "Error uploading PNG file" -ForegroundColor Red
    }
    
    # Cleanup local files
    Remove-Item $sourceFile.FullName -ErrorAction SilentlyContinue
    Remove-Item $pngPath -ErrorAction SilentlyContinue
    
} catch {
    Write-Host "Error converting image: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative: Convert manually using an image editor or online tool" -ForegroundColor Yellow
    Write-Host "Then upload using: .\upload-teachers.ps1" -ForegroundColor Yellow
}
