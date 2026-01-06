import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

class PDFToWordConverter {
  /// Converts PDF to text document (Word-compatible)
  static Future<String> convert({
    required File pdfFile,
    required Function(double progress, String message) onProgress,
    bool preserveFormatting = true,
  }) async {
    sf_pdf.PdfDocument? pdfDocument;
    
    try {
      onProgress(0.05, 'Loading PDF document...');
      final bytes = await pdfFile.readAsBytes();
      pdfDocument = sf_pdf.PdfDocument(inputBytes: bytes);
      final pageCount = pdfDocument.pages.count;
      
      if (pageCount == 0) {
        throw Exception('PDF has no pages');
      }
      
      onProgress(0.10, 'Analyzing PDF structure...');
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final contentBuffer = StringBuffer();
      
      // Add document header
      contentBuffer.writeln('PDF TO WORD CONVERSION');
      contentBuffer.writeln('Generated: ${DateTime.now()}');
      contentBuffer.writeln('Total Pages: $pageCount');
      contentBuffer.writeln('${'=' * 60}\n\n');
      
      // Try different extraction methods
      bool hasText = false;
      
      // Method 1: Try extracting all text at once
      onProgress(0.15, 'Attempting full text extraction...');
      try {
        final textExtractor = sf_pdf.PdfTextExtractor(pdfDocument);
        final fullText = textExtractor.extractText();
        
        if (fullText.trim().isNotEmpty) {
          hasText = true;
          contentBuffer.writeln('Full Document Content:\n');
          
          if (preserveFormatting) {
            contentBuffer.writeln(_formatText(fullText));
          } else {
            contentBuffer.writeln(fullText);
          }
          contentBuffer.writeln('\n${'=' * 60}\n');
        }
      } catch (e) {
        print('Full text extraction failed: $e');
      }
      
      // Method 2: Extract page by page with layout
      onProgress(0.20, 'Extracting text page by page...');
      for (int i = 0; i < pageCount; i++) {
        final pageNum = i + 1;
        onProgress(
          0.20 + (0.60 * (i / pageCount)),
          'Extracting text from page $pageNum of $pageCount...',
        );
        
        try {
          final textExtractor = sf_pdf.PdfTextExtractor(pdfDocument);
          
          // Try with layout preservation
          final extractedText = textExtractor.extractText(
            startPageIndex: i,
            endPageIndex: i,
            layoutText: true, // Preserve layout
          );
          
          if (extractedText.trim().isNotEmpty) {
            hasText = true;
            contentBuffer.writeln('\n━━━━━ Page $pageNum ━━━━━\n');
            
            if (preserveFormatting) {
              final formatted = _formatText(extractedText);
              contentBuffer.writeln(formatted);
            } else {
              contentBuffer.writeln(extractedText);
            }
            contentBuffer.writeln();
          } else {
            // Try without layout if first method fails
            final simpleText = textExtractor.extractText(
              startPageIndex: i,
              endPageIndex: i,
            );
            
            if (simpleText.trim().isNotEmpty) {
              hasText = true;
              contentBuffer.writeln('\n━━━━━ Page $pageNum ━━━━━\n');
              contentBuffer.writeln(simpleText);
              contentBuffer.writeln();
            }
          }
        } catch (e) {
          print('Error extracting page $pageNum: $e');
          contentBuffer.writeln('\n[Error extracting text from page $pageNum]\n');
        }
        
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      // Method 3: Try extracting text line by line (for scanned PDFs)
      if (!hasText) {
        onProgress(0.85, 'Trying alternative extraction method...');
        contentBuffer.writeln('\n${'=' * 60}\n');
        contentBuffer.writeln('ALTERNATIVE EXTRACTION:\n');
        
        for (int i = 0; i < pageCount; i++) {
          try {
            final page = pdfDocument.pages[i];
            
            // Try to extract annotations or form fields
            if (page.annotations.count > 0) {
              contentBuffer.writeln('\n━━━━━ Page ${i + 1} - Annotations ━━━━━\n');
              for (int j = 0; j < page.annotations.count; j++) {
                final annotation = page.annotations[j];
                if (annotation.text.isNotEmpty) {
                  contentBuffer.writeln(annotation.text);
                  hasText = true;
                }
              }
            }
          } catch (e) {
            print('Error with alternative extraction on page ${i + 1}: $e');
          }
        }
      }
      
      // Add warning if no text found
      if (!hasText) {
        contentBuffer.writeln('\n${'!' * 60}\n');
        contentBuffer.writeln('⚠️ WARNING: No extractable text found!');
        contentBuffer.writeln('\nThis PDF may be:');
        contentBuffer.writeln('1. A scanned document (image-based)');
        contentBuffer.writeln('2. Password protected');
        contentBuffer.writeln('3. Created with special encoding');
        contentBuffer.writeln('\nTo extract text from scanned PDFs, you need OCR.');
        contentBuffer.writeln('Consider using PDF to Image conversion first.');
        contentBuffer.writeln('\n${'!' * 60}\n');
      }
      
      onProgress(0.92, 'Saving document...');
      
      // Save as .txt file (compatible with Word)
      final outputPath = '${outputDir.path}/converted_document_$timestamp.txt';
      final outputFile = File(outputPath);
      await outputFile.writeAsString(contentBuffer.toString());
      
      onProgress(1.0, hasText ? 'Conversion completed!' : 'Extraction completed with warnings');
      return outputPath;
      
    } catch (e) {
      throw Exception('PDF to Word conversion failed: $e');
    } finally {
      pdfDocument?.dispose();
    }
  }
  
  static String _formatText(String text) {
    if (text.trim().isEmpty) return '';
    
    // Remove excessive whitespace while preserving structure
    text = text.replaceAll(RegExp(r' {3,}'), '  '); // Keep max 2 spaces
    text = text.replaceAll(RegExp(r'\n{4,}'), '\n\n\n'); // Keep max 3 line breaks
    
    // Format paragraphs
    final lines = text.split('\n');
    final buffer = StringBuffer();
    
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        buffer.writeln(); // Preserve blank lines
        continue;
      }
      
      // Detect headings (short lines, uppercase, or no period)
      if (trimmed.length < 60 && 
          (trimmed == trimmed.toUpperCase() || 
           (!trimmed.endsWith('.') && !trimmed.endsWith(',')))) {
        buffer.writeln('\n## $trimmed\n');
      } else {
        buffer.writeln(trimmed);
      }
    }
    
    return buffer.toString();
  }
}