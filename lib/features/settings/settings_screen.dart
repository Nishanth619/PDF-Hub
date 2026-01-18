import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ilovepdf_flutter/models/app_settings.dart';
import 'package:ilovepdf_flutter/services/premium_service.dart';
import 'package:ilovepdf_flutter/widgets/settings_item.dart';
import 'package:ilovepdf_flutter/widgets/settings_section_header.dart';
import 'package:ilovepdf_flutter/core/theme.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      trackFeatureVisit: false, // Settings is not a feature screen
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (GoRouter.of(context).canPop()) {
                GoRouter.of(context).pop();
              } else {
                context.go('/');
              }
            },
          ),
        ),
        body: Consumer<AppSettings>(
          builder: (context, settings, child) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Premium Card
                  _buildPremiumCard(context),
                  // Header section with distinctive design
                  Container(
                    margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkHeaderBackground
                          : const Color(0xFF2E3A59),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkHeaderBackground.withOpacity(0.4)
                              : const Color(0xFF2E3A59).withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF4A80F0),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'App Settings',
                                style: Theme.of(context)
                                    .textTheme
                                    .displayLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Customize your experience',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFE0E0E0)
                                      : const Color(0xFFA0B4D9),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Configure preferences and default options',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFB0BEC5)
                                      : const Color(0xFFC0D0E9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A80F0).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.settings,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Appearance Settings
                  const SettingsSectionHeader(title: 'APPEARANCE'),

                  SettingsItem(
                    icon: Icons.brightness_6,
                    title: 'Theme',
                    subtitle: _getThemeModeDescription(settings.themeMode),
                    trailing: Icon(
                      _getThemeModeIcon(settings.themeMode),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0BEC5)
                          : const Color(0xFF8F9BB3),
                    ),
                    onTap: () => _showThemeSelectionDialog(context, settings),
                  ),

                  SettingsItem(
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'English (US)',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0BEC5)
                          : const Color(0xFF8F9BB3),
                    ),
                    onTap: () => _showLanguageSelectionDialog(context, settings),
                  ),

                  // Processing Settings
                  const SettingsSectionHeader(title: 'PROCESSING'),

                  SettingsItem(
                    icon: Icons.save,
                    title: 'Default Save Location',
                    subtitle: settings.defaultSaveLocation,
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0BEC5)
                          : const Color(0xFF8F9BB3),
                    ),
                    onTap: () => _showSaveLocationDialog(context, settings),
                  ),

                  SettingsItem(
                    icon: Icons.high_quality,
                    title: 'Default Quality',
                    subtitle: '${settings.defaultQuality}%',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0BEC5)
                          : const Color(0xFF8F9BB3),
                    ),
                    onTap: () => _showQualitySelectionDialog(context, settings),
                  ),

                  SettingsItem(
                    icon: Icons.image,
                    title: 'Image Enhancement',
                    subtitle: settings.enableImageEnhancement
                        ? 'Enabled for better OCR accuracy'
                        : 'Disabled for faster processing',
                    trailing: Switch(
                      value: settings.enableImageEnhancement,
                      onChanged: (value) {
                        settings.enableImageEnhancement = value;
                      },
                      activeThumbColor: const Color(0xFF4A80F0),
                    ),
                  ),

                  SettingsItem(
                    icon: Icons.photo,
                    title: 'Default DPI',
                    subtitle: '${settings.defaultDpi} DPI',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0BEC5)
                          : const Color(0xFF8F9BB3),
                    ),
                    onTap: () => _showDpiSelectionDialog(context, settings),
                  ),

                  // History & Notifications
                  const SettingsSectionHeader(title: 'HISTORY & NOTIFICATIONS'),

                  SettingsItem(
                    icon: Icons.history,
                    title: 'Auto-save to History',
                    subtitle: settings.autoSaveToHistory
                        ? 'Automatically save processed files to history'
                        : 'Don\'t save to history automatically',
                    trailing: Switch(
                      value: settings.autoSaveToHistory,
                      onChanged: (value) {
                        settings.autoSaveToHistory = value;
                      },
                      activeThumbColor: const Color(0xFF4A80F0),
                    ),
                  ),

                  SettingsItem(
                    icon: Icons.notifications,
                    title: 'Enable Notifications',
                    subtitle: settings.enableNotifications
                        ? 'Receive processing updates and tips'
                        : 'No notifications will be shown',
                    trailing: Switch(
                      value: settings.enableNotifications,
                      onChanged: (value) {
                        settings.enableNotifications = value;
                      },
                      activeThumbColor: const Color(0xFF4A80F0),
                    ),
                  ),

                  // Advanced Settings
                  const SettingsSectionHeader(title: 'ADVANCED'),

                  SettingsItem(
                    icon: Icons.restore,
                    title: 'Reset to Defaults',
                    subtitle: 'Restore all settings to their original values',
                    onTap: () => _showResetConfirmationDialog(context, settings),
                  ),

                  SettingsItem(
                    icon: Icons.cleaning_services,
                    title: 'Clear App Cache',
                    subtitle: 'Free up storage by clearing temporary files',
                    onTap: () => _showClearCacheConfirmationDialog(context),
                  ),

                  // Legal & About
                  const SettingsSectionHeader(title: 'LEGAL & ABOUT'),

                  SettingsItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'How we handle your data',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0BEC5)
                          : const Color(0xFF8F9BB3),
                    ),
                    onTap: () => context.push('/privacy'),
                  ),

                  SettingsItem(
                    icon: Icons.description_outlined,
                    title: 'Terms & Conditions',
                    subtitle: 'Usage terms and conditions',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0BEC5)
                          : const Color(0xFF8F9BB3),
                    ),
                    onTap: () => context.push('/terms?from=settings'),
                  ),

                  SettingsItem(
                    icon: Icons.info_outline,
                    title: 'About PDF Hub',
                    subtitle: 'Version 1.0.0',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0BEC5)
                          : const Color(0xFF8F9BB3),
                    ),
                    onTap: () => _showAboutDialog(context),
                  ),

                  SettingsItem(
                    icon: Icons.email_outlined,
                    title: 'Contact Support',
                    subtitle: 'pdfhub09@gmail.com',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB0BEC5)
                          : const Color(0xFF8F9BB3),
                    ),
                    onTap: () => _showContactDialog(context),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _getThemeModeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light theme';
      case ThemeMode.dark:
        return 'Dark theme';
      case ThemeMode.system:
        return 'System default';
      default:
        return 'System default';
    }
  }

  IconData _getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.auto_mode;
      default:
        return Icons.auto_mode;
    }
  }

  Widget _buildPremiumCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Consumer<PremiumService>(
      builder: (context, premium, _) {
        return GestureDetector(
          onTap: () => context.go('/premium'),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: premium.isPremium
                  ? const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF4A80F0), Color(0xFF6B5CF5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (premium.isPremium 
                      ? const Color(0xFFFFD700) 
                      : const Color(0xFF4A80F0)).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    premium.isPremium 
                        ? Icons.workspace_premium_rounded 
                        : Icons.star_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        premium.isPremium ? 'Premium Active' : 'Go Premium',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        premium.isPremium 
                            ? 'Enjoy ad-free experience'
                            : 'Remove all ads forever',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  premium.isPremium 
                      ? Icons.check_circle_rounded 
                      : Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: premium.isPremium ? 28 : 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showThemeSelectionDialog(BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                context,
                'Light',
                ThemeMode.light,
                settings.themeMode,
                () => settings.themeMode = ThemeMode.light,
              ),
              _buildThemeOption(
                context,
                'Dark',
                ThemeMode.dark,
                settings.themeMode,
                () => settings.themeMode = ThemeMode.dark,
              ),
              _buildThemeOption(
                context,
                'System Default',
                ThemeMode.system,
                settings.themeMode,
                () => settings.themeMode = ThemeMode.system,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    ThemeMode mode,
    ThemeMode currentMode,
    VoidCallback onTap,
  ) {
    final isSelected = mode == currentMode;
    return ListTile(
      title: Text(title),
      leading: Icon(
        _getThemeModeIcon(mode),
        color: isSelected ? const Color(0xFF4A80F0) : Colors.grey,
      ),
      trailing: isSelected
          ? const Icon(
              Icons.check,
              color: Color(0xFF4A80F0),
            )
          : null,
      onTap: () {
        onTap();
        Navigator.of(context).pop();
      },
    );
  }

  void _showLanguageSelectionDialog(
      BuildContext context, AppSettings settings) {
    // For now, we'll just show a simple dialog since we only support English
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Language'),
          content: const Text('Currently only English (US) is supported.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSaveLocationDialog(BuildContext context, AppSettings settings) {
    // For now, we'll just show a simple dialog with common options
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Default Save Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSaveLocationOption(
                context,
                'Documents',
                settings.defaultSaveLocation,
                () => settings.defaultSaveLocation = 'Documents',
              ),
              _buildSaveLocationOption(
                context,
                'Downloads',
                settings.defaultSaveLocation,
                () => settings.defaultSaveLocation = 'Downloads',
              ),
              _buildSaveLocationOption(
                context,
                'Pictures',
                settings.defaultSaveLocation,
                () => settings.defaultSaveLocation = 'Pictures',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSaveLocationOption(
    BuildContext context,
    String location,
    String currentLocation,
    VoidCallback onTap,
  ) {
    final isSelected = location == currentLocation;
    return ListTile(
      title: Text(location),
      trailing: isSelected
          ? const Icon(
              Icons.check,
              color: Color(0xFF4A80F0),
            )
          : null,
      onTap: () {
        onTap();
        Navigator.of(context).pop();
      },
    );
  }

  void _showQualitySelectionDialog(BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Default Quality'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${settings.defaultQuality}%'),
              Slider(
                value: settings.defaultQuality.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                label: '${settings.defaultQuality}%',
                onChanged: (value) {
                  settings.defaultQuality = value.round();
                },
              ),
              Text(
                'Higher quality preserves more detail but results in larger files',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0BEC5)
                        : Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showDpiSelectionDialog(BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Default DPI'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${settings.defaultDpi} DPI'),
              Slider(
                value: settings.defaultDpi.toDouble(),
                min: 50,
                max: 600,
                divisions: 11,
                label: '${settings.defaultDpi} DPI',
                onChanged: (value) {
                  settings.defaultDpi = value.round();
                },
              ),
              Text(
                'Higher DPI provides better quality but slower processing',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB0BEC5)
                        : Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirmationDialog(
      BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Settings'),
          content: const Text(
            'Are you sure you want to reset all settings to their default values? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                settings.resetToDefaults();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings reset to defaults')),
                );
              },
              child: const Text(
                'Reset',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showClearCacheConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear App Cache'),
          content: const Text(
            'Are you sure you want to clear the app cache? This will remove temporary files and may improve performance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearAppCache(context);
              },
              child: const Text(
                'Clear Cache',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearAppCache(BuildContext context) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Clearing cache...'),
                ],
              ),
            );
          },
        );
      }

      int filesDeleted = 0;

      // Clear temporary directory
      try {
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          // Count files before deletion
          filesDeleted += await _countFiles(tempDir);
          // Delete all contents but keep the directory
          await _deleteDirectoryContents(tempDir);
        }
      } catch (e) {
        debugPrint('Error clearing temporary directory: $e');
      }

      // Clear cache directory
      try {
        final cacheDir = await getApplicationCacheDirectory();
        if (await cacheDir.exists()) {
          // Count files before deletion
          filesDeleted += await _countFiles(cacheDir);
          // Delete all contents but keep the directory
          await _deleteDirectoryContents(cacheDir);
        }
      } catch (e) {
        debugPrint('Error clearing cache directory: $e');
      }

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'App cache cleared successfully ($filesDeleted files deleted)')),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing cache: ${e.toString()}')),
        );
      }
    }
  }

  /// Count the number of files in a directory recursively
  Future<int> _countFiles(Directory directory) async {
    int count = 0;
    try {
      await for (FileSystemEntity entity in directory.list(recursive: true)) {
        if (entity is File) {
          count++;
        }
      }
    } catch (e) {
      debugPrint('Error counting files: $e');
    }
    return count;
  }

  /// Delete all contents of a directory but keep the directory itself
  Future<void> _deleteDirectoryContents(Directory directory) async {
    try {
      await for (FileSystemEntity entity in directory.list()) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('Error deleting directory contents: $e');
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A80F0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Color(0xFF4A80F0),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text('PDF Hub'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version 1.0.0',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'PDF Hub is a powerful PDF processing app that respects your privacy. '
                'All processing is done locally on your device - your files never leave your phone.',
              ),
              SizedBox(height: 12),
              Text(
                '© 2024 PDF Hub. All rights reserved.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Contact Support'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Need help or have feedback?'),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.email, color: Color(0xFF4A80F0), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'pdfhub09@gmail.com',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A80F0),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'We typically respond within 48 hours.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
