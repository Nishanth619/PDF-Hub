import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf_lib;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx_lib;
import 'package:image/image.dart' as img;

/// Parameters for optimize image isolate
img.Image _optimizeImageIsolate(_OptimizeImageParams params) {
  return PdfCompressor._optimizeImage(params.image, params.settings);
}

/// Parameters class for optimize image isolate
class _OptimizeImageParams {
  final img.Image image;
  final CompressionSettings settings;

  _OptimizeImageParams({
    required this.image,
    required this.settings,
  });
}

/// Professional PDF Compressor for Flutter
/// Multiple compression modes with intelligent optimization
class PdfCompressor {
  
  /// Compress PDF with specified quality level
  /// 
  /// [inputPath] - Path to input PDF file
  /// [outputPath] - Output path (optional, auto-generated if null)
  /// [quality] - Compression quality level
  /// [onProgress] - Progress callback (0.0 to 1.0)
  static Future<CompressionResult> compressPdf({
    required String inputPath,
    String? outputPath,
    CompressionQuality quality = CompressionQuality.balanced,
    Function(double)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final inputFile = File(inputPath);
    
    if (!await inputFile.exists()) {
      throw FileSystemException('Input PDF not found', inputPath);
    }

    final originalSize = await inputFile.length();
    
    try {
      final document = await pdfx_lib.PdfDocument.openFile(inputPath);
      final pdf = pw.Document();
      final pageCount = document.pagesCount;
      
      // Get compression settings
      final settings = _getCompressionSettings(quality);
      
      for (int i = 0; i < pageCount; i++) {
        if (onProgress != null) {
          onProgress((i + 1) / pageCount);
        }

        // Render page at optimized resolution
        final page = await document.getPage(i + 1);
        final pageImage = await page.render(
          width: page.width * settings.renderScale,
          height: page.height * settings.renderScale,
          format: pdfx_lib.PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        
        await page.close();

        // Process and compress image
        var image = img.decodeImage(pageImage!.bytes);
        if (image == null) continue;

        // Apply compression optimizations in background isolate
        image = await compute(_optimizeImageIsolate, 
          _OptimizeImageParams(image: image, settings: settings));

        // Encode with JPEG compression
        final compressedBytes = Uint8List.fromList(
          img.encodeJpg(image, quality: settings.jpegQuality)
        );

        final pdfImage = pw.MemoryImage(compressedBytes);

        // Add page to PDF
        pdf.addPage(
          pw.Page(
            pageFormat: pdf_lib.PdfPageFormat(
              page.width * pdf_lib.PdfPageFormat.point / 72,
              page.height * pdf_lib.PdfPageFormat.point / 72,
            ),
            build: (context) => pw.Image(
              pdfImage,
              fit: pw.BoxFit.fill,
            ),
          ),
        );
      }

      await document.close();

      // Save compressed PDF
      final finalPath = outputPath ?? await _generateOutputPath(inputPath);
      final outputFile = File(finalPath);
      await outputFile.writeAsBytes(await pdf.save());

      final compressedSize = await outputFile.length();
      final compressionRatio = ((originalSize - compressedSize) / originalSize * 100);
      final duration = DateTime.now().difference(startTime);

      return CompressionResult(
        success: true,
        inputPath: inputPath,
        outputPath: finalPath,
        originalSize: originalSize,
        compressedSize: compressedSize,
        compressionRatio: compressionRatio,
        pageCount: pageCount,
        duration: duration,
        quality: quality,
      );
    } catch (e) {
      throw Exception('PDF compression failed: $e');
    }
  }

  /// Compress with custom settings
  static Future<CompressionResult> compressWithCustomSettings({
    required String inputPath,
    String? outputPath,
    required CompressionSettings settings,
    Function(double)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final inputFile = File(inputPath);
    final originalSize = await inputFile.length();
    
    try {
      final document = await pdfx_lib.PdfDocument.openFile(inputPath);
      final pdf = pw.Document();
      final pageCount = document.pagesCount;
      
      for (int i = 0; i < pageCount; i++) {
        if (onProgress != null) {
          onProgress((i + 1) / pageCount);
        }

        final page = await document.getPage(i + 1);
        final pageImage = await page.render(
          width: page.width * settings.renderScale,
          height: page.height * settings.renderScale,
          format: pdfx_lib.PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        
        await page.close();

        var image = img.decodeImage(pageImage!.bytes);
        if (image == null) continue;

        // Apply compression optimizations in background isolate
        image = await compute(_optimizeImageIsolate, 
          _OptimizeImageParams(image: image, settings: settings));

        final compressedBytes = Uint8List.fromList(
          img.encodeJpg(image, quality: settings.jpegQuality)
        );

        final pdfImage = pw.MemoryImage(compressedBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: pdf_lib.PdfPageFormat(
              page.width * pdf_lib.PdfPageFormat.point / 72,
              page.height * pdf_lib.PdfPageFormat.point / 72,
            ),
            build: (context) => pw.Image(
              pdfImage,
              fit: pw.BoxFit.fill,
            ),
          ),
        );
      }

      await document.close();

      final finalPath = outputPath ?? await _generateOutputPath(inputPath);
      final outputFile = File(finalPath);
      await outputFile.writeAsBytes(await pdf.save());

      final compressedSize = await outputFile.length();
      final compressionRatio = ((originalSize - compressedSize) / originalSize * 100);
      final duration = DateTime.now().difference(startTime);

      return CompressionResult(
        success: true,
        inputPath: inputPath,
        outputPath: finalPath,
        originalSize: originalSize,
        compressedSize: compressedSize,
        compressionRatio: compressionRatio,
        pageCount: pageCount,
        duration: duration,
      );
    } catch (e) {
      throw Exception('Custom compression failed: $e');
    }
  }

  /// Compress specific pages only
  static Future<CompressionResult> compressPages({
    required String inputPath,
    required List<int> pageNumbers,
    String? outputPath,
    CompressionQuality quality = CompressionQuality.balanced,
    Function(double)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final inputFile = File(inputPath);
    final originalSize = await inputFile.length();
    
    try {
      final document = await pdfx_lib.PdfDocument.openFile(inputPath);
      final pdf = pw.Document();
      final settings = _getCompressionSettings(quality);
      
      for (int i = 0; i < pageNumbers.length; i++) {
        final pageNum = pageNumbers[i];
        
        if (pageNum < 1 || pageNum > document.pagesCount) continue;

        if (onProgress != null) {
          onProgress((i + 1) / pageNumbers.length);
        }

        final page = await document.getPage(pageNum);
        final pageImage = await page.render(
          width: page.width * settings.renderScale,
          height: page.height * settings.renderScale,
          format: pdfx_lib.PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        
        await page.close();

        var image = img.decodeImage(pageImage!.bytes);
        if (image == null) continue;

        // Apply compression optimizations in background isolate
        image = await compute(_optimizeImageIsolate, 
          _OptimizeImageParams(image: image, settings: settings));

        final compressedBytes = Uint8List.fromList(
          img.encodeJpg(image, quality: settings.jpegQuality)
        );

        final pdfImage = pw.MemoryImage(compressedBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: pdf_lib.PdfPageFormat(
              page.width * pdf_lib.PdfPageFormat.point / 72,
              page.height * pdf_lib.PdfPageFormat.point / 72,
            ),
            build: (context) => pw.Image(
              pdfImage,
              fit: pw.BoxFit.fill,
            ),
          ),
        );
      }

      await document.close();

      final finalPath = outputPath ?? await _generateOutputPath(inputPath);
      final outputFile = File(finalPath);
      await outputFile.writeAsBytes(await pdf.save());

      final compressedSize = await outputFile.length();
      final compressionRatio = ((originalSize - compressedSize) / originalSize * 100);
      final duration = DateTime.now().difference(startTime);

      return CompressionResult(
        success: true,
        inputPath: inputPath,
        outputPath: finalPath,
        originalSize: originalSize,
        compressedSize: compressedSize,
        compressionRatio: compressionRatio,
        pageCount: pageNumbers.length,
        duration: duration,
        quality: quality,
      );
    } catch (e) {
      throw Exception('Page compression failed: $e');
    }
  }

  /// Optimize image based on settings
  static img.Image _optimizeImage(img.Image image, CompressionSettings settings) {
    var optimized = image;

    // 1. Resize if needed (major size reduction)
    if (settings.maxDimension > 0) {
      if (image.width > settings.maxDimension || image.height > settings.maxDimension) {
        if (image.width > image.height) {
          optimized = img.copyResize(
            optimized,
            width: settings.maxDimension,
            interpolation: img.Interpolation.cubic,
          );
        } else {
          optimized = img.copyResize(
            optimized,
            height: settings.maxDimension,
            interpolation: img.Interpolation.cubic,
          );
        }
      }
    }

    // 2. Convert to grayscale if enabled (50% reduction)
    if (settings.grayscale) {
      optimized = img.grayscale(optimized);
    }

    // 3. Apply color quantization (reduce colors for smaller size)
    if (settings.colorQuantization && !settings.grayscale) {
      optimized = img.quantize(
        optimized,
        numberOfColors: settings.numberOfColors,
      );
    }

    // 4. Reduce noise (smoother compression)
    if (settings.reduceNoise) {
      optimized = img.gaussianBlur(optimized, radius: 1);
    }

    // 5. Adjust contrast slightly (better for compression)
    if (settings.enhanceForCompression) {
      optimized = img.adjustColor(
        optimized,
        contrast: 1.05,
        brightness: 1.02,
      );
    }

    return optimized;
  }

  /// Get predefined compression settings
  static CompressionSettings _getCompressionSettings(CompressionQuality quality) {
    switch (quality) {
      case CompressionQuality.maximum:
        return CompressionSettings(
          renderScale: 1.0,
          jpegQuality: 50,
          maxDimension: 1200,
          grayscale: false,
          colorQuantization: false,  // Disabled - was causing B&W output
          numberOfColors: 256,
          reduceNoise: true,
          enhanceForCompression: true,
        );
      
      case CompressionQuality.high:
        return CompressionSettings(
          renderScale: 1.2,
          jpegQuality: 60,
          maxDimension: 1600,
          grayscale: false,
          colorQuantization: false,  // Disabled - was causing washed-out colors
          numberOfColors: 256,
          reduceNoise: false,
          enhanceForCompression: true,
        );
      
      case CompressionQuality.balanced:
        return CompressionSettings(
          renderScale: 1.5,
          jpegQuality: 75,
          maxDimension: 2000,
          grayscale: false,
          colorQuantization: false,
          numberOfColors: 256,
          reduceNoise: false,
          enhanceForCompression: false,
        );
      
      case CompressionQuality.low:
        return CompressionSettings(
          renderScale: 2.0,
          jpegQuality: 85,
          maxDimension: 2400,
          grayscale: false,
          colorQuantization: false,
          numberOfColors: 256,
          reduceNoise: false,
          enhanceForCompression: false,
        );
      
      case CompressionQuality.minimal:
        return CompressionSettings(
          renderScale: 2.0,
          jpegQuality: 90,
          maxDimension: 3000,
          grayscale: false,
          colorQuantization: false,
          numberOfColors: 256,
          reduceNoise: false,
          enhanceForCompression: false,
        );
    }
  }

  static Future<String> _generateOutputPath(String inputPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = inputPath.split('/').last.replaceAll('.pdf', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/${fileName}_compressed_$timestamp.pdf';
  }

  /// Get estimated compression ratio without processing
  static Future<EstimatedCompression> estimateCompression({
    required String inputPath,
    required CompressionQuality quality,
  }) async {
    final file = File(inputPath);
    final originalSize = await file.length();
    
    // Estimate based on quality level
    double estimatedRatio;
    switch (quality) {
      case CompressionQuality.maximum:
        estimatedRatio = 75; // 75% reduction
        break;
      case CompressionQuality.high:
        estimatedRatio = 60; // 60% reduction
        break;
      case CompressionQuality.balanced:
        estimatedRatio = 40; // 40% reduction
        break;
      case CompressionQuality.low:
        estimatedRatio = 20; // 20% reduction
        break;
      case CompressionQuality.minimal:
        estimatedRatio = 10; // 10% reduction
        break;
    }

    final estimatedSize = (originalSize * (1 - estimatedRatio / 100)).toInt();

    return EstimatedCompression(
      originalSize: originalSize,
      estimatedSize: estimatedSize,
      estimatedRatio: estimatedRatio,
      quality: quality,
    );
  }
}

/// Compression quality levels
enum CompressionQuality {
  maximum,  // 70-80% reduction, visible quality loss
  high,     // 50-65% reduction, slight quality loss
  balanced, // 35-50% reduction, minimal quality loss (recommended)
  low,      // 15-30% reduction, imperceptible quality loss
  minimal,  // 5-15% reduction, no visible quality loss
}

/// Compression settings
class CompressionSettings {
  final double renderScale;
  final int jpegQuality;
  final int maxDimension;
  final bool grayscale;
  final bool colorQuantization;
  final int numberOfColors;
  final bool reduceNoise;
  final bool enhanceForCompression;

  CompressionSettings({
    this.renderScale = 1.5,
    this.jpegQuality = 75,
    this.maxDimension = 2000,
    this.grayscale = false,
    this.colorQuantization = false,
    this.numberOfColors = 256,
    this.reduceNoise = false,
    this.enhanceForCompression = false,
  });
}

/// Compression result
class CompressionResult {
  final bool success;
  final String inputPath;
  final String outputPath;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;
  final int pageCount;
  final Duration duration;
  final CompressionQuality? quality;

  CompressionResult({
    required this.success,
    required this.inputPath,
    required this.outputPath,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
    required this.pageCount,
    required this.duration,
    this.quality,
  });

  String get originalSizeFormatted => _formatBytes(originalSize);
  String get compressedSizeFormatted => _formatBytes(compressedSize);
  String get savedSize => _formatBytes(originalSize - compressedSize);
  String get compressionRatioFormatted => '${compressionRatio.toStringAsFixed(1)}%';

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  String toString() {
    return 'Compression Result:\n'
           'Original: $originalSizeFormatted\n'
           'Compressed: $compressedSizeFormatted\n'
           'Saved: $savedSize ($compressionRatioFormatted)\n'
           'Pages: $pageCount\n'
           'Time: ${duration.inSeconds}s';
  }
}

/// Estimated compression
class EstimatedCompression {
  final int originalSize;
  final int estimatedSize;
  final double estimatedRatio;
  final CompressionQuality quality;

  EstimatedCompression({
    required this.originalSize,
    required this.estimatedSize,
    required this.estimatedRatio,
    required this.quality,
  });

  String get originalSizeFormatted => _formatBytes(originalSize);
  String get estimatedSizeFormatted => _formatBytes(estimatedSize);
  String get estimatedSaved => _formatBytes(originalSize - estimatedSize);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// PDF Compressor Widget
class PdfCompressorWidget extends StatefulWidget {
  const PdfCompressorWidget({super.key});

  @override
  _PdfCompressorWidgetState createState() => _PdfCompressorWidgetState();
}

class _PdfCompressorWidgetState extends State<PdfCompressorWidget> {
  String? _inputPath;
  CompressionQuality _selectedQuality = CompressionQuality.balanced;
  double _progress = 0.0;
  String _status = 'Select a PDF to compress';
  CompressionResult? _result;
  EstimatedCompression? _estimate;
  bool _isCompressing = false;

  Future<void> _selectPdf() async {
    // TODO: Integrate file picker
    // Example path for testing
    // _inputPath = '/path/to/pdf';
    
    if (_inputPath != null) {
      _estimateCompression();
    }
  }

  Future<void> _estimateCompression() async {
    if (_inputPath == null) return;

    try {
      final estimate = await PdfCompressor.estimateCompression(
        inputPath: _inputPath!,
        quality: _selectedQuality,
      );

      setState(() {
        _estimate = estimate;
        _status = 'Ready to compress';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _compressPdf() async {
    if (_inputPath == null) return;

    setState(() {
      _isCompressing = true;
      _status = 'Compressing PDF...';
      _progress = 0.0;
      _result = null;
    });

    try {
      final result = await PdfCompressor.compressPdf(
        inputPath: _inputPath!,
        quality: _selectedQuality,
        onProgress: (p) {
          setState(() {
            _progress = p;
            _status = 'Compressing: ${(p * 100).toInt()}%';
          });
        },
      );

      setState(() {
        _result = result;
        _status = 'Compression complete!';
        _isCompressing = false;
      });

      _showResultDialog(result);
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isCompressing = false;
      });
    }
  }

  void _showResultDialog(CompressionResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Compression Complete',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 24),
            _buildResultRow('Original Size', result.originalSizeFormatted),
            _buildResultRow('Compressed Size', result.compressedSizeFormatted),
            _buildResultRow('Saved', result.savedSize, 
              color: Colors.green[700]),
            _buildResultRow('Reduction', result.compressionRatioFormatted, 
              color: Colors.blue[700]),
            _buildResultRow('Pages', '${result.pageCount}'),
            _buildResultRow('Time', '${result.duration.inSeconds}s'),
            const SizedBox(height: 12),
            const Text('Saved to:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(result.outputPath,
              style: const TextStyle(fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Compressor'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quality Selection
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Compression Quality',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildQualityOption(
                      CompressionQuality.maximum,
                      'Maximum Compression',
                      '70-80% reduction - Smallest file',
                      Icons.compress,
                      Colors.red,
                    ),
                    _buildQualityOption(
                      CompressionQuality.high,
                      'High Compression',
                      '50-65% reduction - Small file',
                      Icons.arrow_downward,
                      Colors.orange,
                    ),
                    _buildQualityOption(
                      CompressionQuality.balanced,
                      'Balanced',
                      '35-50% reduction - Good balance (Recommended)',
                      Icons.balance,
                      Colors.blue,
                    ),
                    _buildQualityOption(
                      CompressionQuality.low,
                      'Low Compression',
                      '15-30% reduction - High quality',
                      Icons.high_quality,
                      Colors.green,
                    ),
                    _buildQualityOption(
                      CompressionQuality.minimal,
                      'Minimal Compression',
                      '5-15% reduction - Best quality',
                      Icons.hd,
                      Colors.purple,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Estimate
            if (_estimate != null) ...[
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text('Estimated Result',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      _buildEstimateRow('Original', _estimate!.originalSizeFormatted),
                      _buildEstimateRow('Estimated', _estimate!.estimatedSizeFormatted),
                      _buildEstimateRow('Will Save', _estimate!.estimatedSaved,
                        color: Colors.green[700]),
                      _buildEstimateRow('Reduction', '~${_estimate!.estimatedRatio.toStringAsFixed(0)}%',
                        color: Colors.blue[700]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_status,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    if (_isCompressing) ...[
                      const SizedBox(height: 16),
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
                          Text('Compressed Successfully!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[900],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildResultRow('Original', _result!.originalSizeFormatted),
                      _buildResultRow('Compressed', _result!.compressedSizeFormatted),
                      _buildResultRow('Saved', _result!.savedSize,
                        color: Colors.green[700]),
                      _buildResultRow('Reduction', _result!.compressionRatioFormatted,
                        color: Colors.blue[700]),
                      _buildResultRow('Pages', '${_result!.pageCount}'),
                      _buildResultRow('Time', '${_result!.duration.inSeconds}s'),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            if (_inputPath == null)
              ElevatedButton.icon(
                onPressed: _selectPdf,
                icon: const Icon(Icons.file_upload, size: 24),
                label: const Text('Select PDF', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _isCompressing ? null : _compressPdf,
                icon: const Icon(Icons.compress, size: 24),
                label: const Text('Compress PDF', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(
    CompressionQuality quality,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedQuality == quality;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedQuality = quality;
        });
        if (_inputPath != null) {
          _estimateCompression();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
              color: isSelected ? color : Colors.grey[600],
              size: 28,
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
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimateRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
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
