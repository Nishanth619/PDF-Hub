import 'package:flutter/material.dart';
import 'package:ilovepdf_flutter/core/theme.dart';

class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: enabled
            ? (isDarkMode ? const Color(0xFF64B5F6) : const Color(0xFF4A80F0))
            : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: enabled
              ? (isDarkMode
                  ? AppTheme.darkTextPrimary
                  : const Color(0xFF2E3A59))
              : Colors.grey,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: enabled
                    ? (isDarkMode
                        ? AppTheme.darkTextMuted
                        : const Color(0xFF8F9BB3))
                    : Colors.grey,
              ),
            )
          : null,
      trailing: trailing,
      onTap: enabled ? onTap : null,
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
