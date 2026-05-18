# PDF Hub - Play Store Publication Guide

## Overview
This document provides instructions for publishing PDF Hub to the Google Play Store.

## Prerequisites
1. Google Play Developer Account
2. Signing key for release builds
3. Play Store assets (screenshots, graphics, descriptions)

## Build Configuration

### Version Information
- Current version: 1.0.0
- Build number: 1
- Version code: 1

### Signing Configuration
Before publishing, you must create your own signing key:

1. Generate a signing key:
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Update `android/key.properties` with your key information:
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=upload
storeFile=../app/upload-keystore.jks
```

3. Update `android/app/build.gradle` with release signing config:
```kotlin
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
```

## Required Assets

### App Icons
- Adaptive icon (foreground and background)
- Various density versions (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)

### Play Store Graphics
Create the following assets:
- Feature graphic (1024x500)
- Promo graphic (180x120)
- Screenshots (phone and tablet)

### Screenshots
Include screenshots showing:
1. Home screen with all tools
2. PDF conversion process
3. File management
4. Settings and preferences

## Content Rating
The app should be rated for all audiences since it:
- Does not contain violent content
- Does not contain sexual content
- Does not contain mature/hateful content
- Does not enable gambling
- Does not enable illegal activities

## Permissions Declaration
The following permissions require declaration in the Play Store:

### Required Permissions
- INTERNET: For accessing online services
- CAMERA: For capturing images to convert to PDF
- READ_EXTERNAL_STORAGE: For accessing files to process
- WRITE_EXTERNAL_STORAGE: For saving processed files

### Optional Permissions
- POST_NOTIFICATIONS: For showing processing status
- RECEIVE_BOOT_COMPLETED: For scheduling notifications

## App Content Guidelines

### Compliance
- All functionality works as described
- No misleading promotional claims
- No prohibited content
- Proper handling of user data
- Compliance with privacy policy

### Target API Level
- Target SDK: 34 (Android 14)
- Minimum SDK: 21 (Android 5.0)

## Testing Checklist

### Pre-Publication Testing
- [ ] App installs and launches successfully
- [ ] All core features work correctly
- [ ] No crashes or performance issues
- [ ] Permissions work properly
- [ ] File processing completes successfully
- [ ] Notifications display correctly
- [ ] App handles errors gracefully

### Device Testing
- [ ] Phone (various screen sizes)
- [ ] Tablet
- [ ] Different Android versions (5.0+)

## Publication Steps

### 1. Create Release Build
```bash
flutter build appbundle --release
```

### 2. Upload to Play Console
1. Sign in to Google Play Console
2. Select your app
3. Create new release
4. Upload app bundle
5. Fill in release notes
6. Review and rollout

### 3. Configure Store Listing
1. App name: PDF Hub
2. Short description: Professional PDF Processing Application
3. Full description: See play_store_description.txt
4. Upload graphics and screenshots
5. Set content rating
6. Configure pricing and distribution

### 4. Configure Developer Website & AdMob Verification
This step is **CRUCIAL** for AdMob ad serving verification.

#### Developer Website Setup
1. Your developer website is hosted at: `https://nishanth619.github.io`
2. The `app-ads.txt` file is live at: `https://nishanth619.github.io/app-ads.txt`
3. Content of app-ads.txt:
   ```
   google.com, pub-4025737666505759, DIRECT, f08c47fec0942fa0
   ```

#### In Play Console
1. Go to **Store Settings** → **Contact details**
2. Set **Developer Website** to: `https://nishanth619.github.io`
3. This URL **must match** where your app-ads.txt is hosted

#### Verification Timeline
- AdMob will crawl your developer website within **24-48 hours** after app publication
- The app-ads.txt file helps verify you're authorized to show ads
- This prevents ad fraud and ensures proper ad serving

## Post-Publication

### Monitoring
- Monitor crash reports
- Track user reviews
- Check download statistics
- Update app based on feedback

### Updates
- Regular updates for bug fixes
- New features based on user requests
- Compatibility updates for new Android versions
- Security patches as needed

## Support
For support inquiries, contact:
- Email: support@pdfhub.app
- Website: www.pdfhub.app

## Legal
- Privacy Policy: See privacy_policy.txt
- Terms of Service: See terms_of_service.txt
- Copyright: 2025 PDF Hub. All rights reserved.