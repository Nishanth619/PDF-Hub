@echo off
title PDF Hub App Icon Setup

echo PDF Hub App Icon Setup Script
echo ============================

set sourcePath=G:\New folder (3)\1logo.png
set destinationPath=G:\ilovepdf\ilovepdf_flutter\assets\icons\app_icon.png

echo Checking if source file exists...
if exist "%sourcePath%" (
    echo Source file found!
    
    echo Copying file to project directory...
    copy "%sourcePath%" "%destinationPath%"
    
    if %errorlevel% equ 0 (
        echo File copied successfully!
        echo Destination: %destinationPath%
        
        echo.
        echo Now generating app icons...
        flutter pub run flutter_launcher_icons:main
        
        echo.
        echo App icon setup completed successfully!
        echo You can now build your app with the new icon.
    ) else (
        echo Error copying file.
        echo Please manually copy the file from %sourcePath% to %destinationPath%
    )
) else (
    echo Source file not found at: %sourcePath%
    echo.
    echo Please:
    echo 1. Make sure your logo file exists at the specified location
    echo 2. Manually copy it to: %destinationPath%
    echo 3. Run: flutter pub run flutter_launcher_icons:main
)

echo.
pause