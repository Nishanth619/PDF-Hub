import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:archive/archive_io.dart';
import 'package:image/image.dart' as img;

typedef ProgressCallback = void Function(double progress, String message);

/// Improved PDF to Image converter that handles image-based PDFs better
class PDFToImageConverterV2 {
  static Future<String> convert({
    required File pdfFile,
    required ProgressCallback onProgress,
    int dpi = 200, // Higher DPI for better quality
    String format = 'png',
    bool createZip = true,
  }) async {
    PdfDocument? document;
    
    try {
      // Step 1: Load PDF using pdfx (better for image-based PDFs)
      onProgress(0.05, 'Opening PDF document...');
      document = await PdfDocument.openFile(pdfFile.path);
      final pageCount = document.pagesCount;
      
      // Get original PDF filename for output naming
      final pdfName = pdfFile.path.split('/').last.split('\\').last
          .replaceAll('.pdf', '').replaceAll('.PDF', '');
      
      if (pageCount == 0) {
        throw Exception('PDF has no pages');
      }
      
      // Step 2: Setup output directory
      onProgress(0.10, 'Setting up output directory...');
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFolder = Directory('${outputDir.path}/${pdfName}_images_$timestamp');
      
      if (!await outputFolder.exists()) {
        await outputFolder.create(recursive: true);
      }
      
      // Step 3: Convert pages using pdfx with high quality rendering
      final List<String> imagePaths = [];
      
      // Calculate render dimensions based on DPI
      // Standard PDF is 72 DPI, so we scale up
      final scale = dpi / 72.0;
      
      for (int i = 1; i <= pageCount; i++) {
        final progressPercent = 0.10 + (0.75 * ((i - 1) / pageCount));
        onProgress(progressPercent, 'Converting page $i of $pageCount...');
        
        // Open page
        final page = await document.getPage(i);
        
        // Calculate dimensions with scale for better quality
        final width = page.width * scale;
        final height = page.height * scale;
        
        // Render page with high quality
        // backgroundColor parameter ensures proper background (not black)
        final pageImage = await page.render(
          width: width,
          height: height,
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF', // White background to prevent black areas
        );
        
        await page.close();
        
        if (pageImage == null) {
          throw Exception('Failed to render page $i');
        }
        
        // Get the image bytes
        Uint8List finalBytes = pageImage.bytes;
        String extension = 'png';
        
        // Convert to JPEG if requested
        if (format.toLowerCase() == 'jpeg' || format.toLowerCase() == 'jpg') {
          final image = img.decodePng(pageImage.bytes);
          if (image != null) {
            finalBytes = Uint8List.fromList(img.encodeJpg(image, quality: 90));
            extension = 'jpg';
          }
        }
        
        // Save image
        final outputPath = '${outputFolder.path}/page_$i.$extension';
        await File(outputPath).writeAsBytes(finalBytes);
        imagePaths.add(outputPath);
        
        // Small delay to prevent UI freeze
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      // Step 4: Create ZIP if requested
      onProgress(0.90, 'Finalizing conversion...');
      
      String finalOutputPath;
      
      if (createZip && imagePaths.isNotEmpty) {
        onProgress(0.95, 'Creating ZIP archive...');
        final zipPath = '${outputDir.path}/${pdfName}_images_$timestamp.zip';
        final encoder = ZipFileEncoder();
        encoder.create(zipPath);
        
        for (final imagePath in imagePaths) {
          encoder.addFile(File(imagePath));
        }
        
        encoder.close();
        finalOutputPath = zipPath;
        
        // Clean up individual images
        await outputFolder.delete(recursive: true);
      } else {
        finalOutputPath = outputFolder.path;
      }
      
      onProgress(1.0, 'Conversion completed!');
      return finalOutputPath;
      
    } catch (e) {
      throw Exception('PDF to Image conversion failed: $e');
    } finally {
      await document?.close();
    }
  }
}
