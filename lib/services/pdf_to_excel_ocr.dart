import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:printing/printing.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PDFToExcelWithOCR {
  /// Converts image-based PDF to Excel using OCR with table detection
  static Future<String> convert({
    required File pdfFile,
    required Function(double progress, String message) onProgress,
    bool detectTables = true,
    int dpi = 300,
  }) async {
    sf_pdf.PdfDocument? pdfDocument;
    xlsio.Workbook? workbook;
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
      
      // Step 2: Setup Excel workbook
      onProgress(0.10, 'Creating Excel workbook...');
      workbook = xlsio.Workbook();
      xlsio.Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'OCR Data';
      
      // Setup temp directory
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDir = Directory('${outputDir.path}/temp_excel_ocr_$timestamp');
      
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      
      int currentRow = 1;
      
      // Step 3: Process each page with OCR
      int currentPage = 0;
      
      await for (var page in Printing.raster(bytes, dpi: dpi.toDouble())) {
        currentPage++;
        onProgress(
          0.10 + (0.75 * (currentPage / pageCount)),
          'OCR processing page $currentPage of $pageCount...',
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
          
          // Add page header
          final headerCell = sheet.getRangeByIndex(currentRow, 1);
          headerCell.setText('Page $currentPage');
          headerCell.cellStyle.bold = true;
          headerCell.cellStyle.backColor = '#4472C4';
          headerCell.cellStyle.fontColor = '#FFFFFF';
          headerCell.cellStyle.fontSize = 11;
          currentRow++;
          
          if (recognizedText.text.isNotEmpty) {
            if (detectTables) {
              // Try to detect table structure from OCR
              final tableData = _extractTableFromOCR(recognizedText);
              
              if (tableData.isNotEmpty) {
                // Add table data
                for (final row in tableData) {
                  for (int col = 0; col < row.length; col++) {
                    final cell = sheet.getRangeByIndex(currentRow, col + 1);
                    cell.setText(row[col]);
                    
                    // Add borders
                    cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
                    cell.cellStyle.borders.all.color = '#D0D0D0';
                  }
                  currentRow++;
                }
              } else {
                // No table detected, add as text lines
                currentRow = _addTextLines(sheet, recognizedText.text, currentRow);
              }
            } else {
              // Add as plain text
              currentRow = _addTextLines(sheet, recognizedText.text, currentRow);
            }
          } else {
            // No text found
            sheet.getRangeByIndex(currentRow, 1).setText('[No text detected]');
            sheet.getRangeByIndex(currentRow, 1).cellStyle.italic = true;
            currentRow++;
          }
          
          currentRow++; // Add spacing between pages
          
          // Clean up temp image
          await imageFile.delete();
          
        } catch (e) {
          print('Error processing page $currentPage: $e');
          sheet.getRangeByIndex(currentRow, 1).setText('[Error processing page $currentPage]');
          currentRow++;
        }
        
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      // Step 4: Format Excel
      onProgress(0.88, 'Formatting Excel...');
      
      // Auto-fit columns
      for (int i = 1; i <= 15; i++) {
        try {
          sheet.autoFitColumn(i);
        } catch (e) {
          // Ignore autofit errors
        }
      }
      
      // Freeze first row if it exists
      if (currentRow > 1) {
        sheet.getRangeByIndex(1, 1).cellStyle.bold = true;
      }
      
      // Step 5: Save Excel file
      onProgress(0.92, 'Saving Excel file...');
      final outputPath = '${outputDir.path}/converted_ocr_$timestamp.xlsx';
      
      final List<int> excelBytes = workbook.saveAsStream();
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(excelBytes);
      
      // Cleanup
      await tempDir.delete(recursive: true);
      
      onProgress(1.0, 'OCR to Excel completed!');
      return outputPath;
      
    } catch (e) {
      throw Exception('PDF to Excel OCR failed: $e');
    } finally {
      pdfDocument?.dispose();
      workbook?.dispose();
      textRecognizer.close();
    }
  }
  
  /// Extract table structure from OCR text blocks
  static List<List<String>> _extractTableFromOCR(RecognizedText recognizedText) {
    final tableData = <List<String>>[];
    
    // Group text blocks by vertical position (rows)
    final Map<int, List<TextBlock>> rowGroups = {};
    
    for (final block in recognizedText.blocks) {
      // Use Y coordinate to group blocks into rows (with tolerance)
      final rowKey = (block.boundingBox.top / 20).round() * 20;
      
      if (!rowGroups.containsKey(rowKey)) {
        rowGroups[rowKey] = [];
      }
      rowGroups[rowKey]!.add(block);
    }
    
    // Sort rows by Y position
    final sortedRows = rowGroups.keys.toList()..sort();
    
    // Process each row
    for (final rowKey in sortedRows) {
      final blocks = rowGroups[rowKey]!;
      
      // Sort blocks in row by X position (left to right)
      blocks.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      
      // Check if this looks like a table row (multiple cells)
      if (blocks.length > 1) {
        final rowData = blocks.map((b) => b.text.trim()).toList();
        tableData.add(rowData);
      }
    }
    
    // Only return if we found at least 2 rows (header + data)
    return tableData.length >= 2 ? tableData : [];
  }
  
  /// Add text as individual lines to Excel
  static int _addTextLines(xlsio.Worksheet sheet, String text, int startRow) {
    final lines = text.split('\n');
    int currentRow = startRow;
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      // Try to split line by multiple spaces (potential table)
      final cells = trimmed.split(RegExp(r'  {2,}'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      
      if (cells.length > 1) {
        // Multiple cells in line
        for (int col = 0; col < cells.length; col++) {
          sheet.getRangeByIndex(currentRow, col + 1).setText(cells[col]);
        }
      } else {
        // Single cell
        sheet.getRangeByIndex(currentRow, 1).setText(trimmed);
      }
      
      currentRow++;
    }
    
    return currentRow;
  }
}