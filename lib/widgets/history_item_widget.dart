import 'package:flutter/material.dart';
import 'package:ilovepdf_flutter/models/history_item.dart';
import 'package:ilovepdf_flutter/core/theme.dart';
import 'package:open_file/open_file.dart';

class HistoryItemWidget extends StatelessWidget {
  final HistoryItem historyItem;
  final VoidCallback onDelete;

  const HistoryItemWidget({
    super.key,
    required this.historyItem,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File name and delete button
            Row(
              children: [
                Expanded(
                  child: Text(
                    historyItem.fileName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkTextPrimary
                          : const Color(0xFF2E3A59),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFF6B6B)
                          : Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Delete from history',
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Tool used
            Row(
              children: [
                Icon(Icons.build,
                    size: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkTextMuted
                        : const Color(0xFF8F9BB3)),
                const SizedBox(width: 8),
                Text(
                  historyItem.toolName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkTextMuted
                        : const Color(0xFF8F9BB3),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // File size and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.insert_drive_file,
                        size: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkTextMuted
                            : const Color(0xFF8F9BB3)),
                    const SizedBox(width: 8),
                    Text(
                      historyItem.formattedFileSize,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkTextMuted
                            : const Color(0xFF8F9BB3),
                      ),
                    ),
                  ],
                ),
                Text(
                  historyItem.formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFA0B4D9)
                        : const Color(0xFFA0B4D9),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _openFile,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A80F0),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openFile() async {
    try {
      await OpenFile.open(historyItem.filePath);
    } catch (e) {
      // Handle error silently or show a snackbar
    }
  }
}
