import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilovepdf_flutter/services/notification_service.dart';

class AppSettings with ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _languageKey = 'language';
  static const String _defaultSaveLocationKey = 'default_save_location';
  static const String _defaultQualityKey = 'default_quality';
  static const String _autoSaveToHistoryKey = 'auto_save_to_history';
  static const String _enableImageEnhancementKey = 'enable_image_enhancement';
  static const String _defaultDpiKey = 'default_dpi';
  static const String _enableNotificationsKey = 'enable_notifications';
  static const String _termsAcceptedKey = 'terms_accepted';
  static const String _userNameKey = 'user_name'; // New key for user name

  // Default values
  static const ThemeMode _defaultThemeModeValue = ThemeMode.system;
  static const String _defaultLanguageValue = 'en';
  static const String _defaultSaveLocationValue = 'Documents';
  static const int _defaultQualityValue = 75; // 1-100
  static const bool _defaultAutoSaveToHistoryValue = true;
  static const bool _defaultEnableImageEnhancementValue = true;
  static const int _defaultDpiValue = 150;
  static const bool _defaultEnableNotificationsValue = true;
  static const bool _defaultTermsAcceptedValue = false;
  static const String _defaultUserNameValue = ''; // Default empty name

  // Current values
  ThemeMode _themeMode = _defaultThemeModeValue;
  String _language = _defaultLanguageValue;
  String _defaultSaveLocation = _defaultSaveLocationValue;
  int _defaultQuality = _defaultQualityValue;
  bool _autoSaveToHistory = _defaultAutoSaveToHistoryValue;
  bool _enableImageEnhancement = _defaultEnableImageEnhancementValue;
  int _defaultDpi = _defaultDpiValue;
  bool _enableNotifications = _defaultEnableNotificationsValue;
  bool _termsAccepted = _defaultTermsAcceptedValue;
  String _userName = _defaultUserNameValue; // New field for user name

  // Getters
  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  String get defaultSaveLocation => _defaultSaveLocation;
  int get defaultQuality => _defaultQuality;
  bool get autoSaveToHistory => _autoSaveToHistory;
  bool get enableImageEnhancement => _enableImageEnhancement;
  int get defaultDpi => _defaultDpi;
  bool get enableNotifications => _enableNotifications;
  bool get termsAccepted => _termsAccepted;
  String get userName => _userName; // Getter for user name

  // Setters with persistence
  set themeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    _saveSettings();
  }

  set language(String language) {
    _language = language;
    notifyListeners();
    _saveSettings();
  }

  set defaultSaveLocation(String location) {
    _defaultSaveLocation = location;
    notifyListeners();
    _saveSettings();
  }

  set defaultQuality(int quality) {
    _defaultQuality = quality.clamp(1, 100);
    notifyListeners();
    _saveSettings();
  }

  set autoSaveToHistory(bool value) {
    _autoSaveToHistory = value;
    notifyListeners();
    _saveSettings();
  }

  set enableImageEnhancement(bool value) {
    _enableImageEnhancement = value;
    notifyListeners();
    _saveSettings();
  }

  set defaultDpi(int dpi) {
    _defaultDpi = dpi.clamp(50, 600);
    notifyListeners();
    _saveSettings();
  }

  set enableNotifications(bool value) {
    _enableNotifications = value;
    notifyListeners();
    _saveSettings();
    
    // Handle notification scheduling
    if (value) {
      NotificationService().scheduleDailyNotification();
    } else {
      NotificationService().cancelDailyNotification();
    }
  }

  set termsAccepted(bool value) {
    _termsAccepted = value;
    notifyListeners();
    _saveSettings();
  }

  set userName(String name) { // Setter for user name
    _userName = name;
    notifyListeners();
    _saveSettings();
  }

  AppSettings() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load theme mode
      final themeModeString = prefs.getString(_themeModeKey) ?? _defaultThemeModeValue.toString();
      _themeMode = _parseThemeMode(themeModeString);
      
      // Load other settings
      _language = prefs.getString(_languageKey) ?? _defaultLanguageValue;
      _defaultSaveLocation = prefs.getString(_defaultSaveLocationKey) ?? _defaultSaveLocationValue;
      _defaultQuality = prefs.getInt(_defaultQualityKey) ?? _defaultQualityValue;
      _autoSaveToHistory = prefs.getBool(_autoSaveToHistoryKey) ?? _defaultAutoSaveToHistoryValue;
      _enableImageEnhancement = prefs.getBool(_enableImageEnhancementKey) ?? _defaultEnableImageEnhancementValue;
      _defaultDpi = prefs.getInt(_defaultDpiKey) ?? _defaultDpiValue;
      _enableNotifications = prefs.getBool(_enableNotificationsKey) ?? _defaultEnableNotificationsValue;
      _termsAccepted = prefs.getBool(_termsAcceptedKey) ?? _defaultTermsAcceptedValue;
      _userName = prefs.getString(_userNameKey) ?? _defaultUserNameValue; // Load user name
      
      notifyListeners();
      
      // Schedule notification based on loaded settings
      if (_enableNotifications) {
        NotificationService().scheduleDailyNotification(
          hour: 9,
          minute: 0,
        );
      }
    } catch (e) {
      // If there's an error loading settings, use defaults
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save theme mode
      await prefs.setString(_themeModeKey, _themeMode.toString());
      
      // Save other settings
      await prefs.setString(_languageKey, _language);
      await prefs.setString(_defaultSaveLocationKey, _defaultSaveLocation);
      await prefs.setInt(_defaultQualityKey, _defaultQuality);
      await prefs.setBool(_autoSaveToHistoryKey, _autoSaveToHistory);
      await prefs.setBool(_enableImageEnhancementKey, _enableImageEnhancement);
      await prefs.setInt(_defaultDpiKey, _defaultDpi);
      await prefs.setBool(_enableNotificationsKey, _enableNotifications);
      await prefs.setBool(_termsAcceptedKey, _termsAccepted);
      await prefs.setString(_userNameKey, _userName); // Save user name
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  ThemeMode _parseThemeMode(String themeModeString) {
    switch (themeModeString) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.system':
      default:
        return ThemeMode.system;
    }
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    _themeMode = _defaultThemeModeValue;
    _language = _defaultLanguageValue;
    _defaultSaveLocation = _defaultSaveLocationValue;
    _defaultQuality = _defaultQualityValue;
    _autoSaveToHistory = _defaultAutoSaveToHistoryValue;
    _enableImageEnhancement = _defaultEnableImageEnhancementValue;
    _defaultDpi = _defaultDpiValue;
    _enableNotifications = _defaultEnableNotificationsValue;
    // Note: We don't reset termsAccepted here as it should persist
    // Note: We don't reset userName here as it should persist
    
    notifyListeners();
    await _saveSettings();
    
    // Handle notification scheduling after reset
    if (_enableNotifications) {
      NotificationService().scheduleDailyNotification(
        hour: 9,
        minute: 0,
      );
    } else {
      NotificationService().cancelDailyNotification();
    }
  }
}