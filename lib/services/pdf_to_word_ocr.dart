import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:printing/printing.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PDFToWordWithOCR {
  /// Converts image-based PDF to Word using OCR
  static Future<String> convert({
    required File pdfFile,
    required Function(double progress, String message) onProgress,
    bool preserveFormatting = true,
    String language = 'en', // Language for OCR
  }) async {
    sf_pdf.PdfDocument? pdfDocument;
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      // Step 1: Load PDF
      onProgress(0.05, 'Loading PDF document...');
      final bytes = await pdfFile.readAsBytes();
      pdfDocument = sf_pdf.PdfDocument(inputBytes: bytes);
      final pageCount = pdfDocument.pages.count;
      
      if (pageCount == 0) {
        throw Exception('PDF has no pages');
      }
      
      // Step 2: Setup output
      onProgress(0.10, 'Initializing OCR engine...');
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDir = Directory('${outputDir.path}/temp_ocr_$timestamp');
      
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      
      final contentBuffer = StringBuffer();
      
      // Add header
      contentBuffer.writeln('PDF TO WORD CONVERSION (OCR)');
      contentBuffer.writeln('Generated: ${DateTime.now()}');
      contentBuffer.writeln('Total Pages: $pageCount');
      contentBuffer.writeln('OCR Language: $language');
      contentBuffer.writeln('${'=' * 60}\n\n');
      
      // Step 3: Convert each page to image and perform OCR
      int currentPage = 0;
      
      await for (var page in Printing.raster(bytes, dpi: 300)) {
        currentPage++;
        onProgress(
          0.10 + (0.80 * (currentPage / pageCount)),
          'Processing page $currentPage of $pageCount with OCR...',
        );
        
        try {
          // Convert page to image
          final imageBytes = await page.toPng();
          final imagePath = '${tempDir.path}/page_$currentPage.png';
          final imageFile = File(imagePath);
          await imageFile.writeAsBytes(imageBytes);
          
          // Perform OCR
          final inputImage = InputImage.fromFilePath(imagePath);
          final recognizedText = await textRecognizer.processImage(inputImage);
          
          // Add to content
          contentBuffer.writeln('\n━━━━━ Page $currentPage ━━━━━\n');
          
          if (recognizedText.text.isNotEmpty) {
            if (preserveFormatting) {
              contentBuffer.writeln(_formatOCRText(recognizedText));
            } else {
              contentBuffer.writeln(recognizedText.text);
            }
          } else {
            contentBuffer.writeln('[No text detected on this page]');
          }
          
          contentBuffer.writeln();
          
          // Clean up temp image
          await imageFile.delete();
          
        } catch (e) {
          print('Error processing page $currentPage: $e');
          contentBuffer.writeln('[Error processing page $currentPage: $e]');
        }
        
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Step 4: Save document
      onProgress(0.92, 'Saving document...');
      
      final outputPath = '${outputDir.path}/converted_ocr_$timestamp.txt';
      final outputFile = File(outputPath);
      await outputFile.writeAsString(contentBuffer.toString());
      
      // Cleanup
      await tempDir.delete(recursive: true);
      
      onProgress(1.0, 'OCR conversion completed!');
      return outputPath;
      
    } catch (e) {
      throw Exception('OCR conversion failed: $e');
    } finally {
      pdfDocument?.dispose();
      textRecognizer.close();
    }
  }
  
  static String _formatOCRText(RecognizedText recognizedText) {
    final buffer = StringBuffer();
    
    // Process by text blocks for better formatting
    for (final block in recognizedText.blocks) {
      // Check if block looks like a heading
      if (block.text.length < 60 && 
          (block.text == block.text.toUpperCase() || 
           !block.text.endsWith('.'))) {
        buffer.writeln('\n## ${block.text.trim()}\n');
      } else {
        buffer.writeln(block.text.trim());
      }
      buffer.writeln();
    }
    
    return buffer.toString();
  }
}

// Simple OCR-enabled converter (recommended for image-based PDFs)
class SimplePDFToWordOCR {
  /// Simple conversion for image-based PDFs
  static Future<String> convert({
    required File pdfFile,
    required Function(double progress, String message) onProgress,
  }) async {
    final textRecognizer = TextRecognizer();
    
    try {
      onProgress(0.05, 'Loading PDF...');
      final bytes = await pdfFile.readAsBytes();
      
      final doc = sf_pdf.PdfDocument(inputBytes: bytes);
      final pageCount = doc.pages.count;
      doc.dispose();
      
      onProgress(0.10, 'Starting OCR...');
      
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDir = Directory('${outputDir.path}/temp_$timestamp');
      await tempDir.create(recursive: true);
      
      final contentBuffer = StringBuffer();
      contentBuffer.writeln('SCANNED PDF CONVERSION');
      contentBuffer.writeln('Date: ${DateTime.now()}');
      contentBuffer.writeln('Pages: $pageCount\n\n');
      
      int page = 0;
      await for (var rasterPage in Printing.raster(bytes, dpi: 300)) {
        page++;
        onProgress(
          0.10 + (0.80 * (page / pageCount)),
          'Reading page $page of $pageCount...',
        );
        
        final imgBytes = await rasterPage.toPng();
        final imgPath = '${tempDir.path}/p$page.png';
        await File(imgPath).writeAsBytes(imgBytes);
        
        final inputImage = InputImage.fromFilePath(imgPath);
        final result = await textRecognizer.processImage(inputImage);
        
        contentBuffer.writeln('─── Page $page ───\n');
        contentBuffer.writeln(result.text.isNotEmpty ? result.text : '[No text found]');
        contentBuffer.writeln('\n');
        
        await File(imgPath).delete();
      }
      
      onProgress(0.92, 'Saving...');
      
      final outputPath = '${outputDir.path}/ocr_result_$timestamp.txt';
      await File(outputPath).writeAsString(contentBuffer.toString());
      
      await tempDir.delete(recursive: true);
      
      onProgress(1.0, 'Done!');
      return outputPath;
      
    } finally {
      textRecognizer.close();
    }
  }
}