import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ilovepdf_flutter/services/pdf_watermark_service.dart';
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

class AddWatermarkScreen extends StatefulWidget {
  const AddWatermarkScreen({super.key});

  @override
  State<AddWatermarkScreen> createState() => _AddWatermarkScreenState();
}

class _AddWatermarkScreenState extends State<AddWatermarkScreen> {
  final TextEditingController _textController = TextEditingController();
  File? _selectedFile;
  File? _imageFile;
  String _watermarkType = 'text';
  String _watermarkText = 'CONFIDENTIAL';
  WatermarkPosition _position = WatermarkPosition.center;
  double _opacity = 0.3;
  double _fontSize = 48;
  double _rotation = -30; // Diagonal by default
  Color _color = Colors.grey;
  bool _isTiled = false;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isLoading = false;
  bool _isLoadingThumbnails = false;
  double _progress = 0.0;
  WatermarkResult? _watermarkResult;
  int _totalPages = 0;
  Set<int> _selectedPages = {};
  List<Uint8List> _pageThumbnails = [];

  final List<Color> _colorOptions = [
    Colors.grey,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _textController.text = _watermarkText;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _watermarkResult = null;
        _selectedPages = {};
        _pageThumbnails = [];
        _isLoadingThumbnails = true;
      });
      await _loadPdfInfo();
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        _imageFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _loadPdfInfo() async {
    if (_selectedFile == null) return;
    
    try {
      final bytes = await _selectedFile!.readAsBytes();
      final List<Uint8List> thumbnails = [];
      
      await for (final page in Printing.raster(bytes, dpi: 50)) {
        thumbnails.add(await page.toPng());
      }
      
      setState(() {
        _totalPages = thumbnails.length;
        _pageThumbnails = thumbnails;
        _selectedPages = Set.from(List.generate(_totalPages, (i) => i + 1));
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

  void _selectAll() => setState(() => _selectedPages = Set.from(List.generate(_totalPages, (i) => i + 1)));
  void _deselectAll() => setState(() => _selectedPages = {});

  Future<void> _addWatermark() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file')),
      );
      return;
    }

    if (_watermarkType == 'text' && _watermarkText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter watermark text')),
      );
      return;
    }

    if (_watermarkType == 'image' && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a watermark image')),
      );
      return;
    }

    if (_selectedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pages to watermark')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _progress = 0.0;
    });

    try {
      WatermarkResult result;
      
      if (_watermarkType == 'text') {
        if (_isTiled) {
          // Use pattern watermark for tiled
          result = await PdfWatermark.addPatternWatermark(
            pdfPath: _selectedFile!.path,
            text: _watermarkText,
            opacity: _opacity,
            fontSize: _fontSize,
            color: _color,
            rotation: _rotation,
            spacing: 150,
            applyToAllPages: _selectedPages.length == _totalPages,
            onProgress: (progress) {
              setState(() => _progress = progress);
            },
          );
        } else {
          // Regular text watermark
          result = await PdfWatermark.addTextWatermark(
            pdfPath: _selectedFile!.path,
            text: _watermarkText,
            position: _position,
            opacity: _opacity,
            fontSize: _fontSize,
            color: _color,
            rotation: _rotation,
            applyToAllPages: _selectedPages.length == _totalPages,
            specificPages: _selectedPages.length != _totalPages ? _selectedPages.toList() : null,
            onProgress: (progress) {
              setState(() => _progress = progress);
            },
          );
        }
      } else {
        result = await PdfWatermark.addImageWatermark(
          pdfPath: _selectedFile!.path,
          imagePath: _imageFile!.path,
          position: _position,
          opacity: _opacity,
          rotation: _rotation,
          applyToAllPages: _selectedPages.length == _totalPages,
          specificPages: _selectedPages.length != _totalPages ? _selectedPages.toList() : null,
          onProgress: (progress) {
            setState(() => _progress = progress);
          },
        );
      }
      
      setState(() {
        _watermarkResult = result;
        _isLoading = false;
        _progress = 1.0;
      });
      
      await HistoryUtils.addToHistory(
        context: context,
        fileName: _selectedFile!.path.split('/').last,
        toolName: 'Add Watermark',
        toolId: 'watermark',
        filePath: result.outputPath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Watermark added successfully!')),
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
          title: const Text('Add Watermark'),
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
              onPressed: () => HelpDialog.show(context, 'watermark'),
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
                              'Add Watermark',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Protect your documents with watermarks',
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
                        child: Icon(Icons.water_drop, color: Colors.white, size: 32 * scale),
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

                  // Watermark Type
                  _buildSectionTitle('Watermark Type'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildTypeCard('text', 'Text', Icons.text_fields)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTypeCard('image', 'Image', Icons.image)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Text Input or Image Selection
                  if (_watermarkType == 'text') ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          labelText: 'Watermark Text',
                          hintText: 'e.g., CONFIDENTIAL, DRAFT',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.text_fields),
                        ),
                        onChanged: (value) => setState(() => _watermarkText = value),
                      ),
                    ),
                  ] else ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              if (_imageFile != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(_imageFile!, height: 60, width: 60, fit: BoxFit.cover),
                                )
                              else
                                Container(
                                  height: 60, width: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.image, color: Colors.grey),
                                ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: Text(_imageFile == null ? 'Select Image' : 'Change Image'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

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
                            _buildPositionRow([
                              WatermarkPosition.topLeft,
                              WatermarkPosition.topCenter,
                              WatermarkPosition.topRight,
                            ]),
                            const SizedBox(height: 8),
                            _buildPositionRow([
                              WatermarkPosition.centerLeft,
                              WatermarkPosition.center,
                              WatermarkPosition.centerRight,
                            ]),
                            const SizedBox(height: 8),
                            _buildPositionRow([
                              WatermarkPosition.bottomLeft,
                              WatermarkPosition.bottomCenter,
                              WatermarkPosition.bottomRight,
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tiled Option
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: CheckboxListTile(
                        title: const Text('Tiled Pattern'),
                        subtitle: const Text('Repeat watermark across entire page'),
                        value: _isTiled,
                        onChanged: (value) => setState(() => _isTiled = value ?? false),
                        activeColor: const Color(0xFF4A80F0),
                        secondary: const Icon(Icons.grid_view),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Rotation
                  _buildSectionTitle('Rotation: ${_rotation.toStringAsFixed(0)}°'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('-45°'),
                                Expanded(
                                  child: Slider(
                                    value: _rotation,
                                    min: -45,
                                    max: 45,
                                    divisions: 18,
                                    onChanged: (value) => setState(() => _rotation = value),
                                  ),
                                ),
                                const Text('+45°'),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildRotationPreset(-45, '↘ -45°'),
                                _buildRotationPreset(-30, '↘ -30°'),
                                _buildRotationPreset(0, '→ 0°'),
                                _buildRotationPreset(45, '↗ +45°'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Opacity & Font Size
                  _buildSectionTitle('Appearance'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Opacity: ${(_opacity * 100).toStringAsFixed(0)}%'),
                            Slider(
                              value: _opacity,
                              min: 0.1,
                              max: 1.0,
                              divisions: 9,
                              onChanged: (value) => setState(() => _opacity = value),
                            ),
                            if (_watermarkType == 'text') ...[
                              const SizedBox(height: 16),
                              Text('Font Size: ${_fontSize.toStringAsFixed(0)}'),
                              Slider(
                                value: _fontSize,
                                min: 12,
                                max: 120,
                                divisions: 27,
                                onChanged: (value) => setState(() => _fontSize = value),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _buildStyleToggle('Bold', _isBold, () => setState(() => _isBold = !_isBold)),
                                  const SizedBox(width: 12),
                                  _buildStyleToggle('Italic', _isItalic, () => setState(() => _isItalic = !_isItalic)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (_watermarkType == 'text') ...[
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
                            children: _colorOptions.map((color) => _buildColorOption(color)).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Page Selection
                  _buildSectionTitle('Pages (${_selectedPages.length}/$_totalPages)'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildQuickButton('All', _selectAll),
                        _buildQuickButton('None', _deselectAll),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingThumbnails)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ))
                  else
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _totalPages,
                        itemBuilder: (context, index) {
                          final pageNum = index + 1;
                          final isSelected = _selectedPages.contains(pageNum);
                          return GestureDetector(
                            onTap: () => _togglePage(pageNum),
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF4A80F0) : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
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
                                      color: isSelected ? const Color(0xFF4A80F0) : Colors.black54,
                                      child: Text(
                                        '$pageNum',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Icon(Icons.check_circle, color: Color(0xFF4A80F0), size: 20),
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
                            borderRadius: BorderRadius.circular(5),
                          ),
                          const SizedBox(height: 8),
                          Text('Adding watermark... ${(_progress * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Add Watermark Button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _selectedPages.isEmpty ? null : _addWatermark,
                      icon: const Icon(Icons.water_drop),
                      label: Text('Add Watermark to ${_selectedPages.length} Pages'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF4A80F0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  // Result
                  if (_watermarkResult != null) ...[
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
                            'Watermark added to ${_watermarkResult!.watermarkedPages} pages!',
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
                                  onPressed: () => OpenFile.open(_watermarkResult!.outputPath),
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
                                  onPressed: () => Share.shareXFiles([XFile(_watermarkResult!.outputPath)]),
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

  Widget _buildTypeCard(String type, String label, IconData icon) {
    final isSelected = _watermarkType == type;
    final scale = ResponsiveUtils.getContentScale(context);
    final isLarge = ResponsiveUtils.isLargeDevice(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _watermarkType = type),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: (isLarge ? 24 : 20) * scale),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A80F0) : (isDark ? const Color(0xFF2E2E2E) : Colors.white),
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(color: isSelected ? const Color(0xFF4A80F0) : (isDark ? Colors.grey.shade600 : Colors.grey.shade300)),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF4A80F0).withOpacity(0.3), blurRadius: 8)] : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF4A80F0), size: (isLarge ? 40 : 32) * scale),
            SizedBox(height: 8 * scale),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700]), fontWeight: FontWeight.w600, fontSize: (isLarge ? 15 : 13) * scale)),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionRow(List<WatermarkPosition> positions) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: positions.map((pos) => _buildPositionButton(pos)).toList(),
    );
  }

  Widget _buildPositionButton(WatermarkPosition pos) {
    final isSelected = _position == pos;
    final scale = ResponsiveUtils.getContentScale(context);
    final isLarge = ResponsiveUtils.isLargeDevice(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _position = pos),
      child: Container(
        width: (isLarge ? 60 : 50) * scale,
        height: (isLarge ? 60 : 50) * scale,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A80F0) : (isDark ? const Color(0xFF3E3E3E) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(8 * scale),
          border: Border.all(color: isSelected ? const Color(0xFF4A80F0) : (isDark ? Colors.grey.shade600 : Colors.grey.shade300)),
        ),
        child: Icon(
          Icons.water_drop,
          color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.grey),
          size: (isLarge ? 26 : 20) * scale,
        ),
      ),
    );
  }

  Widget _buildRotationPreset(double angle, String label) {
    final isSelected = _rotation == angle;
    final scale = ResponsiveUtils.getContentScale(context);
    final isLarge = ResponsiveUtils.isLargeDevice(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _rotation = angle),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: (isLarge ? 16 : 12) * scale, vertical: (isLarge ? 8 : 6) * scale),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A80F0) : (isDark ? const Color(0xFF3E3E3E) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(16 * scale),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.grey[700]),
            fontSize: (isLarge ? 13 : 11) * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStyleToggle(String label, bool isActive, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4A80F0) : (isDark ? const Color(0xFF3E3E3E) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : (isDark ? Colors.white : Colors.grey[700]),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontStyle: label == 'Italic' ? FontStyle.italic : FontStyle.normal,
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
        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
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
