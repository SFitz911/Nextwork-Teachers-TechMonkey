# Upload Teacher Images to VAST Instance
# Usage: .\upload-teacher-images.ps1

$VAST_SSH_PORT = "11889"
$VAST_SSH_HOST = "ssh1.vast.ai"
$VAST_SSH_USER = "root"
$PROJECT_DIR = "~/Nextwork-Teachers-TechMonkey"
$SOURCE_DIR = "Nextwork-Teachers"
$TARGET_DIR = "$PROJECT_DIR/Nextwork-Teachers"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Uploading Teacher Images to VAST" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if source directory exists
if (-not (Test-Path $SOURCE_DIR)) {
    Write-Host "❌ Source directory not found: $SOURCE_DIR" -ForegroundColor Red
    exit 1
}

Write-Host "Uploading images..." -ForegroundColor Yellow
Write-Host ""

# Upload each image
$images = @(
    @{Source = "Maya.png"; Target = "Maya.png"},
    @{Source = "Maximus.png"; Target = "Maximus.png"},
    @{Source = "krishna.png"; Target = "krishna.png"},
    @{Source = "TechMonkey Steve.png"; Target = "TechMonkey Steve.png"},
    @{Source = "Pano Bieber.png"; Target = "Pano Bieber.png"}
)

foreach ($img in $images) {
    $sourcePath = Join-Path $SOURCE_DIR $img.Source
    $targetPath = "$TARGET_DIR/$($img.Target)"
    
    if (Test-Path $sourcePath) {
        Write-Host "Uploading $($img.Source)..." -ForegroundColor White
        scp -P $VAST_SSH_PORT "$sourcePath" "${VAST_SSH_USER}@${VAST_SSH_HOST}:${targetPath}"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Uploaded $($img.Source)" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to upload $($img.Source)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️  File not found: $sourcePath" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "✅ Upload complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: On VAST terminal, run:" -ForegroundColor Yellow
Write-Host "  bash scripts/fix_avatar_images.sh" -ForegroundColor White
Write-Host ""
