@echo off
echo PDF Hub Release Build Script
echo ===========================

REM Check if Flutter is installed
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Flutter is not installed or not in PATH
    pause
    exit /b 1
)

echo 1. Cleaning previous builds...
flutter clean
if %errorlevel% neq 0 (
    echo Error: Failed to clean project
    pause
    exit /b 1
)

echo 2. Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo Error: Failed to get dependencies
    pause
    exit /b 1
)

echo 3. Running tests...
flutter test
if %errorlevel% neq 0 (
    echo Error: Tests failed
    pause
    exit /b 1
)

echo 4. Building release APK...
flutter build apk --release
if %errorlevel% neq 0 (
    echo Error: Failed to build APK
    pause
    exit /b 1
)

echo 5. Building App Bundle for Play Store...
flutter build appbundle --release
if %errorlevel% neq 0 (
    echo Error: Failed to build App Bundle
    pause
    exit /b 1
)

echo.
echo Build completed successfully!
echo.
echo Output files:
echo - APK: build\app\outputs\flutter-apk\app-release.apk
echo - App Bundle: build\app\outputs\bundle\release\app-release.aab
echo.
echo Next steps:
echo 1. Test the APK on your device
echo 2. Upload the App Bundle to Google Play Console
echo 3. Update version numbers for next release
echo.
pause