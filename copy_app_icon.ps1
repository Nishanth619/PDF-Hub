# PowerShell script to copy app icon
# This script attempts to copy your app icon from the specified location

Write-Host "PDF Hub App Icon Setup Script" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green
Write-Host ""

# Define source and destination paths
$sourcePath = "G:\New folder (3)\1logo.png"
$destinationPath = "G:\ilovepdf\ilovepdf_flutter\assets\icons\app_icon.png"

Write-Host "Checking if source file exists..." -ForegroundColor Yellow

if (Test-Path $sourcePath) {
    Write-Host "Source file found!" -ForegroundColor Green
    
    try {
        Write-Host "Copying file to project directory..." -ForegroundColor Yellow
        Copy-Item -Path $sourcePath -Destination $destinationPath -Force
        Write-Host "File copied successfully!" -ForegroundColor Green
        Write-Host "Destination: $destinationPath" -ForegroundColor Cyan
        
        Write-Host ""
        Write-Host "Now generating app icons..." -ForegroundColor Yellow
        flutter pub run flutter_launcher_icons:main
        
        Write-Host ""
        Write-Host "App icon setup completed successfully!" -ForegroundColor Green
        Write-Host "You can now build your app with the new icon." -ForegroundColor Cyan
    }
    catch {
        Write-Host "Error copying file: $_" -ForegroundColor Red
        Write-Host "Please manually copy the file from $sourcePath to $destinationPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "Source file not found at: $sourcePath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please:" -ForegroundColor Yellow
    Write-Host "1. Make sure your logo file exists at the specified location" -ForegroundColor Yellow
    Write-Host "2. Manually copy it to: $destinationPath" -ForegroundColor Yellow
    Write-Host "3. Run: flutter pub run flutter_launcher_icons:main" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")