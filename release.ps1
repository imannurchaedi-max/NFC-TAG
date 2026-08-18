# ============================================================
# NFC RW - Auto Build & Release Script
# Cara pakai: .\release.ps1 -Version "1.0.6"
# ============================================================
param(
    [Parameter(Mandatory=$true)]
    [string]$Version
)

$APK_NAME = "NFC_RW.apk"
$VERSION_JSON = "release\version.json"
$APK_SOURCE = "build\app\outputs\flutter-apk\app-release.apk"
$APK_DEST = "release\$APK_NAME"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  NFC RW Release Script - v$Version" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Update pubspec.yaml version
Write-Host "[1/4] Updating pubspec.yaml version..." -ForegroundColor Yellow
$pubspec = Get-Content "pubspec.yaml" -Raw
$null = $pubspec -match 'version: (\d+\.\d+\.\d+)\+(\d+)'
$buildNum = [int]$Matches[2] + 1
$pubspec = $pubspec -replace 'version: \d+\.\d+\.\d+\+\d+', "version: $Version+$buildNum"
Set-Content "pubspec.yaml" $pubspec
Write-Host "   Version set to $Version+$buildNum" -ForegroundColor Green

# Step 2: Build APK
Write-Host "`n[2/4] Building APK (flutter clean + build)..." -ForegroundColor Yellow
flutter clean | Out-Null
flutter build apk
if ($LASTEXITCODE -ne 0) { Write-Host "BUILD FAILED!" -ForegroundColor Red; exit 1 }
Write-Host "   Build successful!" -ForegroundColor Green

# Step 3: Copy APK to release folder
Write-Host "`n[3/4] Copying APK to release folder..." -ForegroundColor Yellow
Copy-Item $APK_SOURCE -Destination $APK_DEST -Force
Write-Host "   Copied to $APK_DEST" -ForegroundColor Green

# Step 4: Update version.json
Write-Host "`n[4/4] Updating version.json..." -ForegroundColor Yellow
$versionJson = @{
    version = $Version
    apk_url = "https://raw.githubusercontent.com/imannurchaedi-max/NFC-TAG/main/release/NFC_RW.apk"
} | ConvertTo-Json
Set-Content $VERSION_JSON $versionJson
Write-Host "   version.json updated!" -ForegroundColor Green

# Git commit & push
Write-Host "`nCommitting and pushing to GitHub..." -ForegroundColor Yellow
git add .
git commit -m "release: v$Version"
git push origin main

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  RELEASE v$Version COMPLETE!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
