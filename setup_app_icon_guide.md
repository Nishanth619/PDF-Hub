# App Icon Setup Guide for PDF Hub

## Overview
This guide will help you set up a custom app icon for your PDF Hub application. The app icon is what users see on their device's home screen when they install your application.

## Requirements
1. A high-quality PNG image (at least 1024x1024 pixels recommended)
2. Your source image file: "G:\New folder (3)\1logo.png"

## Steps to Set Up the App Icon

### 1. Prepare Your Icon File
- Make sure your icon is a square image
- Recommended size: 1024x1024 pixels
- Format: PNG with transparency (if needed)

### 2. Copy the Icon to the Project
Copy your icon file to the correct location in your project:

1. Navigate to: `G:\ilovepdf\ilovepdf_flutter\assets\icons\`
2. Copy your file from "G:\New folder (3)\1logo.png"
3. Rename it to `app_icon.png`

### 3. Generate App Icons
After copying the file, run the following command in your project root directory:

```bash
flutter pub run flutter_launcher_icons:main
```

This command will:
- Generate all required icon sizes for Android
- Create adaptive icons for newer Android versions
- Update the necessary configuration files

### 4. Verify the Setup
After running the command, you should see output indicating that icons were generated successfully.

### 5. Test the Icon
Build and run your app to verify the new icon appears correctly:

```bash
flutter build apk --debug
```

## Android Icon Specifications

### Standard Icons
- mdpi: 48x48 pixels
- hdpi: 72x72 pixels
- xhdpi: 96x96 pixels
- xxhdpi: 144x144 pixels
- xxxhdpi: 192x192 pixels

### Google Play Store
- 512x512 pixels

## Troubleshooting

### If the icon doesn't update:
1. Clean your project:
   ```bash
   flutter clean
   flutter pub get
   ```

2. Delete the build folder:
   ```bash
   rm -rf build/
   ```

3. Regenerate icons:
   ```bash
   flutter pub run flutter_launcher_icons:main
   ```

### If you get errors:
1. Make sure your source image is properly formatted
2. Check that the file path is correct
3. Verify the flutter_launcher_icons package is properly installed

## Additional Notes
- The icon setup is configured in `pubspec.yaml` under the `flutter_launcher_icons` section
- For Android, both standard and adaptive icons are generated
- The adaptive icon background color is set to #4A80F0 (blue)
- Make sure to keep a backup of your original icon file

## Next Steps
After setting up your app icon:
1. Build a release version of your app
2. Test on different devices to ensure the icon displays correctly
3. Upload to Google Play Store with your new icon

For any issues, refer to the flutter_launcher_icons documentation:
https://pub.dev/packages/flutter_launcher_icons