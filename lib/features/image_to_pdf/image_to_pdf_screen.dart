import 'dart:io' show Platform, File;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ilovepdf_flutter/utils/history_utils.dart';
import 'package:ilovepdf_flutter/utils/responsive_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:pdf/pdf.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:ilovepdf_flutter/services/pdf_image_converter_service.dart';
import 'package:ilovepdf_flutter/widgets/base_screen.dart';
import 'package:ilovepdf_flutter/widgets/help_dialog.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  List<File> _selectedImages = [];
  bool _isConverting = false;
  double _progress = 0.0;
  PdfConversionResult? _conversionResult;
  ImageQuality _quality = ImageQuality.high;
  PdfPageFormat _pageSize = PdfPageFormat.a4;
  PageOrientation _orientation = PageOrientation.portrait;
  bool _autoRotate = true;
  double _margin = 20.0;

  Future<void> _pickImages() async {
    try {
      bool hasPermission = false;
      
      if (Platform.isAndroid) {
        PermissionStatus status = await Permission.storage.request();
        if (status == PermissionStatus.granted) {
          hasPermission = true;
        } else {
          status = await Permission.mediaLibrary.request();
          if (status == PermissionStatus.granted) {
            hasPermission = true;
          } else {
            status = await Permission.photos.request();
            if (status == PermissionStatus.granted) {
              hasPermission = true;
            }
          }
        }
      } else if (Platform.isIOS) {
        PermissionStatus status = await Permission.photos.request();
        if (status == PermissionStatus.granted) {
          hasPermission = true;
        }
      } else {
        hasPermission = true;
      }
      
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied. Please enable photo access.')),
        );
        return;
      }

      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((image) => File(image.path)));
          _conversionResult = null;
          _progress = 0.0;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      PermissionStatus status = await Permission.camera.request();
      
      if (status != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission denied.')),
        );
        return;
      }

      final List<String>? scannedImages = await CunningDocumentScanner.getPictures(
        noOfPages: 10,
        isGalleryImportAllowed: true,
      );

      if (scannedImages != null && scannedImages.isNotEmpty) {
        setState(() {
          for (final imagePath in scannedImages) {
            _selectedImages.add(File(imagePath));
          }
          _conversionResult = null;
          _progress = 0.0;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${scannedImages.length} document(s) scanned!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning: ${e.toString()}')),
      );
    }
  }

  Future<void> _convertToPdf() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image')),
      );
      return;
    }

    setState(() {
      _isConverting = true;
      _progress = 0.0;
    });

    try {
      final validImagePaths = <String>[];
      for (final file in _selectedImages) {
        if (file.path.isNotEmpty && await File(file.path).exists()) {
          validImagePaths.add(file.path);
        }
      }

      if (validImagePaths.isEmpty) {
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid images found')),
        );
        return;
      }

      final result = await ImageToPdfConverter.convertImagesToPdf(
        imagePaths: validImagePaths,
        quality: _quality,
        pageSize: _pageSize,
        orientation: _orientation,
        margin: _margin,
        autoRotate: _autoRotate,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );

      if (mounted) {
        setState(() {
          _conversionResult = result;
          _isConverting = false;
          _progress = 1.0;
        });
        
        await HistoryUtils.addToHistory(
          context: context,
          fileName: result.outputPath.split('/').last,
          toolName: 'Images to PDF',
          toolId: 'image_to_pdf',
          filePath: result.outputPath,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF created successfully!')),
        );
        
        // Show interstitial ad after successful operation
        AdService().showInterstitialAfterOperation();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConverting = false;
          _progress = 0.0;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _showRenameDialog() async {
    if (_conversionResult == null) return;
    
    final currentName = _conversionResult!.outputPath.split('/').last.replaceAll('.pdf', '');
    final controller = TextEditingController(text: currentName);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename PDF'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File name',
            suffixText: '.pdf',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    
    if (newName != null && newName.isNotEmpty && newName != currentName) {
      try {
        final oldFile = File(_conversionResult!.outputPath);
        final directory = oldFile.parent.path;
        final newPath = '$directory/$newName.pdf';
        
        await oldFile.rename(newPath);
        
        setState(() {
          _conversionResult = PdfConversionResult(
            success: _conversionResult!.success,
            outputPath: newPath,
            pageCount: _conversionResult!.pageCount,
            fileSize: _conversionResult!.fileSize,
            processedImages: _conversionResult!.processedImages,
            failedCount: _conversionResult!.failedCount,
          );
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed to $newName.pdf')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename: $e')),
        );
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Image to PDF'),
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
              onPressed: () => HelpDialog.show(context, 'image_to_pdf'),
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
                              'Image to PDF',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Convert images to PDF',
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
                        child: const Icon(Icons.image, color: Colors.white, size: 32),
                      ),
                    ],
                  ),
                ),

                // Image Selection
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
                            Icons.add_photo_alternate,
                            size: 48,
                            color: _selectedImages.isNotEmpty ? const Color(0xFF4A80F0) : Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isConverting ? null : _pickImages,
                                  icon: const Icon(Icons.photo_library, size: 18),
                                  label: const Text('Gallery'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isConverting ? null : _pickFromCamera,
                                  icon: const Icon(Icons.document_scanner, size: 18),
                                  label: const Text('Scan'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedImages.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${_selectedImages.length} image(s) selected',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Reorderable Image Grid
                if (_selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('Images (Drag to reorder)'),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 140,
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      onReorder: _onReorder,
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        return Container(
                          key: ValueKey(_selectedImages[index].path),
                          width: 110,
                          margin: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              Card(
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(
                                      _selectedImages[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    ),
                                    // Page number badge
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4A80F0),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Delete button
                              Positioned(
                                top: 4,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Long press and drag to reorder pages',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB0BEC5)
                            : Colors.grey[600], 
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Quality Selection - Visual Cards
                _buildSectionTitle('Image Quality'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: _buildQualityCard(ImageQuality.high, 'High', Icons.hd, '100%')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildQualityCard(ImageQuality.medium, 'Medium', Icons.sd, '75%')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildQualityCard(ImageQuality.low, 'Low', Icons.compress, '50%')),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Page Settings
                _buildSectionTitle('Page Settings'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Page Size Chips
                          const Text('Page Size', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildPageSizeChip(PdfPageFormat.a4, 'A4'),
                              _buildPageSizeChip(PdfPageFormat.letter, 'Letter'),
                              _buildPageSizeChip(PdfPageFormat.a3, 'A3'),
                              _buildPageSizeChip(PdfPageFormat.a5, 'A5'),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Orientation
                          const Text('Orientation', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildOrientationCard(PageOrientation.portrait, 'Portrait', Icons.stay_current_portrait)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildOrientationCard(PageOrientation.landscape, 'Landscape', Icons.stay_current_landscape)),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Auto Rotate & Margin
                          Row(
                            children: [
                              const Text('Auto Rotate', style: TextStyle(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Switch(
                                value: _autoRotate,
                                onChanged: (v) => setState(() => _autoRotate = v),
                                activeColor: const Color(0xFF4A80F0),
                              ),
                            ],
                          ),
                          
                          Text('Margin: ${_margin.toInt()} pts'),
                          Slider(
                            value: _margin,
                            min: 0,
                            max: 50,
                            divisions: 10,
                            onChanged: (v) => setState(() => _margin = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Progress
                if (_isConverting) ...[
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
                        Text('Converting... ${(_progress * 100).toStringAsFixed(0)}%'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Convert Button
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isConverting || _selectedImages.isEmpty ? null : _convertToPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Convert to PDF'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF4A80F0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                // Result
                if (_conversionResult != null) ...[
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
                        const Icon(Icons.check_circle, color: Colors.green, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Created ${_conversionResult!.pageCount} page PDF!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _conversionResult!.outputPath.split('/').last,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFB0BEC5)
                                : Colors.grey[600], 
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => OpenFile.open(_conversionResult!.outputPath),
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
                                onPressed: () => Share.shareXFiles([XFile(_conversionResult!.outputPath)]),
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
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showRenameDialog,
                            icon: const Icon(Icons.edit),
                            label: const Text('Rename PDF'),
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

  Widget _buildQualityCard(ImageQuality quality, String label, IconData icon, String percent) {
    final isSelected = _quality == quality;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _quality = quality),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A80F0) : (isDark ? const Color(0xFF2E2E2E) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF4A80F0).withOpacity(0.3), blurRadius: 8)] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700]), size: 28),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.grey[800]), fontWeight: FontWeight.w600, fontSize: 12)),
            Text(percent, style: TextStyle(color: isSelected ? Colors.white70 : (isDark ? Colors.white54 : Colors.grey[600]), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildPageSizeChip(PdfPageFormat size, String label) {
    final isSelected = _pageSize == size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _pageSize = size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildOrientationCard(PageOrientation orientation, String label, IconData icon) {
    final isSelected = _orientation == orientation;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _orientation = orientation),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A80F0) : (isDark ? const Color(0xFF3E3E3E) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700])),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.grey[700]), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}