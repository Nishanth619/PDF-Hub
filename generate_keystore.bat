@echo off
echo Generating upload keystore for PDF Hub...
echo ======================================

cd android\app

echo Running keytool to generate keystore...
echo You will be prompted to enter passwords and information:
echo - Keystore password: Nish@619
echo - Key password: Nish@619
echo - First and last name: PDF Hub
echo - Organizational unit: Development
echo - Organization: PDF Hub
echo - City: [your city]
echo - State: [your state]
echo - Country: [two-letter country code]
echo.

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

if %errorlevel% equ 0 (
    echo.
    echo Keystore generated successfully!
    echo File location: android\app\upload-keystore.jks
    echo.
    echo Next steps:
    echo 1. Make sure key.properties file exists with correct values
    echo 2. Build your release app bundle with: flutter build appbundle --release
    echo.
) else (
    echo.
    echo Error generating keystore. Please check the error messages above.
    echo.
)

pause