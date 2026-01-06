import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:ilovepdf_flutter/utils/history_utils.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';
import 'package:ilovepdf_flutter/widgets/help_dialog.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';

class FormFillerScreen extends StatefulWidget {
  const FormFillerScreen({super.key});

  @override
  State<FormFillerScreen> createState() => _FormFillerScreenState();
}

class _FormFillerScreenState extends State<FormFillerScreen> {
  File? _selectedFile;
  String? _fileName;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _savedFilePath;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  PdfViewerController? _pdfViewerController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfViewerController?.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            _selectedFile = File(file.path!);
            _fileName = file.name;
            _savedFilePath = null;
          });
        }
      }
    } catch (e) {
      _showError('Error picking file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFilledPdf({bool flatten = false}) async {
    if (_selectedFile == null) return;

    setState(() => _isSaving = true);

    try {
      // Get the filled PDF bytes from the controller
      final List<int>? pdfBytes = await _pdfViewerController?.saveDocument();
      
      if (pdfBytes == null || pdfBytes.isEmpty) {
        _showError('Failed to save PDF');
        return;
      }

      // Generate output filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseName = _fileName?.replaceAll('.pdf', '') ?? 'form';
      final suffix = flatten ? '_filled_final' : '_filled';
      final outputFileName = '${baseName}${suffix}_$timestamp.pdf';

      // Save to documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final outputPath = '${documentsDir.path}/$outputFileName';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(pdfBytes);

      setState(() {
        _savedFilePath = outputPath;
      });

      // Add to history
      await HistoryUtils.addToHistory(
        context: context,
        fileName: outputFileName,
        toolName: 'Form Filler',
        toolId: 'form_filler',
        filePath: outputPath,
      );

      _showSuccess(flatten 
          ? 'Form saved and flattened (non-editable)' 
          : 'Form saved successfully');
      
      // Show interstitial ad after successful operation
      AdService().showInterstitialAfterOperation();
    } catch (e) {
      _showError('Error saving PDF: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_savedFilePath == null) {
      // Save first, then share
      await _saveFilledPdf();
    }
    
    if (_savedFilePath != null) {
      await Share.shareXFiles(
        [XFile(_savedFilePath!)],
        text: 'Filled PDF Form',
      );
    }
  }

  Future<void> _openSavedPdf() async {
    if (_savedFilePath != null) {
      await OpenFile.open(_savedFilePath!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showSaveOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Save Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_document, color: Colors.blue),
              ),
              title: const Text('Save Editable'),
              subtitle: const Text('Form fields remain editable'),
              onTap: () {
                Navigator.pop(context);
                _saveFilledPdf(flatten: false);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock, color: Colors.orange),
              ),
              title: const Text('Save & Flatten'),
              subtitle: const Text('Form becomes non-editable (final)'),
              onTap: () {
                Navigator.pop(context);
                _saveFilledPdf(flatten: true);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = ResponsiveUtils.getContentScale(context);

    return BaseScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PDF Form Filler'),
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
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help',
              onPressed: () => HelpDialog.show(context, 'form_filler'),
            ),
            if (_selectedFile != null) ...[
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save filled form',
                onPressed: _isSaving ? null : _showSaveOptions,
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onPressed: _isSaving ? null : _sharePdf,
              ),
            ],
          ],
        ),
        body: _selectedFile == null
            ? _buildPickerView(isDark)
            : _buildFormFillerView(isDark),
      ),
    );
  }

  Widget _buildPickerView(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PDF Form Filler',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Fill interactive PDF forms',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFA0B4D9),
                        ),
                      ),
                      const Text(
                        'Text boxes, checkboxes, dropdowns & more',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFC0D0E9),
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
                    Icons.edit_document,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),

          // Pick PDF Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 64,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select a PDF with form fields',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supports text boxes, checkboxes, radio buttons,\ndropdowns, and signature fields',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _pickPdf,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(_isLoading ? 'Loading...' : 'Select PDF'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF4A80F0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Instructions
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'How to use',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInstructionRow('1', 'Select a PDF with fillable form fields'),
                _buildInstructionRow('2', 'Tap on fields to enter text or select options'),
                _buildInstructionRow('3', 'Save as editable or flatten (make final)'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Important note about form fields
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 24,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Important',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This only works with PDFs that have interactive form fields (like tax forms, job applications, etc.). Regular PDFs cannot be filled.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF4A80F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFillerView(bool isDark) {
    return Column(
      children: [
        // File info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          child: Row(
            children: [
              const Icon(Icons.description, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _fileName ?? 'PDF File',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: _pickPdf,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Change'),
              ),
            ],
          ),
        ),

        // PDF Viewer with form filling
        Expanded(
          child: SfPdfViewer.file(
            _selectedFile!,
            key: _pdfViewerKey,
            controller: _pdfViewerController,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            onDocumentLoadFailed: (details) {
              _showError('Failed to load PDF: ${details.error}');
            },
          ),
        ),

        // Bottom action bar\r\n        if (_savedFilePath != null)\r\n          Container(\r\n            padding: const EdgeInsets.all(16),\r\n            decoration: BoxDecoration(\r\n              color: Theme.of(context).brightness == Brightness.dark\r\n                  ? Colors.green.withOpacity(0.15)\r\n                  : Colors.green.shade50,\r\n              border: Border(\r\n                top: BorderSide(\r\n                  color: Theme.of(context).brightness == Brightness.dark\r\n                      ? Colors.green.withOpacity(0.5)\r\n                      : Colors.green.shade200,\r\n                ),\r\n              ),\r\n            ),\r\n            child: Row(\r\n              children: [\r\n                Icon(Icons.check_circle, \r\n                  color: Theme.of(context).brightness == Brightness.dark\r\n                      ? Colors.green\r\n                      : Colors.green.shade700,\r\n                ),\r\n                const SizedBox(width: 8),\r\n                Expanded(\r\n                  child: Text(\r\n                    'Form saved!',\r\n                    style: TextStyle(\r\n                      color: Theme.of(context).brightness == Brightness.dark\r\n                          ? Colors.white\r\n                          : Colors.green.shade700,\r\n                      fontWeight: FontWeight.w500,\r\n                    ),\r\n                  ),\r\n                ),\r\n                TextButton.icon(\r\n                  onPressed: _openSavedPdf,\r\n                  icon: const Icon(Icons.open_in_new, size: 18),\r\n                  label: const Text('Open'),\r\n                ),\r\n              ],\r\n            ),\r\n          ),
      ],
    );
  }
}
