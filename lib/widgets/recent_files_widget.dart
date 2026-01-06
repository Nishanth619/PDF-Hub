import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ilovepdf_flutter/services/history_service.dart';
import 'package:ilovepdf_flutter/models/history_item.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:pdfx/pdfx.dart';

class RecentFilesWidget extends StatelessWidget {
  const RecentFilesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<HistoryService>(
      builder: (context, historyService, _) {
        final recentItems = historyService.history.take(5).toList();

        if (recentItems.isEmpty) {
          return _buildEmptyState(context, isDark);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Files',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 115,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: recentItems.length,
                itemBuilder: (context, index) {
                  final item = recentItems[index];
                  return _RecentFileCard(
                    item: item,
                    isDark: isDark,
                    onDelete: () {
                      historyService.removeHistoryItem(item.id);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A80F0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: Color(0xFF4A80F0),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No recent files',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF2E3A59),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Start by processing a PDF',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentFileCard extends StatefulWidget {
  final HistoryItem item;
  final bool isDark;
  final VoidCallback onDelete;

  const _RecentFileCard({
    required this.item,
    required this.isDark,
    required this.onDelete,
  });

  @override
  State<_RecentFileCard> createState() => _RecentFileCardState();
}

class _RecentFileCardState extends State<_RecentFileCard> {
  Uint8List? _thumbnail;
  bool _loadingThumbnail = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (!widget.item.filePath.toLowerCase().endsWith('.pdf')) {
      setState(() => _loadingThumbnail = false);
      return;
    }

    try {
      final file = File(widget.item.filePath);
      if (!await file.exists()) {
        setState(() => _loadingThumbnail = false);
        return;
      }

      final document = await PdfDocument.openFile(widget.item.filePath);
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: 80,
        height: 100,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      await document.close();

      if (mounted && pageImage != null) {
        setState(() {
          _thumbnail = pageImage.bytes;
          _loadingThumbnail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingThumbnail = false);
      }
    }
  }

  String _getTimeAgo() {
    final diff = DateTime.now().difference(widget.item.processedDate);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${widget.item.processedDate.day}/${widget.item.processedDate.month}';
  }

  IconData _getToolIcon() {
    switch (widget.item.toolName.toLowerCase()) {
      case 'compress pdf': return Icons.compress;
      case 'merge pdf': return Icons.merge_type;
      case 'split pdf': return Icons.call_split;
      case 'rotate pdf': return Icons.rotate_90_degrees_ccw;
      case 'add watermark': return Icons.water_drop;
      case 'add page numbers': return Icons.format_list_numbered;
      case 'images to pdf': return Icons.image;
      case 'ocr text extraction': return Icons.document_scanner;
      case 'pdf annotate': return Icons.edit_note;
      case 'form filler': return Icons.edit_document;
      default: return Icons.description;
    }
  }

  Color _getToolColor() {
    switch (widget.item.toolName.toLowerCase()) {
      case 'compress pdf': return const Color(0xFF00B894);
      case 'merge pdf': return const Color(0xFF6C5CE7);
      case 'split pdf': return const Color(0xFFFF7675);
      case 'rotate pdf': return const Color(0xFF74B9FF);
      case 'add watermark': return const Color(0xFF00CEC9);
      case 'add page numbers': return const Color(0xFFFDAE7B);
      case 'images to pdf': return const Color(0xFFE84393);
      case 'ocr text extraction': return const Color(0xFFFFBE76);
      default: return const Color(0xFF4A80F0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (await File(widget.item.filePath).exists()) {
          OpenFile.open(widget.item.filePath);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File not found')),
          );
        }
      },
      onLongPress: () => _showOptions(context),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isDark ? Colors.white12 : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Thumbnail or icon
                Container(
                  width: 32,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getToolColor().withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _loadingThumbnail
                      ? const Center(
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        )
                      : _thumbnail != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(
                                _thumbnail!,
                                fit: BoxFit.cover,
                                width: 32,
                                height: 40,
                              ),
                            )
                          : Icon(
                              _getToolIcon(),
                              size: 16,
                              color: _getToolColor(),
                            ),
                ),
                const Spacer(),
                Text(
                  _getTimeAgo(),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    color: widget.isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              widget.item.fileName,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white : const Color(0xFF2E3A59),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              widget.item.toolName,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                color: widget.isDark ? Colors.white54 : Colors.grey.shade500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.item.fileName,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open'),
              onTap: () async {
                Navigator.pop(ctx);
                if (await File(widget.item.filePath).exists()) {
                  OpenFile.open(widget.item.filePath);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share'),
              onTap: () async {
                Navigator.pop(ctx);
                if (await File(widget.item.filePath).exists()) {
                  Share.shareXFiles([XFile(widget.item.filePath)]);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete from history?'),
        content: Text('Remove "${widget.item.fileName}" from recent files?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Removed from history')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
