import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:printing/printing.dart';

typedef ProgressCallback = void Function(double progress, String message);

/// Creates HTML file from PDF content
class PDFToHtmlConverter {
  /// Converts PDF to HTML file with styled content
  static Future<String> convert({
    required File pdfFile,
    required ProgressCallback onProgress,
    bool embedImages = true,
    int imageDpi = 150,
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
      
      onProgress(0.10, 'Extracting content...');
      final textExtractor = sf_pdf.PdfTextExtractor(pdfDocument);
      
      final htmlContent = StringBuffer();
      
      // HTML header with styling
      htmlContent.write('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Converted PDF</title>
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      line-height: 1.6;
      max-width: 900px;
      margin: 0 auto;
      padding: 20px;
      background-color: #f5f5f5;
      color: #333;
    }
    .page {
      background: white;
      padding: 40px;
      margin-bottom: 30px;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    .page-header {
      color: #2E74B5;
      border-bottom: 2px solid #2E74B5;
      padding-bottom: 10px;
      margin-bottom: 20px;
    }
    .page-content {
      white-space: pre-wrap;
      word-wrap: break-word;
    }
    .page-image {
      max-width: 100%;
      height: auto;
      border: 1px solid #ddd;
      border-radius: 4px;
      margin: 20px 0;
    }
    h1 { color: #1a5490; }
    .doc-info {
      background: #e8f4fd;
      padding: 15px;
      border-radius: 8px;
      margin-bottom: 30px;
    }
    @media print {
      .page { page-break-after: always; box-shadow: none; }
    }
  </style>
</head>
<body>
  <div class="doc-info">
    <h1>📄 Converted Document</h1>
    <p><strong>Pages:</strong> $pageCount</p>
    <p><strong>Converted:</strong> ${DateTime.now().toString().split('.')[0]}</p>
  </div>
''');
      
      // Extract and add each page
      for (int i = 0; i < pageCount; i++) {
        onProgress(0.10 + (0.80 * (i / pageCount)), 'Processing page ${i + 1} of $pageCount...');
        
        final pageText = textExtractor.extractText(startPageIndex: i, endPageIndex: i);
        final escapedText = _escapeHtml(pageText);
        
        htmlContent.write('''
  <div class="page">
    <h2 class="page-header">Page ${i + 1}</h2>
    <div class="page-content">$escapedText</div>
  </div>
''');
      }
      
      // Close HTML
      htmlContent.write('''
</body>
</html>
''');
      
      onProgress(0.95, 'Saving HTML file...');
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${outputDir.path}/converted_$timestamp.html';
      
      await File(outputPath).writeAsString(htmlContent.toString());
      
      onProgress(1.0, 'Done!');
      return outputPath;
      
    } catch (e) {
      throw Exception('HTML conversion failed: $e');
    } finally {
      pdfDocument?.dispose();
    }
  }
  
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
