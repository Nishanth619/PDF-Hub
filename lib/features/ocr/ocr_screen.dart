import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ilovepdf_flutter/utils/history_utils.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ilovepdf_flutter/services/pdf_ocr_service.dart';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';
import 'package:ilovepdf_flutter/widgets/help_dialog.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  File? _selectedFile;
  bool _isLoading = false;
  double _progress = 0.0;
  OcrResult? _ocrResult;
  String _extractMode = 'balanced';
  List<int> _selectedPages = [];
  TextRecognitionScript _script = TextRecognitionScript.latin;
  bool _enhanceImage = false;
  int _dpi = 150;
  String? _savedFilePath;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      setState(() {
        _selectedFile = file;
        _ocrResult = null;
        _progress = 0.0;
        _savedFilePath = null;
      });
    }
  }

  Future<void> _extractText() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0.0;
    });

    try {
      OcrResult result;

      switch (_extractMode) {
        case 'pages':
          if (_selectedPages.isEmpty) _selectedPages = [1];
          result = await PdfOcrExtractor.extractTextFromPages(
            pdfPath: _selectedFile!.path,
            pageNumbers: _selectedPages,
            script: _script,
            enhanceImage: _enhanceImage,
            dpi: _dpi,
            onProgress: (p) { if (mounted) setState(() => _progress = p); },
          );
          break;
        case 'fast':
          result = await PdfOcrExtractor.extractTextFast(
            pdfPath: _selectedFile!.path,
            script: _script,
            onProgress: (p) { if (mounted) setState(() => _progress = p); },
          );
          break;
        case 'balanced':
          result = await PdfOcrExtractor.extractTextBalanced(
            pdfPath: _selectedFile!.path,
            script: _script,
            onProgress: (p) { if (mounted) setState(() => _progress = p); },
          );
          break;
        case 'highAccuracy':
          result = await PdfOcrExtractor.extractTextHighAccuracy(
            pdfPath: _selectedFile!.path,
            script: _script,
            onProgress: (p) { if (mounted) setState(() => _progress = p); },
          );
          break;
        default:
          result = await PdfOcrExtractor.extractText(
            pdfPath: _selectedFile!.path,
            script: _script,
            enhanceImage: _enhanceImage,
            dpi: _dpi,
            onProgress: (p) { if (mounted) setState(() => _progress = p); },
          );
      }

      if (!mounted) return;
      
      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'ocr_${_selectedFile!.path.split('/').last.replaceAll('.pdf', '')}_$timestamp.txt';
      final outputPath = '${directory.path}/$fileName';
      await File(outputPath).writeAsString(result.fullText);
      
      await HistoryUtils.addToHistory(
        context: context,
        fileName: fileName,
        toolName: 'OCR Text Extraction',
        toolId: 'ocr',
        filePath: outputPath,
      );

      setState(() {
        _ocrResult = result;
        _isLoading = false;
        _progress = 1.0;
        _savedFilePath = outputPath;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text extracted successfully!')),
      );
      
      // Show interstitial ad after successful operation
      AdService().showInterstitialAfterOperation();
    } on TimeoutException {
      if (!mounted) return;
      setState(() { _isLoading = false; _progress = 0.0; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OCR timed out. Try Fast mode or fewer pages.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _progress = 0.0; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _copyToClipboard() {
    if (_ocrResult == null) return;
    Clipboard.setData(ClipboardData(text: _ocrResult!.fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Text copied to clipboard!')),
    );
  }

  void _showExtractedText() {
    if (_ocrResult == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Text('Extracted Text', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: _copyToClipboard,
                    tooltip: 'Copy all',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _ocrResult!.fullText,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveUtils.getContentScale(context);
    return BaseScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OCR Text Extractor'),
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
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => HelpDialog.show(context, 'ocr'),
              tooltip: 'Help',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'OCR Text Extractor',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Extract text from scanned PDFs',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.document_scanner, color: Colors.white, size: 32 * scale),
                      ),
                    ],
                  ),
                ),

                // PDF Selection
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            size: 48,
                            color: _selectedFile != null ? const Color(0xFF4A80F0) : Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _pickFile,
                              icon: const Icon(Icons.upload_file),
                              label: Text(_selectedFile == null ? 'Select PDF' : 'Change PDF'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          if (_selectedFile != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _selectedFile!.path.split('/').last,
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB0BEC5)
                                    : Colors.grey[600], 
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Extraction Mode Cards
                _buildSectionTitle('Extraction Mode'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildModeCard('fast', 'Fast', Icons.flash_on, '100 DPI', Colors.orange)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildModeCard('balanced', 'Balanced', Icons.balance, '150 DPI', Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildModeCard('highAccuracy', 'Accurate', Icons.verified, '200 DPI', Colors.green)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildModeCard('pages', 'Pages', Icons.filter_list, 'Custom', Colors.purple)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Page Selection (when pages mode)
                if (_extractMode == 'pages') ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Enter Page Numbers', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                              decoration: const InputDecoration(
                                hintText: 'e.g., 1, 3, 5-10',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                final pages = <int>[];
                                for (final part in value.split(',')) {
                                  final trimmed = part.trim();
                                  if (trimmed.contains('-')) {
                                    final range = trimmed.split('-');
                                    if (range.length == 2) {
                                      final start = int.tryParse(range[0].trim());
                                      final end = int.tryParse(range[1].trim());
                                      if (start != null && end != null) {
                                        for (int i = start; i <= end; i++) pages.add(i);
                                      }
                                    }
                                  } else {
                                    final num = int.tryParse(trimmed);
                                    if (num != null) pages.add(num);
                                  }
                                }
                                setState(() => _selectedPages = pages);
                              },
                            ),
                            if (_selectedPages.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Selected: ${_selectedPages.join(', ')}', style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB0BEC5)
                                    : Colors.grey[600], 
                                fontSize: 12,
                              )),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Language Chips
                _buildSectionTitle('Language Script'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildLanguageChip(TextRecognitionScript.latin, 'Latin (English)'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Progress
                if (_isLoading) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.grey[300],
                          borderRadius: BorderRadius.circular(5),
                        ),
                        const SizedBox(height: 8),
                        Text('Extracting... ${(_progress * 100).toStringAsFixed(0)}%'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Extract Button
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || _selectedFile == null ? null : _extractText,
                    icon: const Icon(Icons.text_snippet),
                    label: const Text('Extract Text'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF4A80F0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                // Result
                if (_ocrResult != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.green.withOpacity(0.15)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 48 * scale),
                        const SizedBox(height: 12),
                        Text(
                          'Text Extracted!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_ocrResult!.pageCount} pages • ${_ocrResult!.wordCount} words • ${(_ocrResult!.averageConfidence * 100).toStringAsFixed(0)}% confidence',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFB0BEC5)
                                : Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showExtractedText,
                                icon: const Icon(Icons.visibility),
                                label: const Text('View'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _copyToClipboard,
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A80F0),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              if (_savedFilePath != null) {
                                Share.shareXFiles([XFile(_savedFilePath!)]);
                              }
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Share Text File'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2E3A59),
        ),
      ),
    );
  }

  Widget _buildModeCard(String mode, String label, IconData icon, String dpi, Color color) {
    final isSelected = _extractMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _extractMode = mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF2E2E2E) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700]), size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.grey[800]),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              dpi,
              style: TextStyle(
                color: isSelected ? Colors.white70 : (isDark ? Colors.white54 : Colors.grey[600]),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageChip(TextRecognitionScript script, String label) {
    final isSelected = _script == script;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _script = script),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A80F0) : (isDark ? const Color(0xFF3E3E3E) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.grey[700]),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}