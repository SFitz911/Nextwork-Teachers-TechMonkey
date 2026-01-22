# Upload teacher images to VAST instance
# Run this from: C:\Users\Sean Fitz\OneDrive\Pictures\Nextworks\Nextwork Teachers

$sourceDir = "C:\Users\Sean Fitz\OneDrive\Pictures\Nextworks\Nextwork Teachers"
$port = 41428
$serverHost = "50.217.254.161"
$remotePath = "~/Nextwork-Teachers-TechMonkey/services/animation/avatars/"

Write-Host "Uploading teacher images to VAST instance..." -ForegroundColor Green
Write-Host ""

# Teacher A = Maya (using Maya.png - the first one)
Write-Host "Uploading Teacher A (Maya)..." -ForegroundColor Yellow
scp -P $port "$sourceDir\Maya.png" "root@${serverHost}:${remotePath}teacher_a.png"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Teacher A uploaded" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to upload Teacher A" -ForegroundColor Red
}

# Teacher B = Maximus
Write-Host "Uploading Teacher B (Maximus)..." -ForegroundColor Yellow
scp -P $port "$sourceDir\Maximus.jpg" "root@${serverHost}:${remotePath}teacher_b.jpg"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Teacher B uploaded" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to upload Teacher B" -ForegroundColor Red
}

# Teacher C = Krishna
Write-Host "Uploading Teacher C (Krishna)..." -ForegroundColor Yellow
scp -P $port "$sourceDir\krishna.png" "root@${serverHost}:${remotePath}teacher_c.png"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Teacher C uploaded" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to upload Teacher C" -ForegroundColor Red
}

# Teacher D = TechMonkey Steve
Write-Host "Uploading Teacher D (TechMonkey Steve)..." -ForegroundColor Yellow
scp -P $port "$sourceDir\TechMonkey Steve.png" "root@${serverHost}:${remotePath}teacher_d.png"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Teacher D uploaded" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to upload Teacher D" -ForegroundColor Red
}

# Teacher E = Pano Bieber
Write-Host "Uploading Teacher E (Pano Bieber)..." -ForegroundColor Yellow
scp -P $port "$sourceDir\Pano Bieber.png" "root@${serverHost}:${remotePath}teacher_e.png"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Teacher E uploaded" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to upload Teacher E" -ForegroundColor Red
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Upload complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: Some images are PNG format. The animation service supports both .jpg and .png" -ForegroundColor Yellow
Write-Host "If you need to convert them to .jpg, you can do so on the VAST instance." -ForegroundColor Yellow
