import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ilovepdf_flutter/services/history_service.dart';
import 'package:ilovepdf_flutter/models/history_item.dart';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _filterTool = 'all';

  List<HistoryItem> _getFilteredHistory(List<HistoryItem> history) {
    var filtered = history;
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) => 
        item.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        item.toolName.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Filter by tool
    if (_filterTool != 'all') {
      filtered = filtered.where((item) => item.toolId == _filterTool).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveUtils.getContentScale(context);
    return BaseScreen(
      trackFeatureVisit: false, // History is not a feature screen
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          actions: [
            Consumer<HistoryService>(
              builder: (context, service, _) => service.history.isEmpty ? const SizedBox() : IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: () => _showClearHistoryDialog(context, service),
                tooltip: 'Clear all',
              ),
            ),
          ],
        ),
        body: Consumer<HistoryService>(
          builder: (context, historyService, child) {
            if (historyService.history.isEmpty) {
              return _buildEmptyState(scale);
            }

            final filteredHistory = _getFilteredHistory(historyService.history);
            final tools = historyService.history.map((e) => e.toolId).toSet().toList();

            return Column(
              children: [
                // Header with stats
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E3A59), Color(0xFF1E2A49)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4A80F0), width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.history, color: Colors.white, size: 28 * scale),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${historyService.history.length} Files Processed',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18 * scale),
                            ),
                            Text(
                              '${tools.length} tools used',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search files...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2E2E2E)
                          : Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),

                // Filter chips
                if (tools.length > 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildFilterChip('all', 'All'),
                        ...tools.map((toolId) => _buildFilterChip(
                          toolId, 
                          _getToolName(toolId),
                        )),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // History list
                Expanded(
                  child: filteredHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48 * scale, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('No results found', style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            )),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredHistory.length,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemBuilder: (context, index) {
                          final item = filteredHistory[index];
                          return _buildHistoryCard(context, historyService, item, scale);
                        },
                      ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(double scale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history, size: 64 * scale, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          const Text(
            'No History Yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Processed files will appear here',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home),
            label: const Text('Go to Tools'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String toolId, String label) {
    final isSelected = _filterTool == toolId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _filterTool = toolId),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A80F0) : (isDark ? const Color(0xFF3E3E3E) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.grey[700]),
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, HistoryService service, HistoryItem item, double scale) {
    final toolColor = _getToolColor(item.toolId);
    final toolIcon = _getToolIcon(item.toolId);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.white, size: 24 * scale),
      ),
      onDismissed: (_) {
        service.removeHistoryItem(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted from history')),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => OpenFile.open(item.filePath),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Tool icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: toolColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(toolIcon, color: toolColor, size: 24 * scale),
                  ),
                  const SizedBox(width: 12),
                  // File info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: toolColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.toolName,
                                style: TextStyle(color: toolColor, fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.formattedFileSize,
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[500], 
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Date and actions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatDate(item.processedDate),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[500], 
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => Share.shareXFiles([XFile(item.filePath)]),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF3E3E3E)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.share, size: 18 * scale, 
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[300]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _getToolIcon(String toolId) {
    switch (toolId) {
      case 'compress': return Icons.compress;
      case 'merge': return Icons.merge_type;
      case 'split': return Icons.call_split;
      case 'rotate': return Icons.rotate_90_degrees_ccw;
      case 'watermark': return Icons.water_drop;
      case 'page_number': return Icons.format_list_numbered;
      case 'image_to_pdf': return Icons.image;
      case 'ocr': return Icons.text_snippet;
      case 'convert': return Icons.transform;
      case 'annotate': return Icons.edit_note;
      default: return Icons.description;
    }
  }

  Color _getToolColor(String toolId) {
    switch (toolId) {
      case 'compress': return Colors.orange;
      case 'merge': return Colors.blue;
      case 'split': return Colors.purple;
      case 'rotate': return Colors.green;
      case 'watermark': return Colors.cyan;
      case 'page_number': return Colors.indigo;
      case 'image_to_pdf': return Colors.pink;
      case 'ocr': return Colors.teal;
      case 'convert': return Colors.amber;
      case 'annotate': return Colors.red;
      default: return const Color(0xFF4A80F0);
    }
  }

  String _getToolName(String toolId) {
    switch (toolId) {
      case 'compress': return 'Compress';
      case 'merge': return 'Merge';
      case 'split': return 'Split';
      case 'rotate': return 'Rotate';
      case 'watermark': return 'Watermark';
      case 'page_number': return 'Page #';
      case 'image_to_pdf': return 'Image→PDF';
      case 'ocr': return 'OCR';
      case 'convert': return 'Convert';
      case 'annotate': return 'Annotate';
      default: return toolId;
    }
  }

  void _showClearHistoryDialog(BuildContext context, HistoryService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('This will delete all history. Files will not be deleted.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              service.clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('History cleared')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
