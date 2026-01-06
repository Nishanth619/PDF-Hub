import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Parameters for process image isolate
_ProcessImageResult _processImageIsolate(_ProcessImageParams params) {
  return _ProcessImageResult(
    image: ImageToPdfConverter._processImage(params.image, params.quality, params.compress),
  );
}

/// Parameters class for process image isolate
class _ProcessImageParams {
  final img.Image image;
  final ImageQuality quality;
  final bool compress;

  _ProcessImageParams({
    required this.image,
    required this.quality,
    required this.compress,
  });
}

/// Result class for process image isolate
class _ProcessImageResult {
  final img.Image image;

  _ProcessImageResult({required this.image});
}

/// Parameters for copy rotate isolate
_CopyRotateResult _copyRotateIsolate(_CopyRotateParams params) {
  return _CopyRotateResult(
    image: img.copyRotate(params.image, angle: params.angle),
  );
}

/// Parameters class for copy rotate isolate
class _CopyRotateParams {
  final img.Image image;
  final double angle;

  _CopyRotateParams({
    required this.image,
    required this.angle,
  });
}

/// Result class for copy rotate isolate
class _CopyRotateResult {
  final img.Image image;

  _CopyRotateResult({required this.image});
}

/// Parameters for copy crop isolate
_CopyCropResult _copyCropIsolate(_CopyCropParams params) {
  return _CopyCropResult(
    image: img.copyCrop(
      params.image,
      x: params.x,
      y: params.y,
      width: params.width,
      height: params.height,
    ),
  );
}

/// Parameters class for copy crop isolate
class _CopyCropParams {
  final img.Image image;
  final int x;
  final int y;
  final int width;
  final int height;

  _CopyCropParams({
    required this.image,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Result class for copy crop isolate
class _CopyCropResult {
  final img.Image image;

  _CopyCropResult({required this.image});
}

/// Powerful Mobile Image to PDF Converter
/// Optimized for performance, quality, and memory efficiency
class ImageToPdfConverter {
  /// Convert multiple images to a single PDF
  /// 
  /// [imagePaths] - List of image file paths
  /// [outputPath] - Output PDF file path (optional, auto-generated if null)
  /// [quality] - Compression quality: 'high', 'medium', 'low'
  /// [pageSize] - PDF page size (default: A4)
  /// [orientation] - 'portrait' or 'landscape' (auto-detect if null)
  /// [margin] - Page margins in points
  static Future<PdfConversionResult> convertImagesToPdf({
    required List<String> imagePaths,
    String? outputPath,
    ImageQuality quality = ImageQuality.high,
    PdfPageFormat? pageSize,
    PageOrientation? orientation,
    double margin = 20.0,
    bool autoRotate = true,
    bool compress = true,
    Function(double)? onProgress,
  }) async {
    if (imagePaths.isEmpty) {
      throw Exception('No images provided');
    }

    final pdf = pw.Document();
    final processedImages = <ProcessedImage>[];
    int successCount = 0;
    int failedCount = 0;

    try {
      for (int i = 0; i < imagePaths.length; i++) {
        try {
          if (onProgress != null) {
            onProgress((i + 1) / imagePaths.length);
          }

          // Validate image path
          if (imagePaths[i].isEmpty) {
            failedCount++;
            continue;
          }

          // Load and process image
          final imageFile = File(imagePaths[i]);
          if (!await imageFile.exists()) {
            print('Image file does not exist: ${imagePaths[i]}');
            failedCount++;
            continue;
          }

          // Check file size to prevent memory issues
          final fileSize = await imageFile.length();
          if (fileSize > 50 * 1024 * 1024) { // 50MB limit
            print('Image file too large: ${imagePaths[i]} (${fileSize / (1024 * 1024)} MB)');
            failedCount++;
            continue;
          }

          final imageBytes = await imageFile.readAsBytes();
          if (imageBytes.isEmpty) {
            print('Image file is empty: ${imagePaths[i]}');
            failedCount++;
            continue;
          }

          var image = img.decodeImage(imageBytes);
          if (image == null) {
            print('Failed to decode image: ${imagePaths[i]}');
            failedCount++;
            continue;
          }

          // Process image based on quality settings in background isolate
          final result = await compute(_processImageIsolate, 
            _ProcessImageParams(image: image, quality: quality, compress: compress));
          image = result.image;

          // Determine orientation
          final isLandscape = image.width > image.height;
          final finalOrientation = orientation ?? 
            (autoRotate 
              ? (isLandscape ? PageOrientation.landscape : PageOrientation.portrait)
              : PageOrientation.portrait);

          // Encode to JPEG for smaller file size with error handling
          Uint8List processedBytes;
          try {
            processedBytes = Uint8List.fromList(
              img.encodeJpg(image, quality: _getJpegQuality(quality))
            );
          } catch (e) {
            print('Failed to encode image: $e');
            failedCount++;
            continue;
          }

          final pdfImage = pw.MemoryImage(processedBytes);

          // Calculate dimensions to fit page
          final format = pageSize ?? PdfPageFormat.a4;
          final pageWidth = finalOrientation == PageOrientation.portrait 
            ? format.width 
            : format.height;
          final pageHeight = finalOrientation == PageOrientation.portrait 
            ? format.height 
            : format.width;

          final availableWidth = pageWidth - (margin * 2);
          final availableHeight = pageHeight - (margin * 2);

          // Add page with image
          pdf.addPage(
            pw.Page(
              pageFormat: format.copyWith(
                width: pageWidth,
                height: pageHeight,
              ),
              margin: pw.EdgeInsets.all(margin),
              build: (context) {
                return pw.Center(
                  child: pw.Image(
                    pdfImage,
                    fit: pw.BoxFit.contain,
                    width: availableWidth,
                    height: availableHeight,
                  ),
                );
              },
            ),
          );

          processedImages.add(ProcessedImage(
            originalPath: imagePaths[i],
            width: image.width,
            height: image.height,
            fileSize: processedBytes.length,
            pageNumber: i + 1,
          ));

          successCount++;
        } catch (e, stackTrace) {
          print('Failed to process image ${imagePaths[i]}: $e');
          print('Stack trace: $stackTrace');
          failedCount++;
        }
      }

      // Check if we have any successful images
      if (successCount == 0) {
        throw Exception('No images could be processed successfully');
      }

      // Generate output path if not provided
      final finalOutputPath = outputPath ?? await _generateOutputPath();

      // Save PDF with error handling
      try {
        final file = File(finalOutputPath);
        // Ensure directory exists
        await file.create(recursive: true);
        final pdfBytes = await pdf.save();
        await file.writeAsBytes(pdfBytes);

        final fileSize = await file.length();

        return PdfConversionResult(
          success: true,
          outputPath: finalOutputPath,
          pageCount: successCount,
          fileSize: fileSize,
          processedImages: processedImages,
          failedCount: failedCount,
        );
      } catch (e, stackTrace) {
        print('Failed to save PDF: $e');
        print('Stack trace: $stackTrace');
        throw Exception('Failed to save PDF file: $e');
      }
    } catch (e, stackTrace) {
      print('PDF conversion failed: $e');
      print('Stack trace: $stackTrace');
      // Clean up any resources
      processedImages.clear();
      rethrow;
    }
  }

  /// Convert single image to PDF
  static Future<PdfConversionResult> convertSingleImageToPdf({
    required String imagePath,
    String? outputPath,
    ImageQuality quality = ImageQuality.high,
    PdfPageFormat? pageSize,
    bool autoRotate = true,
  }) async {
    // Validate image path
    if (imagePath.isEmpty) {
      throw Exception('No image provided');
    }

    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist: $imagePath');
    }

    // Check file size to prevent memory issues
    final fileSize = await imageFile.length();
    if (fileSize > 50 * 1024 * 1024) { // 50MB limit
      throw Exception('Image file too large: $imagePath (${fileSize / (1024 * 1024)} MB)');
    }

    return await convertImagesToPdf(
      imagePaths: [imagePath],
      outputPath: outputPath,
      quality: quality,
      pageSize: pageSize,
      autoRotate: autoRotate,
    );
  }

  /// Convert images with custom page settings per image
  static Future<PdfConversionResult> convertWithCustomPages({
    required List<ImagePageConfig> pageConfigs,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    final pdf = pw.Document();
    final processedImages = <ProcessedImage>[];
    int successCount = 0;
    int failedCount = 0;

    try {
      for (int i = 0; i < pageConfigs.length; i++) {
        try {
          if (onProgress != null) {
            onProgress((i + 1) / pageConfigs.length);
          }

          final config = pageConfigs[i];
          
          // Validate image path
          if (config.imagePath.isEmpty) {
            failedCount++;
            continue;
          }

          final imageFile = File(config.imagePath);
          
          if (!await imageFile.exists()) {
            print('Image file does not exist: ${config.imagePath}');
            failedCount++;
            continue;
          }

          // Check file size to prevent memory issues
          final fileSize = await imageFile.length();
          if (fileSize > 50 * 1024 * 1024) { // 50MB limit
            print('Image file too large: ${config.imagePath} (${fileSize / (1024 * 1024)} MB)');
            failedCount++;
            continue;
          }

          final imageBytes = await imageFile.readAsBytes();
          if (imageBytes.isEmpty) {
            print('Image file is empty: ${config.imagePath}');
            failedCount++;
            continue;
          }

          var image = img.decodeImage(imageBytes);
          
          if (image == null) {
            print('Failed to decode image: ${config.imagePath}');
            failedCount++;
            continue;
          }

          // Apply custom transformations with error handling
          try {
            if (config.rotate != 0) {
              final result = await compute(_copyRotateIsolate, 
                _CopyRotateParams(image: image, angle: config.rotate));
              image = result.image;
            }

            if (config.crop != null) {
              final crop = config.crop!;
              final result = await compute(_copyCropIsolate, 
                _CopyCropParams(
                  image: image,
                  x: crop.left.toInt(),
                  y: crop.top.toInt(),
                  width: crop.width.toInt(),
                  height: crop.height.toInt(),
                ));
              image = result.image;
            }
          } catch (e) {
            print('Error applying transformations to image: $e');
            // Continue with original image if transformations fail
          }

          // Process image in background isolate
          final result = await compute(_processImageIsolate, 
            _ProcessImageParams(image: image!, quality: config.quality, compress: config.compress));
          image = result.image;

          Uint8List processedBytes;
          try {
            processedBytes = Uint8List.fromList(
              img.encodeJpg(image, quality: _getJpegQuality(config.quality))
            );
          } catch (e) {
            print('Failed to encode image: $e');
            failedCount++;
            continue;
          }

          final pdfImage = pw.MemoryImage(processedBytes);

          // Add page
          pdf.addPage(
            pw.Page(
              pageFormat: config.pageSize ?? PdfPageFormat.a4,
              margin: pw.EdgeInsets.all(config.margin),
              build: (context) {
                return pw.Center(
                  child: pw.Image(
                    pdfImage,
                    fit: pw.BoxFit.contain,
                  ),
                );
              },
            ),
          );

          processedImages.add(ProcessedImage(
            originalPath: config.imagePath,
            width: image.width,
            height: image.height,
            fileSize: processedBytes.length,
            pageNumber: i + 1,
          ));

          successCount++;
        } catch (e, stackTrace) {
          print('Failed to process page ${i + 1}: $e');
          print('Stack trace: $stackTrace');
          failedCount++;
        }
      }

      // Check if we have any successful images
      if (successCount == 0) {
        throw Exception('No images could be processed successfully');
      }

      final finalOutputPath = outputPath ?? await _generateOutputPath();
      
      try {
        final file = File(finalOutputPath);
        // Ensure directory exists
        await file.create(recursive: true);
        final pdfBytes = await pdf.save();
        await file.writeAsBytes(pdfBytes);

        return PdfConversionResult(
          success: true,
          outputPath: finalOutputPath,
          pageCount: successCount,
          fileSize: await file.length(),
          processedImages: processedImages,
          failedCount: failedCount,
        );
      } catch (e, stackTrace) {
        print('Failed to save custom PDF: $e');
        print('Stack trace: $stackTrace');
        throw Exception('Failed to save PDF file: $e');
      }
    } catch (e, stackTrace) {
      print('Custom PDF conversion failed: $e');
      print('Stack trace: $stackTrace');
      // Clean up any resources
      processedImages.clear();
      rethrow;
    }
  }

  /// Create PDF from images with text overlay
  static Future<PdfConversionResult> convertWithText({
    required List<ImageWithText> imagesWithText,
    String? outputPath,
    ImageQuality quality = ImageQuality.high,
    Function(double)? onProgress,
  }) async {
    final pdf = pw.Document();
    final processedImages = <ProcessedImage>[];

    try {
      for (int i = 0; i < imagesWithText.length; i++) {
        try {
          if (onProgress != null) {
            onProgress((i + 1) / imagesWithText.length);
          }

          final item = imagesWithText[i];
          
          // Validate image path
          if (item.imagePath.isEmpty) {
            continue;
          }

          final imageFile = File(item.imagePath);
          if (!await imageFile.exists()) {
            print('Image file does not exist: ${item.imagePath}');
            continue;
          }

          final imageBytes = await imageFile.readAsBytes();
          if (imageBytes.isEmpty) {
            print('Image file is empty: ${item.imagePath}');
            continue;
          }

          var image = img.decodeImage(imageBytes);
          if (image == null) {
            print('Failed to decode image: ${item.imagePath}');
            continue;
          }

          // Process image in background isolate
          final result = await compute(_processImageIsolate, 
            _ProcessImageParams(image: image, quality: quality, compress: true));
          image = result.image;
          
          Uint8List processedBytes;
          try {
            processedBytes = Uint8List.fromList(
              img.encodeJpg(image, quality: _getJpegQuality(quality))
            );
          } catch (e) {
            print('Failed to encode image: $e');
            continue;
          }

          final pdfImage = pw.MemoryImage(processedBytes);

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (item.title != null)
                      pw.Text(
                        item.title!,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    if (item.title != null) pw.SizedBox(height: 10),
                    pw.Expanded(
                      child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                    ),
                    if (item.description != null) pw.SizedBox(height: 10),
                    if (item.description != null)
                      pw.Text(
                        item.description!,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                  ],
                );
              },
            ),
          );

          processedImages.add(ProcessedImage(
            originalPath: item.imagePath,
            width: image.width,
            height: image.height,
            fileSize: processedBytes.length,
            pageNumber: i + 1,
          ));
        } catch (e, stackTrace) {
          print('Failed to process image with text ${imagesWithText[i].imagePath}: $e');
          print('Stack trace: $stackTrace');
          continue;
        }
      }

      // Check if we have any successful images
      if (processedImages.isEmpty) {
        throw Exception('No images could be processed successfully');
      }

      final finalOutputPath = outputPath ?? await _generateOutputPath();
      
      try {
        final file = File(finalOutputPath);
        // Ensure directory exists
        await file.create(recursive: true);
        final pdfBytes = await pdf.save();
        await file.writeAsBytes(pdfBytes);

        return PdfConversionResult(
          success: true,
          outputPath: finalOutputPath,
          pageCount: processedImages.length,
          fileSize: await file.length(),
          processedImages: processedImages,
          failedCount: imagesWithText.length - processedImages.length,
        );
      } catch (e, stackTrace) {
        print('Failed to save PDF with text: $e');
        print('Stack trace: $stackTrace');
        throw Exception('Failed to save PDF file: $e');
      }
    } catch (e, stackTrace) {
      print('PDF with text conversion failed: $e');
      print('Stack trace: $stackTrace');
      // Clean up any resources
      processedImages.clear();
      rethrow;
    }
  }

  /// Process image based on quality settings
  static img.Image _processImage(
    img.Image image,
    ImageQuality quality,
    bool compress,
  ) {
    var processed = image;

    if (compress) {
      try {
        // Resize if too large (memory optimization)
        final maxDimension = _getMaxDimension(quality);
        if (image.width > maxDimension || image.height > maxDimension) {
          if (image.width > image.height) {
            processed = img.copyResize(
              processed,
              width: maxDimension,
              interpolation: img.Interpolation.cubic,
            );
          } else {
            processed = img.copyResize(
              processed,
              height: maxDimension,
              interpolation: img.Interpolation.cubic,
            );
          }
        }
      } catch (e) {
        print('Error resizing image: $e');
        // If resizing fails, use original image
        processed = image;
      }
    }

    // Enhance image quality with error handling
    if (quality == ImageQuality.high) {
      try {
        processed = img.adjustColor(
          processed,
          contrast: 1.1,
          brightness: 1.02,
        );
      } catch (e) {
        print('Error enhancing image: $e');
        // If enhancement fails, use resized image
      }
    }

    return processed;
  }

  static int _getMaxDimension(ImageQuality quality) {
    switch (quality) {
      case ImageQuality.high:
        return 1800; // Optimized for speed while maintaining quality
      case ImageQuality.medium:
        return 1200;
      case ImageQuality.low:
        return 800;
    }
  }

  static int _getJpegQuality(ImageQuality quality) {
    switch (quality) {
      case ImageQuality.high:
        return 85;
      case ImageQuality.medium:
        return 70;
      case ImageQuality.low:
        return 55;
    }
  }

  static Future<String> _generateOutputPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/converted_$timestamp.pdf';
  }
}

/// Image quality settings
enum ImageQuality { high, medium, low }

/// Page orientation
enum PageOrientation { portrait, landscape }

/// Configuration for individual page
class ImagePageConfig {
  final String imagePath;
  final ImageQuality quality;
  final PdfPageFormat? pageSize;
  final double margin;
  final double rotate;
  final Rect? crop;
  final bool compress;

  ImagePageConfig({
    required this.imagePath,
    this.quality = ImageQuality.high,
    this.pageSize,
    this.margin = 20.0,
    this.rotate = 0.0,
    this.crop,
    this.compress = true,
  });
}

/// Image with text overlay
class ImageWithText {
  final String imagePath;
  final String? title;
  final String? description;

  ImageWithText({
    required this.imagePath,
    this.title,
    this.description,
  });
}

/// Processed image information
class ProcessedImage {
  final String originalPath;
  final int width;
  final int height;
  final int fileSize;
  final int pageNumber;

  ProcessedImage({
    required this.originalPath,
    required this.width,
    required this.height,
    required this.fileSize,
    required this.pageNumber,
  });

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// PDF conversion result
class PdfConversionResult {
  final bool success;
  final String outputPath;
  final int pageCount;
  final int fileSize;
  final List<ProcessedImage> processedImages;
  final int failedCount;

  PdfConversionResult({
    required this.success,
    required this.outputPath,
    required this.pageCount,
    required this.fileSize,
    required this.processedImages,
    required this.failedCount,
  });

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() {
    return 'PDF Conversion Result:\n'
           'Success: $success\n'
           'Output: $outputPath\n'
           'Pages: $pageCount\n'
           'Size: $fileSizeFormatted\n'
           'Failed: $failedCount';
  }
}

/// Flutter Widget for Image to PDF Conversion
class ImageToPdfWidget extends StatefulWidget {
  const ImageToPdfWidget({super.key});

  @override
  _ImageToPdfWidgetState createState() => _ImageToPdfWidgetState();
}

class _ImageToPdfWidgetState extends State<ImageToPdfWidget> {
  final List<String> _selectedImages = [];
  double _progress = 0.0;
  String _status = 'Select images to convert';
  PdfConversionResult? _result;
  ImageQuality _quality = ImageQuality.high;
  bool _autoRotate = true;
  bool _compress = true;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.clear();
          _selectedImages.addAll(images.map((img) => img.path));
          _status = '${_selectedImages.length} image(s) selected';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error picking images: $e';
      });
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      
      if (image != null) {
        setState(() {
          _selectedImages.add(image.path);
          _status = '${_selectedImages.length} image(s) selected';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error taking photo: $e';
      });
    }
  }

  Future<void> _convertToPdf() async {
    if (_selectedImages.isEmpty) {
      setState(() {
        _status = 'Please select images first';
      });
      return;
    }

    setState(() {
      _status = 'Converting to PDF...';
      _progress = 0.0;
      _result = null;
    });

    try {
      final result = await ImageToPdfConverter.convertImagesToPdf(
        imagePaths: _selectedImages,
        quality: _quality,
        autoRotate: _autoRotate,
        compress: _compress,
        onProgress: (p) {
          if (mounted) {
            setState(() => _progress = p);
          }
        },
      );

      if (mounted) {
        setState(() {
          _status = 'Conversion complete!';
          _result = result;
          _progress = 1.0;
        });
      }
    } catch (e, stackTrace) {
      print('PDF conversion error in widget: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _status = 'Error: ${e.toString()}';
          _progress = 0.0;
        });
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _status = '${_selectedImages.length} image(s) selected';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image to PDF Converter'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quality Settings
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Conversion Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    const Text('Quality', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    _buildQualityOption(ImageQuality.high, 'High Quality', 
                      'Best quality, larger file size', Icons.high_quality),
                    _buildQualityOption(ImageQuality.medium, 'Medium Quality', 
                      'Balanced (Recommended)', Icons.hd),
                    _buildQualityOption(ImageQuality.low, 'Low Quality', 
                      'Smaller file size', Icons.sd),
                    
                    const Divider(height: 24),
                    
                    SwitchListTile(
                      title: const Text('Auto-rotate pages'),
                      subtitle: const Text('Automatically adjust orientation'),
                      value: _autoRotate,
                      onChanged: (v) => setState(() => _autoRotate = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    SwitchListTile(
                      title: const Text('Compress images'),
                      subtitle: const Text('Reduce file size (recommended)'),
                      value: _compress,
                      onChanged: (v) => setState(() => _compress = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Image Selection Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pick Images'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),

            // Selected Images
            if (_selectedImages.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Selected Images (${_selectedImages.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _selectedImages.clear();
                              _status = 'Select images to convert';
                            }),
                            icon: const Icon(Icons.clear_all, size: 18),
                            label: const Text('Clear All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(_selectedImages[index]),
                                        fit: BoxFit.cover,
                                        width: 100,
                                        height: 120,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, 
                                          color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('${index + 1}',
                                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Status & Progress
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_status,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    if (_progress > 0) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text('${(_progress * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),

            // Result
            if (_result != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green[50],
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700], size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('PDF Created Successfully!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildResultRow(Icons.insert_drive_file, 'File Size',
                        _result!.fileSizeFormatted),
                      _buildResultRow(Icons.pages, 'Pages',
                        '${_result!.pageCount}'),
                      if (_result!.failedCount > 0)
                        _buildResultRow(Icons.warning, 'Failed',
                          '${_result!.failedCount}', color: Colors.orange),
                      const SizedBox(height: 12),
                      const Text('Location:',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                      Text(_result!.outputPath,
                        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            
            // Convert Button
            ElevatedButton.icon(
              onPressed: _selectedImages.isEmpty ? null : _convertToPdf,
              icon: const Icon(Icons.picture_as_pdf, size: 24),
              label: const Text('Convert to PDF', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(18),
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(ImageQuality value, String title, 
    String description, IconData icon) {
    final isSelected = _quality == value;
    return InkWell(
      onTap: () => setState(() => _quality = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.grey[50],
          border: Border.all(
            color: isSelected ? Colors.blue[700]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
              color: isSelected ? Colors.blue[700] : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blue[900] : Colors.black87,
                    ),
                  ),
                  Text(description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.blue[700], size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
