import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ilovepdf_flutter/services/pdf_page_number_service.dart';
import 'package:ilovepdf_flutter/utils/history_utils.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';
import 'package:ilovepdf_flutter/widgets/help_dialog.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:printing/printing.dart';

class AddPageNumbersPage extends StatefulWidget {
  const AddPageNumbersPage({super.key});

  @override
  State<AddPageNumbersPage> createState() => _AddPageNumbersPageState();
}

class _AddPageNumbersPageState extends State<AddPageNumbersPage> {
  File? _selectedFile;
  String _formatType = 'pageOfTotal';
  PageNumberPosition _position = PageNumberPosition.bottomCenter;
  double _fontSize = 12.0;
  Color _color = Colors.black;
  bool _bold = false;
  int _startPage = 1;
  bool _isLoading = false;
  bool _isLoadingThumbnail = false;
  double _progress = 0;
  PageNumberResult? _pageNumberResult;
  int _totalPages = 0;
  Uint8List? _firstPageThumbnail;

  final List<Color> _colorOptions = [
    Colors.black,
    Colors.grey,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _pageNumberResult = null;
        _firstPageThumbnail = null;
        _isLoadingThumbnail = true;
      });
      await _loadPdfInfo();
    }
  }

  Future<void> _loadPdfInfo() async {
    if (_selectedFile == null) return;
    
    try {
      final bytes = await _selectedFile!.readAsBytes();
      int pageCount = 0;
      Uint8List? thumbnail;
      
      await for (final page in Printing.raster(bytes, dpi: 72)) {
        if (pageCount == 0) {
          thumbnail = await page.toPng();
        }
        pageCount++;
      }
      
      setState(() {
        _totalPages = pageCount;
        _firstPageThumbnail = thumbnail;
        _isLoadingThumbnail = false;
      });
    } catch (e) {
      setState(() => _isLoadingThumbnail = false);
    }
  }

  String _getFormatPreview() {
    switch (_formatType) {
      case 'pageOfTotal':
        return 'Page $_startPage of $_totalPages';
      case 'slash':
        return '$_startPage/$_totalPages';
      case 'simple':
        return '$_startPage';
      case 'roman':
        return _toRoman(_startPage);
      case 'mirrored':
        return 'Alternates left/right';
      default:
        return 'Page $_startPage of $_totalPages';
    }
  }

  String _toRoman(int num) {
    const romanNumerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
    if (num >= 1 && num <= 10) return romanNumerals[num - 1];
    return num.toString();
  }

  Future<void> _addPageNumbers() async {
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
      PageNumberResult result;
      
      switch (_formatType) {
        case 'pageOfTotal':
          result = await PdfPageNumbering.addPageOfTotal(
            pdfPath: _selectedFile!.path,
            position: _position,
            startPage: _startPage,
            fontSize: _fontSize,
            color: _color,
            onProgress: (progress) => setState(() => _progress = progress),
          );
          break;
        case 'slash':
          result = await PdfPageNumbering.addSlashFormat(
            pdfPath: _selectedFile!.path,
            position: _position,
            startPage: _startPage,
            fontSize: _fontSize,
            color: _color,
            onProgress: (progress) => setState(() => _progress = progress),
          );
          break;
        case 'simple':
          result = await PdfPageNumbering.addSimpleNumbers(
            pdfPath: _selectedFile!.path,
            position: _position,
            startPage: _startPage,
            fontSize: _fontSize,
            color: _color,
            onProgress: (progress) => setState(() => _progress = progress),
          );
          break;
        case 'roman':
          result = await PdfPageNumbering.addRomanNumbers(
            pdfPath: _selectedFile!.path,
            position: _position,
            startPage: _startPage,
            fontSize: _fontSize,
            color: _color,
            onProgress: (progress) => setState(() => _progress = progress),
          );
          break;
        case 'mirrored':
          result = await PdfPageNumbering.addMirroredNumbers(
            pdfPath: _selectedFile!.path,
            startPage: _startPage,
            fontSize: _fontSize,
            color: _color,
            onProgress: (progress) => setState(() => _progress = progress),
          );
          break;
        default:
          result = await PdfPageNumbering.addPageOfTotal(
            pdfPath: _selectedFile!.path,
            position: _position,
            startPage: _startPage,
            fontSize: _fontSize,
            color: _color,
            onProgress: (progress) => setState(() => _progress = progress),
          );
      }
      
      setState(() {
        _pageNumberResult = result;
        _isLoading = false;
        _progress = 1.0;
      });
      
      await HistoryUtils.addToHistory(
        context: context,
        fileName: _selectedFile!.path.split('/').last,
        toolName: 'Add Page Numbers',
        toolId: 'page_numbers',
        filePath: result.outputPath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Page numbers added successfully!')),
        );
      }
      
      // Show interstitial ad after successful operation
      AdService().showInterstitialAfterOperation();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _progress = 0.0;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveUtils.getContentScale(context);
    return BaseScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Page Numbers'),
          elevation: 0,
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
              onPressed: () => HelpDialog.show(context, 'page_number'),
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
                              'Add Page Numbers',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Number your PDF pages',
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
                        child: Icon(Icons.format_list_numbered, color: Colors.white, size: 32 * scale),
                      ),
                    ],
                  ),
                ),

                // PDF Selection with Preview
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          if (_firstPageThumbnail != null) ...[
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    _firstPageThumbnail!,
                                    height: 150,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                // Preview overlay showing where number will appear
                                Positioned(
                                  top: _position == PageNumberPosition.topLeft || 
                                       _position == PageNumberPosition.topCenter || 
                                       _position == PageNumberPosition.topRight ? 8 : null,
                                  bottom: _position == PageNumberPosition.bottomLeft || 
                                          _position == PageNumberPosition.bottomCenter || 
                                          _position == PageNumberPosition.bottomRight ? 8 : null,
                                  left: _position == PageNumberPosition.topLeft || 
                                        _position == PageNumberPosition.bottomLeft ? 8 : null,
                                  right: _position == PageNumberPosition.topRight || 
                                         _position == PageNumberPosition.bottomRight ? 8 : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.95),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF4A80F0), width: 2),
                                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                    ),
                                    child: Text(
                                      _getFormatPreview(),
                                      style: TextStyle(
                                        color: _color,
                                        fontSize: 10,
                                        fontWeight: _bold ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ] else if (_isLoadingThumbnail) ...[
                            const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                            const SizedBox(height: 12),
                          ] else ...[
                            Icon(
                              Icons.picture_as_pdf,
                              size: 48,
                              color: _selectedFile != null ? const Color(0xFF4A80F0) : Colors.grey,
                            ),
                            const SizedBox(height: 12),
                          ],
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
                          if (_selectedFile != null && _totalPages > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              '$_totalPages pages',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB0BEC5)
                                    : Colors.grey[600], 
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                if (_selectedFile != null && _totalPages > 0) ...[
                  const SizedBox(height: 24),

                  // Format Selection
                  _buildSectionTitle('Number Format'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFormatChip('pageOfTotal', 'Page X of Y'),
                        _buildFormatChip('slash', 'X / Y'),
                        _buildFormatChip('simple', 'X'),
                        _buildFormatChip('roman', 'I, II, III'),
                        _buildFormatChip('mirrored', 'Mirrored'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Position Grid
                  _buildSectionTitle('Position'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // 3x2 Grid for positions
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildPositionButton(PageNumberPosition.topLeft, '↖'),
                                _buildPositionButton(PageNumberPosition.topCenter, '↑'),
                                _buildPositionButton(PageNumberPosition.topRight, '↗'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildPositionButton(PageNumberPosition.bottomLeft, '↙'),
                                _buildPositionButton(PageNumberPosition.bottomCenter, '↓'),
                                _buildPositionButton(PageNumberPosition.bottomRight, '↘'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Appearance
                  _buildSectionTitle('Appearance'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Start Number
                            Text('Start from: $_startPage'),
                            Slider(
                              value: _startPage.toDouble(),
                              min: 1,
                              max: 100,
                              divisions: 99,
                              onChanged: (v) => setState(() => _startPage = v.toInt()),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Font Size
                            Text('Font Size: ${_fontSize.toStringAsFixed(0)}'),
                            Slider(
                              value: _fontSize,
                              min: 8,
                              max: 24,
                              divisions: 16,
                              onChanged: (v) => setState(() => _fontSize = v),
                            ),

                            const SizedBox(height: 16),

                            // Bold Toggle
                            Row(
                              children: [
                                const Text('Bold: '),
                                Switch(
                                  value: _bold,
                                  onChanged: (v) => setState(() => _bold = v),
                                  activeColor: const Color(0xFF4A80F0),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Colors
                  _buildSectionTitle('Color'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _colorOptions.map((c) => _buildColorOption(c)).toList(),
                        ),
                      ),
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
                          Text('Adding numbers... ${(_progress * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Add Button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _addPageNumbers,
                      icon: const Icon(Icons.format_list_numbered),
                      label: const Text('Add Page Numbers'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF4A80F0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  // Result
                  if (_pageNumberResult != null) ...[
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
                            'Added to ${_pageNumberResult!.numberedPages} pages!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => OpenFile.open(_pageNumberResult!.outputPath),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('Open'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => Share.shareXFiles([XFile(_pageNumberResult!.outputPath)]),
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A80F0),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildFormatChip(String type, String label) {
    final isSelected = _formatType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _formatType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A80F0) : (isDark ? const Color(0xFF3E3E3E) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF4A80F0).withOpacity(0.3), blurRadius: 8)] : [],
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

  Widget _buildPositionButton(PageNumberPosition pos, String arrow) {
    final isSelected = _position == pos;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _position = pos),
      child: Container(
        width: 60,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A80F0) : (isDark ? const Color(0xFF3E3E3E) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF4A80F0) : (isDark ? Colors.grey.shade600 : Colors.grey.shade300)),
        ),
        child: Center(
          child: Text(
            arrow,
            style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.grey[700]),
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorOption(Color color) {
    final isSelected = _color == color;
    return GestureDetector(
      onTap: () => setState(() => _color = color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFF4A80F0) : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)] : [],
        ),
        child: isSelected ? Icon(Icons.check, color: color == Colors.black ? Colors.white : Colors.white, size: 20) : null,
      ),
    );
  }
}
