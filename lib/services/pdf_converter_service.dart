import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:archive/archive_io.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:ilovepdf_flutter/services/pdf_to_word_converter.dart';
import 'package:ilovepdf_flutter/services/pdf_to_word_ocr.dart';
import 'package:ilovepdf_flutter/services/pdf_to_excel_ocr.dart';
import 'package:ilovepdf_flutter/services/pdf_to_excel_smart_ocr.dart';
import 'package:ilovepdf_flutter/services/proper_docx_converter.dart';
import 'package:ilovepdf_flutter/services/proper_pptx_converter.dart';
import 'package:ilovepdf_flutter/services/pdf_to_html_converter.dart';
import 'package:ilovepdf_flutter/services/smart_excel_converter.dart';
import 'package:ilovepdf_flutter/services/pdf_to_image_v2.dart';

typedef ProgressCallback = void Function(double progress, String message);

class PDFConverterService {
  Future<String> convertToImage(
    File pdfFile, {
    required ProgressCallback onProgress,
    int dpi = 200, // Higher DPI for better quality
  }) async {
    // Use V2 converter with pdfx for better image-based PDF handling
    return await PDFToImageConverterV2.convert(
      pdfFile: pdfFile,
      onProgress: onProgress,
      dpi: dpi,
      format: 'png',
      createZip: true,
    );
  }
  
  Future<String> convertToWord(
    File pdfFile, {
    required ProgressCallback onProgress,
  }) async {
    // Use proper DOCX converter for real Word files
    return await ProperDocxConverter.convert(
      pdfFile: pdfFile,
      onProgress: onProgress,
    );
  }

  Future<String> convertToExcel(
    File pdfFile, {
    required ProgressCallback onProgress,
    bool useSmartDetection = true,
  }) async {
    if (useSmartDetection) {
      // Use smart table detection
      return await SmartExcelConverter.convert(
        pdfFile: pdfFile,
        onProgress: onProgress,
      );
    } else {
      // Fallback to basic extraction
      return await PDFToExcelConverter.convert(
        pdfFile: pdfFile,
        onProgress: onProgress,
        detectTables: true,
      );
    }
  }

  Future<String> convertToPowerPoint(
    File pdfFile, {
    required ProgressCallback onProgress,
  }) async {
    // Use proper PPTX converter for real PowerPoint files
    return await ProperPptxConverter.convert(
      pdfFile: pdfFile,
      onProgress: onProgress,
    );
  }

  Future<String> convertToHtml(
    File pdfFile, {
    required ProgressCallback onProgress,
  }) async {
    return await PDFToHtmlConverter.convert(
      pdfFile: pdfFile,
      onProgress: onProgress,
    );
  }
}

/// Converts PDF to images using printing library (cross-platform)
class PDFToImageConverter {
  static Future<String> convert({
    required File pdfFile,
    required Function(double progress, String message) onProgress,
    int dpi = 150,
    String format = 'png',
    bool createZip = true,
  }) async {
    try {
      // Step 1: Load PDF
      onProgress(0.05, 'Opening PDF document...');
      final bytes = await pdfFile.readAsBytes();
      
      // Get original PDF filename for output naming
      final pdfName = pdfFile.path.split('/').last.split('\\').last.replaceAll('.pdf', '').replaceAll('.PDF', '');
      
      // Step 2: Get page count using Syncfusion
      final sf_pdf.PdfDocument document = sf_pdf.PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      document.dispose();
      
      if (pageCount == 0) {
        throw Exception('PDF has no pages');
      }
      
      // Step 3: Setup output with unique name based on PDF filename
      onProgress(0.10, 'Setting up output directory...');
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFolder = Directory('${outputDir.path}/${pdfName}_images_$timestamp');
      
      if (!await outputFolder.exists()) {
        await outputFolder.create(recursive: true);
      }
      
      // Step 4: Convert pages using printing library
      final List<String> imagePaths = [];
      int pageNum = 0;
      
      // Render pages using printing library
      await for (var page in Printing.raster(
        bytes,
        pages: List.generate(pageCount, (index) => index),
        dpi: dpi.toDouble(),
      )) {
        pageNum++;
        final progressPercent = 0.10 + (0.70 * ((pageNum - 1) / pageCount));
        onProgress(
          progressPercent,
          'Converting page $pageNum of $pageCount...',
        );
        
        // Get image from raster
        final imageBytes = await page.toPng();
        
        // Save based on format
        String extension;
        Uint8List finalBytes;
        
        if (format.toLowerCase() == 'jpeg' || format.toLowerCase() == 'jpg') {
          // Convert to JPEG
          final image = img.decodePng(imageBytes);
          if (image == null) throw Exception('Failed to decode image');
          finalBytes = Uint8List.fromList(img.encodeJpg(image, quality: 85));
          extension = 'jpg';
        } else {
          // Keep as PNG
          finalBytes = imageBytes;
          extension = 'png';
        }
        
        // Save image
        final outputPath = '${outputFolder.path}/page_$pageNum.$extension';
        final outputFile = File(outputPath);
        await outputFile.writeAsBytes(finalBytes);
        imagePaths.add(outputPath);
        
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      // Step 5: Create ZIP if requested
      onProgress(0.85, 'Finalizing conversion...');
      
      String finalOutputPath;
      
      if (createZip && imagePaths.isNotEmpty) {
        onProgress(0.90, 'Creating ZIP archive...');
        final zipPath = '${outputDir.path}/${pdfName}_images_$timestamp.zip';
        final encoder = ZipFileEncoder();
        encoder.create(zipPath);
        
        for (final imagePath in imagePaths) {
          encoder.addFile(File(imagePath));
        }
        
        encoder.close();
        finalOutputPath = zipPath;
        
        await outputFolder.delete(recursive: true);
      } else {
        finalOutputPath = outputFolder.path;
      }
      
      onProgress(1.0, 'Conversion completed!');
      return finalOutputPath;
      
    } catch (e) {
      throw Exception('PDF to Image conversion failed: $e');
    }
  }
}

/// Converts PDF to Excel spreadsheet
class PDFToExcelConverter {
  /// Converts PDF to Excel spreadsheet
  static Future<String> convert({
    required File pdfFile,
    required Function(double progress, String message) onProgress,
    bool detectTables = true,
  }) async {
    sf_pdf.PdfDocument? pdfDocument;
    
    try {
      onProgress(0.05, 'Loading PDF...');
      final bytes = await pdfFile.readAsBytes();
      pdfDocument = sf_pdf.PdfDocument(inputBytes: bytes);
      final pageCount = pdfDocument.pages.count;
      
      if (pageCount == 0) {
        throw Exception('PDF has no pages');
      }
      
      onProgress(0.10, 'Preparing Excel document...');
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Create Excel workbook
      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['Sheet1'];
      
      // Add headers
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .value = excel_lib.TextCellValue('Page Number');
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
        .value = excel_lib.TextCellValue('Content');
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0))
        .value = excel_lib.TextCellValue('Word Count');
      
      final textExtractor = sf_pdf.PdfTextExtractor(pdfDocument);
      
      for (int i = 0; i < pageCount; i++) {
        final pageNum = i + 1;
        onProgress(
          0.10 + (0.75 * (i / pageCount)),
          'Processing page $pageNum of $pageCount...',
        );
        
        final extractedText = textExtractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        
        if (extractedText.isNotEmpty) {
          // Add data to Excel
          sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1))
            .value = excel_lib.IntCellValue(pageNum);
          sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1))
            .value = excel_lib.TextCellValue(extractedText);
          sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1))
            .value = excel_lib.IntCellValue(extractedText.split(' ').length);
        }
        
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      onProgress(0.90, 'Saving Excel file...');
      final outputPath = '${outputDir.path}/converted_$timestamp.xlsx';
      final excelBytes = excel.encode();
      await File(outputPath).writeAsBytes(excelBytes!);
      
      onProgress(1.0, 'Done!');
      return outputPath;
      
    } catch (e) {
      throw Exception('Excel conversion failed: $e');
    } finally {
      pdfDocument?.dispose();
    }
  }
}

/// Converts PDF to PowerPoint presentation
class PDFToPowerPointConverter {
  /// Converts PDF to PowerPoint presentation
  static Future<String> convert({
    required File pdfFile,
    required Function(double progress, String message) onProgress,
  }) async {
    try {
      onProgress(0.05, 'Loading PDF...');
      final bytes = await pdfFile.readAsBytes();
      
      // Get page count
      final document = sf_pdf.PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      document.dispose();
      
      if (pageCount == 0) {
        throw Exception('PDF has no pages');
      }
      
      onProgress(0.10, 'Preparing presentation...');
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFolder = Directory('${outputDir.path}/ppt_slides_$timestamp');
      
      if (!await outputFolder.exists()) {
        await outputFolder.create(recursive: true);
      }
      
      // Convert pages to images for slides
      final List<String> slidePaths = [];
      int pageNum = 0;
      
      await for (var page in Printing.raster(
        bytes,
        pages: List.generate(pageCount, (index) => index),
        dpi: 150.0, // Lower DPI for presentation slides
      )) {
        pageNum++;
        onProgress(
          0.10 + (0.70 * ((pageNum - 1) / pageCount)),
          'Creating slide $pageNum of $pageCount...',
        );
        
        // Get image from raster
        final imageBytes = await page.toPng();
        
        // Save as PNG for slide
        final slidePath = '${outputFolder.path}/slide_$pageNum.png';
        await File(slidePath).writeAsBytes(imageBytes);
        slidePaths.add(slidePath);
      }
      
      onProgress(0.85, 'Finalizing presentation...');
      
      // Create ZIP archive containing all slides with .pptx extension
      final pptxPath = '${outputDir.path}/presentation_$timestamp.pptx';
      final encoder = ZipFileEncoder();
      encoder.create(pptxPath);
      
      for (final slidePath in slidePaths) {
        encoder.addFile(File(slidePath));
      }
      
      encoder.close();
      
      // Clean up individual slides
      await outputFolder.delete(recursive: true);
      
      onProgress(1.0, 'Done!');
      return pptxPath;
      
    } catch (e) {
      throw Exception('PowerPoint conversion failed: $e');
    }
  }
}