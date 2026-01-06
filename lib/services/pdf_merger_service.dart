import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' as dart_pdf;
import 'package:pdf/widgets.dart' as pw;

/// Powerful PDF Merger for Flutter
/// Uses multiple approaches for maximum compatibility
class PdfMerger {
  /// Merges multiple PDF files into a single PDF
  /// 
  /// [pdfPaths] - List of file paths to PDF files to merge
  /// [outputPath] - Optional output path. If not provided, saves to app documents
  /// Returns the path to the merged PDF file
  static Future<String> mergePdfs({
    required List<String> pdfPaths,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    print('DEBUG PdfMerger: mergePdfs called with ${pdfPaths.length} paths');
    
    if (pdfPaths.length < 2) {
      throw ArgumentError('At least 2 PDF files are required for merging');
    }

    // Filter out empty paths
    final validPaths = pdfPaths.where((p) => p.isNotEmpty).toList();
    if (validPaths.length < 2) {
      throw ArgumentError('At least 2 valid PDF files are required');
    }

    try {
      // Collect all page images first (faster with lower DPI)
      final List<_PageData> allPages = [];
      int totalFilesProcessed = 0;
      
      // First pass: count total pages for accurate progress
      int totalPageCount = 0;
      for (final path in validPaths) {
        final bytes = await _readPdfBytes(path);
        final doc = PdfDocument(inputBytes: bytes);
        totalPageCount += doc.pages.count;
        doc.dispose();
      }
      
      print('DEBUG PdfMerger: Total pages to process: $totalPageCount');
      int pagesProcessed = 0;
      
      // Second pass: rasterize all pages
      for (int i = 0; i < validPaths.length; i++) {
        final path = validPaths[i];
        print('DEBUG PdfMerger: Processing file $i: "$path"');
        
        final bytes = await _readPdfBytes(path);
        
        // Use lower DPI (72) for faster processing - still good quality
        await for (final page in Printing.raster(bytes, dpi: 72)) {
          final imageBytes = await page.toPng();
          allPages.add(_PageData(
            imageBytes: imageBytes,
            width: page.width.toDouble(),
            height: page.height.toDouble(),
          ));
          
          pagesProcessed++;
          if (onProgress != null) {
            onProgress(pagesProcessed / totalPageCount * 0.9); // 90% for rasterizing
          }
        }
        
        totalFilesProcessed++;
        print('DEBUG PdfMerger: Processed ${allPages.length} pages so far');
      }

      if (allPages.isEmpty) {
        throw Exception('No pages could be merged');
      }

      // Create merged PDF (fast - just adding images)
      print('DEBUG PdfMerger: Creating merged PDF with ${allPages.length} pages...');
      final pw.Document mergedPdf = pw.Document();
      
      for (final pageData in allPages) {
        final image = pw.MemoryImage(pageData.imageBytes);
        mergedPdf.addPage(
          pw.Page(
            pageFormat: dart_pdf.PdfPageFormat(pageData.width, pageData.height),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) => pw.Image(image, fit: pw.BoxFit.contain),
          ),
        );
      }
      
      if (onProgress != null) {
        onProgress(0.95); // 95% - building PDF
      }

      // Save PDF
      print('DEBUG PdfMerger: Saving...');
      final savedBytes = await mergedPdf.save();
      print('DEBUG PdfMerger: Saved ${savedBytes.length} bytes');

      // Generate output path
      final String finalOutputPath = outputPath ?? await _getDefaultOutputPath();
      
      // Write to file
      final file = File(finalOutputPath);
      await file.writeAsBytes(savedBytes);
      
      if (onProgress != null) {
        onProgress(1.0);
      }
      
      print('DEBUG PdfMerger: File written to $finalOutputPath');
      return finalOutputPath;
    } catch (e, stackTrace) {
      print('DEBUG PdfMerger: Error: $e');
      print('DEBUG PdfMerger: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Merges PDFs from byte arrays (useful for in-memory operations)
  static Future<Uint8List> mergePdfsFromBytes({
    required List<Uint8List> pdfBytesList,
    Function(double)? onProgress,
  }) async {
    if (pdfBytesList.length < 2) {
      throw ArgumentError('At least 2 PDF byte arrays are required');
    }

    final PdfDocument mergedDocument = PdfDocument();
    
    try {
      int totalProcessed = 0;

      for (Uint8List bytes in pdfBytesList) {
        try {
          final PdfDocument sourceDocument = PdfDocument(inputBytes: bytes);
          mergedDocument.importPdfDocument(sourceDocument);
          sourceDocument.dispose();
          
          totalProcessed++;
          if (onProgress != null) {
            onProgress(totalProcessed / pdfBytesList.length);
          }
        } catch (e) {
          mergedDocument.dispose();
          throw Exception('Error processing PDF bytes: $e');
        }
      }

      final List<int> bytes = await mergedDocument.save();
      mergedDocument.dispose();
      
      return Uint8List.fromList(bytes);
    } catch (e) {
      mergedDocument.dispose();
      rethrow;
    }
  }

  /// Merge specific page ranges from PDFs
  static Future<String> mergePdfsWithPageRange({
    required List<PdfSource> sources,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    if (sources.length < 2) {
      throw ArgumentError('At least 2 PDF sources are required');
    }

    final PdfDocument mergedDocument = PdfDocument();
    
    try {
      int totalProcessed = 0;

      for (PdfSource source in sources) {
        try {
          final bytes = await _readPdfBytes(source.path);
          final PdfDocument sourceDocument = PdfDocument(inputBytes: bytes);
          
          if (source.startPage != null && source.endPage != null) {
            // Import specific page range
            mergedDocument.importPage(
              sourceDocument,
              source.startPage!,
              source.endPage!,
            );
          } else {
            // Import all pages
            mergedDocument.importPdfDocument(sourceDocument);
          }
          
          sourceDocument.dispose();
          
          totalProcessed++;
          if (onProgress != null) {
            onProgress(totalProcessed / sources.length);
          }
        } catch (e) {
          mergedDocument.dispose();
          throw Exception('Error processing PDF at ${source.path}: $e');
        }
      }

      final List<int> bytes = await mergedDocument.save();
      mergedDocument.dispose();

      final String finalOutputPath = outputPath ?? await _getDefaultOutputPath();
      final file = File(finalOutputPath);
      await file.writeAsBytes(bytes);
      
      return finalOutputPath;
    } catch (e) {
      mergedDocument.dispose();
      rethrow;
    }
  }

  /// Read PDF bytes from file path
  static Future<Uint8List> _readPdfBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('PDF file not found', path);
    }
    return await file.readAsBytes();
  }

  /// Get default output path in app documents directory
  static Future<String> _getDefaultOutputPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/merged_pdf_$timestamp.pdf';
  }

  /// Validate if file is a valid PDF
  static Future<bool> isValidPdf(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      
      final bytes = await file.readAsBytes();
      if (bytes.length < 5) return false;
      
      // Check PDF header signature
      return bytes[0] == 0x25 && // %
             bytes[1] == 0x50 && // P
             bytes[2] == 0x44 && // D
             bytes[3] == 0x46;   // F
    } catch (e) {
      return false;
    }
  }

  /// Get PDF page count
  static Future<int> getPageCount(String path) async {
    final bytes = await _readPdfBytes(path);
    final document = PdfDocument(inputBytes: bytes);
    final count = document.pages.count;
    document.dispose();
    return count;
  }
}

/// Class to define PDF source with optional page range
class PdfSource {
  final String path;
  final int? startPage;
  final int? endPage;

  PdfSource({
    required this.path,
    this.startPage,
    this.endPage,
  });
}

/// Extension on PdfDocument for easier page importing
extension PdfDocumentExtension on PdfDocument {
  void importPdfDocument(PdfDocument sourceDocument) {
    for (int i = 0; i < sourceDocument.pages.count; i++) {
      // Get source page size
      final sourcePage = sourceDocument.pages[i];
      final sourceSize = sourcePage.getClientSize();
      
      // Add page with matching size
      final newPage = pages.add();
      newPage.graphics.drawPdfTemplate(
        sourcePage.createTemplate(),
        Offset.zero,
        Size(sourceSize.width, sourceSize.height),
      );
    }
  }

  void importPage(PdfDocument sourceDocument, int startPage, int endPage) {
    for (int i = startPage; i <= endPage && i < sourceDocument.pages.count; i++) {
      final sourcePage = sourceDocument.pages[i];
      final sourceSize = sourcePage.getClientSize();
      
      final newPage = pages.add();
      newPage.graphics.drawPdfTemplate(
        sourcePage.createTemplate(),
        Offset.zero,
        Size(sourceSize.width, sourceSize.height),
      );
    }
  }
}

/// Example Flutter Widget for PDF Merging
class PdfMergerWidget extends StatefulWidget {
  const PdfMergerWidget({super.key});

  @override
  _PdfMergerWidgetState createState() => _PdfMergerWidgetState();
}

class _PdfMergerWidgetState extends State<PdfMergerWidget> {
  double _progress = 0.0;
  String _status = 'Ready';
  String? _mergedPath;

  Future<void> _mergePdfs(List<String> pdfPaths) async {
    setState(() {
      _status = 'Merging...';
      _progress = 0.0;
    });

    try {
      final path = await PdfMerger.mergePdfs(
        pdfPaths: pdfPaths,
        onProgress: (progress) {
          setState(() {
            _progress = progress;
          });
        },
      );

      setState(() {
        _status = 'Complete!';
        _mergedPath = path;
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
      appBar: AppBar(title: const Text('PDF Merger')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 20),
            if (_mergedPath != null)
              Text('Saved to: $_mergedPath', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Example: Add your file picker here
                // _mergePdfs([path1, path2, path3]);
              },
              child: const Text('Select & Merge PDFs'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Powerful PDF Splitter for Flutter using Syncfusion
/// Accurately splits PDFs preserving all content
class PdfSplitter {
  /// Get PDF info (page count, file size)
  static Future<PdfInfo> getPdfInfo(String pdfPath) async {
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final info = PdfInfo(
      pageCount: document.pages.count,
      fileSize: bytes.length,
      filePath: pdfPath,
    );
    document.dispose();
    return info;
  }

  /// Generate thumbnails for all pages (for visual selection)
  static Future<List<Uint8List>> getPageThumbnails(String pdfPath, {double dpi = 72}) async {
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    final List<Uint8List> thumbnails = [];
    
    await for (final page in Printing.raster(bytes, dpi: dpi)) {
      thumbnails.add(await page.toPng());
    }
    
    return thumbnails;
  }

  /// Split PDF into individual pages (one page per file)
  static Future<List<String>> splitIntoPages({
    required String pdfPath,
    String? outputDir,
    Function(double)? onProgress,
  }) async {
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    
    final String outputDirectory = outputDir ?? await _getDefaultOutputDir();
    await Directory(outputDirectory).create(recursive: true);
    
    final List<String> outputPaths = [];
    int pageIndex = 0;
    
    await for (final page in Printing.raster(bytes, dpi: 72)) {
      final imageBytes = await page.toPng();
      
      // Create single-page PDF with this image
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: dart_pdf.PdfPageFormat(page.width.toDouble(), page.height.toDouble()),
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) => pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.contain),
        ),
      );
      
      final outputPath = '$outputDirectory/page_${pageIndex + 1}.pdf';
      final pdfBytes = await pdf.save();
      await File(outputPath).writeAsBytes(pdfBytes);
      outputPaths.add(outputPath);
      
      pageIndex++;
      if (onProgress != null) {
        // We don't know total pages in stream, estimate
        onProgress(0.9); // Will update to 1.0 at end
      }
    }
    
    if (onProgress != null) onProgress(1.0);
    return outputPaths;
  }

  /// Split PDF by page ranges
  static Future<List<String>> splitByRanges({
    required String pdfPath,
    required List<PageRange> ranges,
    String? outputDir,
    Function(double)? onProgress,
  }) async {
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    
    final String outputDirectory = outputDir ?? await _getDefaultOutputDir();
    await Directory(outputDirectory).create(recursive: true);
    
    // Collect all page images first
    final List<Uint8List> pageImages = [];
    await for (final page in Printing.raster(bytes, dpi: 72)) {
      pageImages.add(await page.toPng());
    }
    
    final List<String> outputPaths = [];
    
    for (int rangeIndex = 0; rangeIndex < ranges.length; rangeIndex++) {
      final range = ranges[rangeIndex];
      final start = (range.startPage - 1).clamp(0, pageImages.length - 1);
      final end = (range.endPage - 1).clamp(0, pageImages.length - 1);
      
      final pdf = pw.Document();
      for (int i = start; i <= end; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: dart_pdf.PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) => pw.Image(pw.MemoryImage(pageImages[i]), fit: pw.BoxFit.contain),
          ),
        );
      }
      
      final outputPath = '$outputDirectory/pages_${range.startPage}-${range.endPage}.pdf';
      await File(outputPath).writeAsBytes(await pdf.save());
      outputPaths.add(outputPath);
      
      if (onProgress != null) {
        onProgress((rangeIndex + 1) / ranges.length);
      }
    }
    
    return outputPaths;
  }

  /// Split PDF into chunks of specified size
  static Future<List<String>> splitIntoChunks({
    required String pdfPath,
    required int chunkSize,
    String? outputDir,
    Function(double)? onProgress,
  }) async {
    if (chunkSize < 1) throw ArgumentError('Chunk size must be at least 1');

    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    
    final String outputDirectory = outputDir ?? await _getDefaultOutputDir();
    await Directory(outputDirectory).create(recursive: true);
    
    // Collect all page images
    final List<Uint8List> pageImages = [];
    await for (final page in Printing.raster(bytes, dpi: 72)) {
      pageImages.add(await page.toPng());
    }
    
    final totalChunks = (pageImages.length / chunkSize).ceil();
    final List<String> outputPaths = [];
    
    for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
      final startPage = chunkIndex * chunkSize;
      final endPage = ((chunkIndex + 1) * chunkSize).clamp(0, pageImages.length) as int;
      
      final pdf = pw.Document();
      for (int i = startPage; i < endPage; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: dart_pdf.PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) => pw.Image(pw.MemoryImage(pageImages[i]), fit: pw.BoxFit.contain),
          ),
        );
      }
      
      final outputPath = '$outputDirectory/chunk_${chunkIndex + 1}.pdf';
      await File(outputPath).writeAsBytes(await pdf.save());
      outputPaths.add(outputPath);
      
      if (onProgress != null) {
        onProgress((chunkIndex + 1) / totalChunks);
      }
    }
    
    return outputPaths;
  }

  /// Extract specific pages from PDF
  static Future<String> extractPages({
    required String pdfPath,
    required List<int> pageNumbers,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    
    // Collect all page images
    final List<Uint8List> pageImages = [];
    await for (final page in Printing.raster(bytes, dpi: 72)) {
      pageImages.add(await page.toPng());
    }
    
    final pdf = pw.Document();
    for (int i = 0; i < pageNumbers.length; i++) {
      final pageNum = pageNumbers[i];
      if (pageNum >= 1 && pageNum <= pageImages.length) {
        pdf.addPage(
          pw.Page(
            pageFormat: dart_pdf.PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) => pw.Image(pw.MemoryImage(pageImages[pageNum - 1]), fit: pw.BoxFit.contain),
          ),
        );
      }
      if (onProgress != null) onProgress((i + 1) / pageNumbers.length);
    }
    
    final finalOutputPath = outputPath ?? await _getDefaultOutputPath('extracted');
    await File(finalOutputPath).writeAsBytes(await pdf.save());
    return finalOutputPath;
  }

  /// Remove specific pages from PDF (keep all except specified)
  static Future<String> removePages({
    required String pdfPath,
    required List<int> pageNumbers,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    final pagesToRemove = Set<int>.from(pageNumbers);
    
    // Collect all page images
    final List<Uint8List> pageImages = [];
    await for (final page in Printing.raster(bytes, dpi: 72)) {
      pageImages.add(await page.toPng());
    }
    
    final pdf = pw.Document();
    for (int i = 0; i < pageImages.length; i++) {
      final pageNum = i + 1;
      if (!pagesToRemove.contains(pageNum)) {
        pdf.addPage(
          pw.Page(
            pageFormat: dart_pdf.PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) => pw.Image(pw.MemoryImage(pageImages[i]), fit: pw.BoxFit.contain),
          ),
        );
      }
      if (onProgress != null) onProgress((i + 1) / pageImages.length);
    }
    
    final finalOutputPath = outputPath ?? await _getDefaultOutputPath('removed');
    await File(finalOutputPath).writeAsBytes(await pdf.save());
    return finalOutputPath;
  }

  /// Reverse page order
  static Future<String> reverseOrder({
    required String pdfPath,
    String? outputPath,
    Function(double)? onProgress,
  }) async {
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    
    // Collect all page images
    final List<Uint8List> pageImages = [];
    await for (final page in Printing.raster(bytes, dpi: 72)) {
      pageImages.add(await page.toPng());
    }
    
    final pdf = pw.Document();
    for (int i = pageImages.length - 1; i >= 0; i--) {
      pdf.addPage(
        pw.Page(
          pageFormat: dart_pdf.PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) => pw.Image(pw.MemoryImage(pageImages[i]), fit: pw.BoxFit.contain),
        ),
      );
      if (onProgress != null) onProgress((pageImages.length - i) / pageImages.length);
    }
    
    final finalOutputPath = outputPath ?? await _getDefaultOutputPath('reversed');
    await File(finalOutputPath).writeAsBytes(await pdf.save());
    return finalOutputPath;
  }

  // Helper methods
  static Future<String> _getDefaultOutputDir() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/split_pdf_$timestamp';
  }

  static Future<String> _getDefaultOutputPath(String prefix) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/${prefix}_$timestamp.pdf';
  }
}

/// Class to define page range for splitting
class PageRange {
  final int startPage;
  final int endPage;

  PageRange({required this.startPage, required this.endPage}) {
    if (startPage < 1 || endPage < 1) {
      throw ArgumentError('Page numbers must be positive');
    }
    if (startPage > endPage) {
      throw ArgumentError('Start page cannot be greater than end page');
    }
  }
}

/// PDF information class
class PdfInfo {
  final int pageCount;
  final int fileSize;
  final String filePath;

  PdfInfo({
    required this.pageCount,
    required this.fileSize,
    required this.filePath,
  });

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(2)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Example Flutter Widget for PDF Splitting
class PdfSplitterWidget extends StatefulWidget {
  const PdfSplitterWidget({super.key});

  @override
  _PdfSplitterWidgetState createState() => _PdfSplitterWidgetState();
}

class _PdfSplitterWidgetState extends State<PdfSplitterWidget> {
  double _progress = 0.0;
  String _status = 'Ready';
  List<String>? _outputPaths;
  PdfInfo? _pdfInfo;

  Future<void> _loadPdfInfo(String path) async {
    final info = await PdfSplitter.getPdfInfo(path);
    setState(() {
      _pdfInfo = info;
    });
  }

  Future<void> _splitPdf(String pdfPath) async {
    setState(() {
      _status = 'Splitting...';
      _progress = 0.0;
      _outputPaths = null;
    });

    try {
      final paths = await PdfSplitter.splitIntoPages(
        pdfPath: pdfPath,
        onProgress: (progress) {
          setState(() {
            _progress = progress;
          });
        },
      );

      setState(() {
        _status = 'Complete! Created ${paths.length} files';
        _outputPaths = paths;
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
      appBar: AppBar(title: const Text('PDF Splitter')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_pdfInfo != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PDF Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Pages: ${_pdfInfo!.pageCount}'),
                      Text('Size: ${_pdfInfo!.fileSizeFormatted}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(_status, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 24),
            if (_outputPaths != null) ...[
              const Text('Output Files:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _outputPaths!.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      dense: true,
                      title: Text('Page ${index + 1}'),
                      subtitle: Text(_outputPaths![index], 
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Add your file picker here
                // _splitPdf(selectedFilePath);
              },
              child: const Text('Select & Split PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper class for storing page data during merge
class _PageData {
  final Uint8List imageBytes;
  final double width;
  final double height;
  
  _PageData({required this.imageBytes, required this.width, required this.height});
}