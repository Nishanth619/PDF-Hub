# PDF Hub - Future Updates Plan

## Version 1.1.0 - Android 15 Compatibility

### Priority: Medium
### Target: Before SDK 35 release

---

## Issues to Fix (from Google Play Pre-launch Report)

### 1. Edge-to-Edge Display (Android 15)
**Warning:** Edge-to-edge may not display for all users

**Description:**
From Android 15, apps targeting SDK 35 will display edge-to-edge by default. Apps should handle insets to make sure the app displays correctly.

**Solution:**
- Add `enableEdgeToEdge()` call in MainActivity
- Handle window insets properly in Flutter
- Test on Android 15 devices/emulator

**Files to update:**
- `android/app/src/main/kotlin/.../MainActivity.kt`
- Potentially Flutter widgets that need inset handling

---

### 2. Deprecated Edge-to-Edge APIs
**Warning:** Your app uses deprecated APIs or parameters for edge-to-edge

**Description:**
One or more of the APIs used for edge-to-edge and window display have been deprecated in Android 15.

**Solution:**
- Migrate away from deprecated APIs
- Update to new recommended APIs
- Test thoroughly after migration

---

### 3. Large Screen Device Support (Android 16)
**Warning:** Remove resizability and orientation restrictions

**Description:**
From Android 16, Android will ignore resizability and orientation restrictions for large screen devices (foldables, tablets).

**Solution:**
- Remove fixed orientation restrictions from AndroidManifest.xml
- Make layouts responsive for all screen sizes
- Test on tablets and foldables

**Files to update:**
- `android/app/src/main/AndroidManifest.xml` - Remove `android:screenOrientation` if set
- Flutter layouts - Ensure responsive design

---

## Timeline

| Update | Priority | Target Date |
|--------|----------|-------------|
| Edge-to-edge fix | Medium | Q1 2025 |
| Deprecated APIs | Medium | Q1 2025 |
| Large screen support | Low | Before Android 16 |

---

## Notes

- Current app version: 1.0.0
- Current target SDK: 34 (Android 14)
- These issues will become mandatory when targeting SDK 35
- App currently works fine - these are future-proofing warnings

---

## Created
- Date: December 21, 2024
- Source: Google Play Console Pre-launch Report
