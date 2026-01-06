import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:ilovepdf_flutter/services/pdf_merger_service.dart';
import 'package:ilovepdf_flutter/utils/history_utils.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';
import 'package:ilovepdf_flutter/widgets/help_dialog.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';

/// Model to hold PDF file info
class PdfFileInfo {
  final File file;
  final int pageCount;
  final int fileSize;
  final Uint8List? thumbnail;
  
  PdfFileInfo({
    required this.file,
    required this.pageCount,
    required this.fileSize,
    this.thumbnail,
  });
  
  String get fileName => file.path.split('/').last.split('\\').last;
  
  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<PdfFileInfo> _pdfFiles = [];
  bool _isLoading = false;
  bool _isLoadingInfo = false;
  double _progress = 0.0;
  String? _outputFilePath;
  String _outputFileName = 'Merged_PDF';
  final TextEditingController _fileNameController = TextEditingController(text: 'Merged_PDF');

  int get _totalPages => _pdfFiles.fold(0, (sum, pdf) => sum + pdf.pageCount);
  int get _totalSize => _pdfFiles.fold(0, (sum, pdf) => sum + pdf.fileSize);

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _isLoadingInfo = true;
        _outputFilePath = null;
        _progress = 0.0;
      });
      
      for (var file in result.files) {
        if (file.path != null) {
          await _addPdfFile(File(file.path!));
        }
      }
      
      setState(() => _isLoadingInfo = false);
    }
  }
  
  Future<void> _addPdfFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final document = sf_pdf.PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      document.dispose();
      
      // Generate thumbnail
      Uint8List? thumbnail;
      try {
        await for (var page in Printing.raster(bytes, pages: [0], dpi: 72)) {
          thumbnail = await page.toPng();
          break;
        }
      } catch (e) {
        // Thumbnail failed, continue without it
      }
      
      setState(() {
        _pdfFiles.add(PdfFileInfo(
          file: file,
          pageCount: pageCount,
          fileSize: bytes.length,
          thumbnail: thumbnail,
        ));
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading ${file.path.split('/').last}: $e')),
      );
    }
  }

  Future<void> _mergeFiles() async {
    if (_pdfFiles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 2 PDF files')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0.0;
    });

    try {
      // Get file paths
      final List<String> filePaths = _pdfFiles
          .map((pdf) => pdf.file.path)
          .where((path) => path.isNotEmpty)
          .toList();
      
      if (filePaths.length < 2) {
        throw Exception('Not enough valid PDF paths');
      }
      
      // Merge PDFs
      final outputPath = await PdfMerger.mergePdfs(
        pdfPaths: filePaths,
        onProgress: (progress) {
          setState(() => _progress = progress);
        },
      );
      
      setState(() {
        _outputFilePath = outputPath;
        _isLoading = false;
        _progress = 1.0;
      });
      
      // Add to history
      await HistoryUtils.addToHistory(
        context: context,
        fileName: outputPath.split('/').last,
        toolName: 'Merge PDFs',
        toolId: 'merge',
        filePath: outputPath,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Merged $_totalPages pages successfully!')),
      );
      
      // Show interstitial ad after successful operation
      AdService().showInterstitialAfterOperation();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _progress = 0.0;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _shareFile() async {
    if (_outputFilePath != null) {
      try {
        final file = XFile(_outputFilePath!);
        await Share.shareXFiles([file], text: 'Check out this merged PDF file');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _pdfFiles.removeAt(index);
      _outputFilePath = null;
    });
  }

  void _reorderFiles(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _pdfFiles.removeAt(oldIndex);
      _pdfFiles.insert(newIndex, item);
      _outputFilePath = null;
    });
  }
  
  void _clearAll() {
    setState(() {
      _pdfFiles.clear();
      _outputFilePath = null;
      _progress = 0.0;
    });
  }
  
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  Widget _buildSummaryItem(IconData icon, String value, String label, double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 24 * scale),
        SizedBox(height: 4 * scale),
        Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16 * scale)),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 11 * scale)),
      ],
    );
  }
  
  Widget _buildInfoChip(IconData icon, String text, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 4 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFF4A80F0).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12 * scale, color: const Color(0xFF4A80F0)),
          SizedBox(width: 4 * scale),
          Text(text, style: TextStyle(fontSize: 11 * scale, color: const Color(0xFF4A80F0), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveUtils.getContentScale(context);
    return BaseScreen(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDFs'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => HelpDialog.show(context, 'merge'),
            tooltip: 'Help',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section with distinctive design
              Container(
                margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E3A59),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E3A59).withOpacity(0.4),
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
                            'Merge PDFs',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Combine multiple PDF files into one',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFE0E0E0)
                                  : const Color(0xFFA0B4D9),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Select PDFs and arrange in desired order',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark
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
                        Icons.merge_type,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
              
              // PDF Selection Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Text(
                  'Select PDF Files',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF2E3A59),
                  ),
                ),
              ),
              
              // PDF Selection Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                width: double.infinity,
                child: Card(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E1E)
                      : Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.upload_file,
                          size: 56,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF64B5F6)
                              : const Color(0xFF4A80F0),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _pickFiles,
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Select PDF Files'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You can select multiple PDF files to merge',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFB0BEC5)
                                : const Color(0xFF8F9BB3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              // Loading indicator while fetching file info
              if (_isLoadingInfo)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                )),

              if (_pdfFiles.isNotEmpty) ...[
                // Selected Files Header with Total Summary
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected Files (${_pdfFiles.length})',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF2E3A59),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ),
                ),
                
                // Total Summary Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A80F0), Color(0xFF1E88E5)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(Icons.insert_drive_file, '${_pdfFiles.length}', 'Files', scale),
                      Container(width: 1, height: 40, color: Colors.white24),
                      _buildSummaryItem(Icons.layers, '$_totalPages', 'Pages', scale),
                      Container(width: 1, height: 40, color: Colors.white24),
                      _buildSummaryItem(Icons.storage, _formatSize(_totalSize), 'Size', scale),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A80F0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.drag_indicator, size: 16, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF64B5F6) : const Color(0xFF4A80F0)),
                        const SizedBox(width: 8),
                        Text(
                          'Drag to reorder • Swipe to delete',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF64B5F6)
                                : const Color(0xFF4A80F0),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Enhanced File List with Thumbnails
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E1E1E)
                        : Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: _pdfFiles.length > 4 ? 350 : null,
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: _pdfFiles.length > 4 
                              ? const AlwaysScrollableScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          itemCount: _pdfFiles.length,
                          onReorder: _reorderFiles,
                          itemBuilder: (context, index) {
                            final pdf = _pdfFiles[index];
                            return Dismissible(
                              key: ValueKey(pdf.file.path + index.toString()),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) => _removeFile(index),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              child: Card(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2E2E2E)
                                    : Colors.white,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Thumbnail or Icon
                                      Container(
                                        width: 50,
                                        height: 65,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(7),
                                          child: pdf.thumbnail != null
                                              ? Image.memory(pdf.thumbnail!, fit: BoxFit.cover)
                                              : Icon(Icons.picture_as_pdf, size: 30, color: Colors.red[400]),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // File Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pdf.fileName,
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white
                                                    : const Color(0xFF2E3A59),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                _buildInfoChip(Icons.layers, '${pdf.pageCount} pages', scale),
                                                const SizedBox(width: 8),
                                                _buildInfoChip(Icons.storage, pdf.fileSizeFormatted, scale),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Order indicator
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4A80F0),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Progress indicator
                if (_isLoading) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A80F0)),
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Merging PDFs... ${( _progress * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF2E3A59),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Merge Button
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _mergeFiles,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF4A80F0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Merge PDFs',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                
                // Result Section
                if (_outputFilePath != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: const Color(0xFF43A047).withOpacity(0.1),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: Color(0xFF43A047),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF43A047),
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Merge Complete!',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF2E3A59),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2E3A59)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF43A047),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'File: ${_outputFilePath!.split('/').last}',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF2E3A59),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Open and Share Buttons in a more prominent grid layout
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2E2E2E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF4A80F0),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'What would you like to do?',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : const Color(0xFF2E3A59),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      // Open Button
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => OpenFile.open(_outputFilePath),
                                          icon: const Icon(Icons.open_in_new, size: 20),
                                          label: const Text('Open'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF43A047),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Share Button
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _shareFile,
                                          icon: const Icon(Icons.share, size: 20),
                                          label: const Text('Share'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF4A80F0),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2E2E2E)
                                    : Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Path: $_outputFilePath',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  color: Color(0xFF8F9BB3),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tip: If "Open" doesn\'t work, manually locate this file in your device\'s file manager.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: Color(0xFF8F9BB3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
  }
}