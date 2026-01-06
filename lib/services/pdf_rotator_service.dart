import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Powerful PDF Rotator for Flutter using Syncfusion
/// Rotates PDF pages accurately and efficiently
class PdfRotator {
  /// Rotate all pages in a PDF
  /// 
  /// [pdfPath] - Path to the PDF file
  /// [rotation] - Rotation angle (90, 180, 270, or -90, -180, -270)
  /// [outputPath] - Optional output path
  static Future<RotationResult> rotateAllPages({
    required String pdfPath,
    required int rotation,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    final validRotation = _normalizeRotation(rotation);
    final originalBytes = await _readPdfBytes(pdfPath);
    final document = PdfDocument(inputBytes: originalBytes);

    try {
      final pageCount = document.pages.count;

      for (int i = 0; i < pageCount; i++) {
        final page = document.pages[i];
        page.rotation = _getPdfRotation(validRotation);

        if (onProgress != null) {
          onProgress((i + 1) / pageCount);
        }
      }

      final outputBytes = await document.save();
      final finalOutputPath = outputPath ?? await _getDefaultOutputPath('rotated');
      await File(finalOutputPath).writeAsBytes(outputBytes);

      document.dispose();

      return RotationResult(
        outputPath: finalOutputPath,
        rotatedPages: pageCount,
        rotation: validRotation,
      );
    } catch (e) {
      document.dispose();
      throw Exception('Error rotating PDF: $e');
    }
  }

  /// Rotate specific pages
  /// 
  /// [pageNumbers] - List of page numbers to rotate (1-indexed)
  /// [rotation] - Rotation angle
  static Future<RotationResult> rotatePages({
    required String pdfPath,
    required List<int> pageNumbers,
    required int rotation,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    final validRotation = _normalizeRotation(rotation);
    final originalBytes = await _readPdfBytes(pdfPath);
    final document = PdfDocument(inputBytes: originalBytes);

    try {
      final pageCount = document.pages.count;
      int processedPages = 0;

      for (int pageNum in pageNumbers) {
        if (pageNum < 1 || pageNum > pageCount) {
          document.dispose();
          throw ArgumentError('Page $pageNum is out of range (1-$pageCount)');
        }

        final page = document.pages[pageNum - 1];
        page.rotation = _getPdfRotation(validRotation);

        processedPages++;
        if (onProgress != null) {
          onProgress(processedPages / pageNumbers.length);
        }
      }

      final outputBytes = await document.save();
      final finalOutputPath = outputPath ?? await _getDefaultOutputPath('rotated');
      await File(finalOutputPath).writeAsBytes(outputBytes);

      document.dispose();

      return RotationResult(
        outputPath: finalOutputPath,
        rotatedPages: pageNumbers.length,
        rotation: validRotation,
      );
    } catch (e) {
      document.dispose();
      throw Exception('Error rotating pages: $e');
    }
  }

  /// Rotate pages by range
  /// 
  /// [startPage] - First page to rotate (1-indexed)
  /// [endPage] - Last page to rotate (1-indexed)
  /// [rotation] - Rotation angle
  static Future<RotationResult> rotatePageRange({
    required String pdfPath,
    required int startPage,
    required int endPage,
    required int rotation,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    final validRotation = _normalizeRotation(rotation);
    final originalBytes = await _readPdfBytes(pdfPath);
    final document = PdfDocument(inputBytes: originalBytes);

    try {
      final pageCount = document.pages.count;

      if (startPage < 1 || startPage > pageCount) {
        document.dispose();
        throw ArgumentError('Start page $startPage is out of range (1-$pageCount)');
      }

      if (endPage < 1 || endPage > pageCount) {
        document.dispose();
        throw ArgumentError('End page $endPage is out of range (1-$pageCount)');
      }

      if (startPage > endPage) {
        document.dispose();
        throw ArgumentError('Start page cannot be greater than end page');
      }

      final totalPages = endPage - startPage + 1;
      int processedPages = 0;

      for (int i = startPage - 1; i < endPage; i++) {
        final page = document.pages[i];
        page.rotation = _getPdfRotation(validRotation);

        processedPages++;
        if (onProgress != null) {
          onProgress(processedPages / totalPages);
        }
      }

      final outputBytes = await document.save();
      final finalOutputPath = outputPath ?? await _getDefaultOutputPath('rotated');
      await File(finalOutputPath).writeAsBytes(outputBytes);

      document.dispose();

      return RotationResult(
        outputPath: finalOutputPath,
        rotatedPages: totalPages,
        rotation: validRotation,
      );
    } catch (e) {
      document.dispose();
      throw Exception('Error rotating page range: $e');
    }
  }

  /// Rotate odd pages only
  static Future<RotationResult> rotateOddPages({
    required String pdfPath,
    required int rotation,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    final validRotation = _normalizeRotation(rotation);
    final originalBytes = await _readPdfBytes(pdfPath);
    final document = PdfDocument(inputBytes: originalBytes);

    try {
      final pageCount = document.pages.count;
      int rotatedCount = 0;

      for (int i = 0; i < pageCount; i++) {
        if ((i + 1) % 2 == 1) {  // Odd pages (1, 3, 5, ...)
          final page = document.pages[i];
          page.rotation = _getPdfRotation(validRotation);
          rotatedCount++;
        }

        if (onProgress != null) {
          onProgress((i + 1) / pageCount);
        }
      }

      final outputBytes = await document.save();
      final finalOutputPath = outputPath ?? await _getDefaultOutputPath('rotated');
      await File(finalOutputPath).writeAsBytes(outputBytes);

      document.dispose();

      return RotationResult(
        outputPath: finalOutputPath,
        rotatedPages: rotatedCount,
        rotation: validRotation,
      );
    } catch (e) {
      document.dispose();
      throw Exception('Error rotating odd pages: $e');
    }
  }

  /// Rotate even pages only
  static Future<RotationResult> rotateEvenPages({
    required String pdfPath,
    required int rotation,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    final validRotation = _normalizeRotation(rotation);
    final originalBytes = await _readPdfBytes(pdfPath);
    final document = PdfDocument(inputBytes: originalBytes);

    try {
      final pageCount = document.pages.count;
      int rotatedCount = 0;

      for (int i = 0; i < pageCount; i++) {
        if ((i + 1) % 2 == 0) {  // Even pages (2, 4, 6, ...)
          final page = document.pages[i];
          page.rotation = _getPdfRotation(validRotation);
          rotatedCount++;
        }

        if (onProgress != null) {
          onProgress((i + 1) / pageCount);
        }
      }

      final outputBytes = await document.save();
      final finalOutputPath = outputPath ?? await _getDefaultOutputPath('rotated');
      await File(finalOutputPath).writeAsBytes(outputBytes);

      document.dispose();

      return RotationResult(
        outputPath: finalOutputPath,
        rotatedPages: rotatedCount,
        rotation: validRotation,
      );
    } catch (e) {
      document.dispose();
      throw Exception('Error rotating even pages: $e');
    }
  }

  /// Get current rotation of all pages
  static Future<List<int>> getPageRotations(String pdfPath) async {
    final originalBytes = await _readPdfBytes(pdfPath);
    final document = PdfDocument(inputBytes: originalBytes);
    
    final rotations = <int>[];
    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      rotations.add(_getRotationDegrees(page.rotation));
    }
    
    document.dispose();
    return rotations;
  }

  /// Quick rotation presets
  
  /// Rotate 90 degrees clockwise
  static Future<RotationResult> rotate90Clockwise({
    required String pdfPath,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    return await rotateAllPages(
      pdfPath: pdfPath,
      rotation: 90,
      outputPath: outputPath,
      onProgress: onProgress,
    );
  }

  /// Rotate 90 degrees counter-clockwise
  static Future<RotationResult> rotate90CounterClockwise({
    required String pdfPath,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    return await rotateAllPages(
      pdfPath: pdfPath,
      rotation: 270,
      outputPath: outputPath,
      onProgress: onProgress,
    );
  }

  /// Rotate 180 degrees (upside down)
  static Future<RotationResult> rotate180({
    required String pdfPath,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    return await rotateAllPages(
      pdfPath: pdfPath,
      rotation: 180,
      outputPath: outputPath,
      onProgress: onProgress,
    );
  }

  // Helper methods
  static int _normalizeRotation(int rotation) {
    // Normalize rotation to 0, 90, 180, or 270
    int normalized = rotation % 360;
    if (normalized < 0) normalized += 360;
    
    if (normalized != 0 && normalized != 90 && normalized != 180 && normalized != 270) {
      throw ArgumentError('Rotation must be 0, 90, 180, or 270 degrees (or equivalent negative values)');
    }
    
    return normalized;
  }

  static PdfPageRotateAngle _getPdfRotation(int degrees) {
    switch (degrees) {
      case 0:
        return PdfPageRotateAngle.rotateAngle0;
      case 90:
        return PdfPageRotateAngle.rotateAngle90;
      case 180:
        return PdfPageRotateAngle.rotateAngle180;
      case 270:
        return PdfPageRotateAngle.rotateAngle270;
      default:
        return PdfPageRotateAngle.rotateAngle0;
    }
  }

  static int _getRotationDegrees(PdfPageRotateAngle angle) {
    switch (angle) {
      case PdfPageRotateAngle.rotateAngle0:
        return 0;
      case PdfPageRotateAngle.rotateAngle90:
        return 90;
      case PdfPageRotateAngle.rotateAngle180:
        return 180;
      case PdfPageRotateAngle.rotateAngle270:
        return 270;
    }
  }

  static Future<Uint8List> _readPdfBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('PDF file not found', path);
    }
    return await file.readAsBytes();
  }

  static Future<String> _getDefaultOutputPath(String prefix) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/${prefix}_$timestamp.pdf';
  }
}

/// Rotation result
class RotationResult {
  final String outputPath;
  final int rotatedPages;
  final int rotation;

  RotationResult({
    required this.outputPath,
    required this.rotatedPages,
    required this.rotation,
  });

  String get rotationDescription {
    switch (rotation) {
      case 90:
        return '90° clockwise';
      case 180:
        return '180° (upside down)';
      case 270:
        return '90° counter-clockwise';
      default:
        return '$rotation°';
    }
  }

  @override
  String toString() {
    return 'Rotated $rotatedPages page(s) by $rotationDescription\nSaved to: $outputPath';
  }
}

/// Flutter Widget for PDF Rotation
class PdfRotatorWidget extends StatefulWidget {
  const PdfRotatorWidget({super.key});

  @override
  _PdfRotatorWidgetState createState() => _PdfRotatorWidgetState();
}

class _PdfRotatorWidgetState extends State<PdfRotatorWidget> {
  double _progress = 0.0;
  String _status = 'Ready to rotate';
  RotationResult? _result;
  int _selectedRotation = 90;
  String _rotationType = 'all';
  final List<int> _specificPages = [];
  int _startPage = 1;
  int _endPage = 1;

  Future<void> _rotatePdf(String pdfPath) async {
    setState(() {
      _status = 'Rotating...';
      _progress = 0.0;
      _result = null;
    });

    try {
      RotationResult result;

      switch (_rotationType) {
        case 'all':
          result = await PdfRotator.rotateAllPages(
            pdfPath: pdfPath,
            rotation: _selectedRotation,
            onProgress: (p) => setState(() => _progress = p),
          );
          break;
        case 'specific':
          result = await PdfRotator.rotatePages(
            pdfPath: pdfPath,
            pageNumbers: _specificPages,
            rotation: _selectedRotation,
            onProgress: (p) => setState(() => _progress = p),
          );
          break;
        case 'range':
          result = await PdfRotator.rotatePageRange(
            pdfPath: pdfPath,
            startPage: _startPage,
            endPage: _endPage,
            rotation: _selectedRotation,
            onProgress: (p) => setState(() => _progress = p),
          );
          break;
        case 'odd':
          result = await PdfRotator.rotateOddPages(
            pdfPath: pdfPath,
            rotation: _selectedRotation,
            onProgress: (p) => setState(() => _progress = p),
          );
          break;
        case 'even':
          result = await PdfRotator.rotateEvenPages(
            pdfPath: pdfPath,
            rotation: _selectedRotation,
            onProgress: (p) => setState(() => _progress = p),
          );
          break;
        default:
          result = await PdfRotator.rotateAllPages(
            pdfPath: pdfPath,
            rotation: _selectedRotation,
            onProgress: (p) => setState(() => _progress = p),
          );
      }

      setState(() {
        _status = 'Complete!';
        _result = result;
        _progress = 1.0;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _progress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Rotator'),
        backgroundColor: Colors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rotation Angle Selection
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rotation Angle', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRotationButton(90, '90°\nClockwise', Icons.rotate_right),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildRotationButton(180, '180°\nFlip', Icons.flip),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildRotationButton(270, '90°\nCounter', Icons.rotate_left),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Page Selection
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pages to Rotate', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildPageOption('all', 'All Pages', Icons.select_all),
                    _buildPageOption('odd', 'Odd Pages (1, 3, 5...)', Icons.filter_1),
                    _buildPageOption('even', 'Even Pages (2, 4, 6...)', Icons.filter_2),
                    _buildPageOption('range', 'Page Range', Icons.linear_scale),
                    if (_rotationType == 'range') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'From',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => _startPage = int.tryParse(v) ?? 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'To',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => _endPage = int.tryParse(v) ?? 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Progress
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_status, 
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ),

            // Result
            if (_result != null) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.purple[50],
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.purple[700], size: 28),
                          const SizedBox(width: 8),
                          Text('Rotation Complete!', 
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[900],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildResultRow(Icons.description, 'Pages Rotated', 
                        '${_result!.rotatedPages}'),
                      _buildResultRow(Icons.rotate_right, 'Rotation', 
                        _result!.rotationDescription),
                      const SizedBox(height: 8),
                      Text('Saved to:\n${_result!.outputPath}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Add file picker integration
                // _rotatePdf(selectedFilePath);
              },
              icon: const Icon(Icons.rotate_right, size: 24),
              label: const Text('Select PDF to Rotate', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(18),
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRotationButton(int rotation, String label, IconData icon) {
    final isSelected = _selectedRotation == rotation;
    return InkWell(
      onTap: () => setState(() => _selectedRotation = rotation),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple[100] : Colors.grey[100],
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.grey[400]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, 
              color: isSelected ? Colors.purple : Colors.grey[700],
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(label, 
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.purple[900] : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageOption(String value, String label, IconData icon) {
    final isSelected = _rotationType == value;
    return InkWell(
      onTap: () => setState(() => _rotationType = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple[50] : Colors.grey[50],
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, 
              color: isSelected ? Colors.purple : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, 
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.purple[900] : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.purple, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Text(value, 
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/*
=== DEPENDENCIES ===

dependencies:
  syncfusion_flutter_pdf: ^28.1.33
  path_provider: ^2.1.0
  file_picker: ^8.0.0  # Optional

=== USAGE EXAMPLES ===

// 1. Rotate all pages 90° clockwise
RotationResult result = await PdfRotator.rotate90Clockwise(
  pdfPath: '/path/to/file.pdf',
);

// 2. Rotate all pages 90° counter-clockwise
await PdfRotator.rotate90CounterClockwise(pdfPath: path);

// 3. Rotate all pages 180° (flip)
await PdfRotator.rotate180(pdfPath: path);

// 4. Rotate specific pages
await PdfRotator.rotatePages(
  pdfPath: path,
  pageNumbers: [1, 3, 5],  // Rotate pages 1, 3, and 5
  rotation: 90,
);

// 5. Rotate page range
await PdfRotator.rotatePageRange(
  pdfPath: path,
  startPage: 2,
  endPage: 10,
  rotation: 180,
);

// 6. Rotate odd pages only
await PdfRotator.rotateOddPages(
  pdfPath: path,
  rotation: 90,
);

// 7. Rotate even pages only
await PdfRotator.rotateEvenPages(
  pdfPath: path,
  rotation: 270,
);

// 8. Get current rotations
List<int> rotations = await PdfRotator.getPageRotations(path);
print(rotations);  // [0, 90, 0, 180, ...]

// 9. Custom rotation with progress
await PdfRotator.rotateAllPages(
  pdfPath: path,
  rotation: 90,
  onProgress: (progress) {
    print('Progress: ${(progress * 100).toInt()}%');
  },
);
*/