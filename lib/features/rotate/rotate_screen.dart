import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ilovepdf_flutter/services/pdf_rotator_service.dart';
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

class RotateScreen extends StatefulWidget {
  const RotateScreen({super.key});

  @override
  State<RotateScreen> createState() => _RotateScreenState();
}

class _RotateScreenState extends State<RotateScreen> {
  File? _selectedFile;
  int _rotation = 90;
  Set<int> _selectedPages = {};
  bool _isLoading = false;
  bool _isLoadingThumbnails = false;
  double _progress = 0.0;
  RotationResult? _rotationResult;
  int _totalPages = 0;
  int _fileSize = 0;
  List<Uint8List> _pageThumbnails = [];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      
      setState(() {
        _selectedFile = file;
        _rotationResult = null;
        _progress = 0.0;
        _selectedPages = {};
        _pageThumbnails = [];
        _isLoadingThumbnails = true;
      });
      
      await _loadPdfInfo();
    }
  }

  Future<void> _loadPdfInfo() async {
    if (_selectedFile == null) return;
    
    try {
      // Get file size
      final fileSize = await _selectedFile!.length();
      
      // Get page count and thumbnails
      final rotations = await PdfRotator.getPageRotations(_selectedFile!.path);
      final bytes = await _selectedFile!.readAsBytes();
      
      setState(() {
        _totalPages = rotations.length;
        _fileSize = fileSize;
      });
      
      // Generate thumbnails
      final List<Uint8List> thumbnails = [];
      await for (final page in Printing.raster(bytes, dpi: 50)) {
        thumbnails.add(await page.toPng());
      }
      
      setState(() {
        _pageThumbnails = thumbnails;
        _isLoadingThumbnails = false;
      });
    } catch (e) {
      setState(() => _isLoadingThumbnails = false);
    }
  }

  void _togglePage(int pageNum) {
    setState(() {
      if (_selectedPages.contains(pageNum)) {
        _selectedPages.remove(pageNum);
      } else {
        _selectedPages.add(pageNum);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedPages = Set.from(List.generate(_totalPages, (i) => i + 1));
    });
  }

  void _deselectAll() {
    setState(() => _selectedPages = {});
  }

  void _selectOddPages() {
    setState(() {
      _selectedPages = Set.from(
        List.generate(_totalPages, (i) => i + 1).where((p) => p % 2 == 1)
      );
    });
  }

  void _selectEvenPages() {
    setState(() {
      _selectedPages = Set.from(
        List.generate(_totalPages, (i) => i + 1).where((p) => p % 2 == 0)
      );
    });
  }

  Future<void> _rotateFile() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file')),
      );
      return;
    }

    if (_selectedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pages to rotate')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0.0;
    });

    try {
      final result = await PdfRotator.rotatePages(
        pdfPath: _selectedFile!.path,
        pageNumbers: _selectedPages.toList()..sort(),
        rotation: _rotation,
        onProgress: (progress) {
          setState(() => _progress = progress);
        },
      );
      
      setState(() {
        _rotationResult = result;
        _isLoading = false;
        _progress = 1.0;
      });
      
      await HistoryUtils.addToHistory(
        context: context,
        fileName: _selectedFile!.path.split('/').last,
        toolName: 'Rotate PDF',
        toolId: 'rotate',
        filePath: result.outputPath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF rotated successfully!')),
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveUtils.getContentScale(context);
    return BaseScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rotate PDF'),
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
              onPressed: () => HelpDialog.show(context, 'rotate'),
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
                              'Rotate PDF',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select pages and rotation angle',
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
                        child: Icon(Icons.rotate_right, color: Colors.white, size: 32 * scale),
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
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: Text(_selectedFile == null ? 'Select PDF' : 'Change PDF'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          if (_selectedFile != null && _totalPages > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A80F0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildInfoChip(Icons.description, '$_totalPages pages'),
                                  _buildInfoChip(Icons.storage, _formatFileSize(_fileSize)),
                                  _buildInfoChip(Icons.check_circle, '${_selectedPages.length} selected'),
                                ],
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

                  // Rotation Angle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Rotation Angle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white : const Color(0xFF2E3A59),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildRotationCard(90, 'Right', Icons.rotate_right)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildRotationCard(180, 'Flip', Icons.sync)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildRotationCard(270, 'Left', Icons.rotate_left)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Page Selection
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Pages',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white : const Color(0xFF2E3A59),
                          ),
                        ),
                        Text(
                          '${_selectedPages.length}/$_totalPages',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFB0BEC5)
                                : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Select Buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildQuickButton('All', _selectAll),
                        _buildQuickButton('None', _deselectAll),
                        _buildQuickButton('Odd', _selectOddPages),
                        _buildQuickButton('Even', _selectEvenPages),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Page Grid
                  if (_isLoadingThumbnails)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ))
                  else
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      height: 300,
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _totalPages,
                        itemBuilder: (context, index) {
                          final pageNum = index + 1;
                          final isSelected = _selectedPages.contains(pageNum);
                          return GestureDetector(
                            onTap: () => _togglePage(pageNum),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF4A80F0) : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(color: const Color(0xFF4A80F0).withOpacity(0.3), blurRadius: 8)
                                ] : [],
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: index < _pageThumbnails.length
                                        ? Image.memory(_pageThumbnails[index], fit: BoxFit.cover)
                                        : Container(color: Colors.grey[200]),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? const Color(0xFF4A80F0)
                                            : Colors.black.withOpacity(0.6),
                                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                                      ),
                                      child: Text(
                                        '$pageNum',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4A80F0),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
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
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A80F0)),
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          const SizedBox(height: 8),
                          Text('Rotating... ${(_progress * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Rotate Button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _selectedPages.isEmpty ? null : _rotateFile,
                      icon: Icon(_rotation == 90 ? Icons.rotate_right : 
                                 _rotation == 270 ? Icons.rotate_left : Icons.sync),
                      label: Text('Rotate ${_selectedPages.length} Pages'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF4A80F0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                    ),
                  ),
                  // Result
                  if (_rotationResult != null) ...[
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
                            'Rotated ${_rotationResult!.rotatedPages} pages!',
                            style: TextStyle(
                              fontSize: 18,
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
                                  onPressed: () => OpenFile.open(_rotationResult!.outputPath),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('Open'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await Share.shareXFiles([XFile(_rotationResult!.outputPath)]);
                                  },
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4A80F0),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildInfoChip(IconData icon, String label) {
    final scale = ResponsiveUtils.getContentScale(context);
    final isLarge = ResponsiveUtils.isLargeDevice(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: (isLarge ? 20 : 16) * scale, color: const Color(0xFF4A80F0)),
        SizedBox(width: 4 * scale),
        Text(label, style: TextStyle(
          fontSize: (isLarge ? 14 : 12) * scale, 
          fontWeight: FontWeight.w500,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF2E3A59),
        )),
      ],
    );
  }

  Widget _buildRotationCard(int angle, String label, IconData icon) {
    final isSelected = _rotation == angle;
    final scale = ResponsiveUtils.getContentScale(context);
    final isLarge = ResponsiveUtils.isLargeDevice(context);
    return GestureDetector(
      onTap: () => setState(() => _rotation = angle),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: (isLarge ? 18 : 16) * scale),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF4A80F0) 
              : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2E2E2E)
                  : Colors.white),
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF4A80F0) 
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade600
                    : Colors.grey.shade300),
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: const Color(0xFF4A80F0).withOpacity(0.3), blurRadius: 8)
          ] : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF4A80F0), size: (isLarge ? 34 : 28) * scale),
            SizedBox(height: 4 * scale),
            Text(
              label,
              style: TextStyle(
                color: isSelected 
                    ? Colors.white 
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.grey[700]),
                fontWeight: FontWeight.w600,
                fontSize: (isLarge ? 14 : 12) * scale,
              ),
            ),
            Text(
              '$angle°',
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.grey[500],
                fontSize: (isLarge ? 12 : 10) * scale,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(String label, VoidCallback onTap) {
    final scale = ResponsiveUtils.getContentScale(context);
    final isLarge = ResponsiveUtils.isLargeDevice(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(right: 8 * scale),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF3E3E3E) : Colors.grey.shade200,
          foregroundColor: isDark ? Colors.white : const Color(0xFF2E3A59),
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: (isLarge ? 20 : 16) * scale, vertical: (isLarge ? 10 : 8) * scale),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * scale)),
        ),
        child: Text(label, style: TextStyle(fontSize: (isLarge ? 15 : 13) * scale)),
      ),
    );
  }
}