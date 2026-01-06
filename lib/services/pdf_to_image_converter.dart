import 'dart:io'; 
import 'dart:typed_data'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf; 
import 'package:printing/printing.dart'; 
import 'package:image/image.dart' as img; 
import 'package:archive/archive_io.dart'; 
 
class PDFToImageConverter { 
  /// Converts PDF to images using printing library 
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
      
      // Get page count 
      final sf_pdf.PdfDocument document = sf_pdf.PdfDocument(inputBytes: bytes); 
      final pageCount = document.pages.count; 
      document.dispose(); 
      
      if (pageCount == 0) { 
        throw Exception('PDF has no pages'); 
      } 
      
      // Step 2: Setup output 
      onProgress(0.10, 'Setting up output directory...'); 
      final outputDir = await getApplicationDocumentsDirectory(); 
      final timestamp = DateTime.now().millisecondsSinceEpoch; 
      final outputFolder = Directory('${outputDir.path}/pdf_images_$timestamp'); 
      
      if (!await outputFolder.exists()) { 
        await outputFolder.create(recursive: true); 
      } 
      
      // Step 3: Convert pages 
      final List<String> imagePaths = []; 
      int currentPage = 0; 
      
      await for (var page in Printing.raster( 
        bytes, 
        dpi: dpi.toDouble(), 
      )) { 
        currentPage++; 
        final progressPercent = 0.10 + (0.70 * (currentPage / pageCount)); 
        onProgress( 
          progressPercent, 
          'Converting page $currentPage of $pageCount...', 
        ); 
        
        // Get PNG bytes 
        final imageBytes = await page.toPng(); 
        
        // Process based on format 
        String extension; 
        Uint8List finalBytes; 
        
        if (format.toLowerCase() == 'jpeg' || format.toLowerCase() == 'jpg') { 
          // Convert PNG to JPEG 
          final image = img.decodePng(imageBytes); 
          if (image == null) throw Exception('Failed to decode image'); 
          
          // Encode to JPEG with quality 
          finalBytes = Uint8List.fromList(img.encodeJpg(image, quality: 85)); 
          extension = 'jpg'; 
        } else { 
          // Keep as PNG 
          finalBytes = imageBytes; 
          extension = 'png'; 
        } 
        
        // Save image 
        final outputPath = '${outputFolder.path}/page_$currentPage.$extension'; 
        final outputFile = File(outputPath); 
        await outputFile.writeAsBytes(finalBytes); 
        imagePaths.add(outputPath); 
        
        // Allow UI updates 
        await Future.delayed(const Duration(milliseconds: 10)); 
      } 
      
      // Step 4: Create ZIP 
      onProgress(0.85, 'Finalizing conversion...'); 
      
      String finalOutputPath; 
      
      if (createZip && imagePaths.isNotEmpty) { 
        onProgress(0.90, 'Creating ZIP archive...'); 
        final zipPath = '${outputDir.path}/pdf_images_$timestamp.zip'; 
        final encoder = ZipFileEncoder(); 
        encoder.create(zipPath); 
        
        for (final imagePath in imagePaths) { 
          encoder.addFile(File(imagePath)); 
        } 
        
        encoder.close(); 
        finalOutputPath = zipPath; 
        
        // Clean up individual files 
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