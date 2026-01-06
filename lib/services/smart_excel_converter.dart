import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:excel/excel.dart' as excel_lib;

typedef ProgressCallback = void Function(double progress, String message);

/// Smart Excel converter with table detection
class SmartExcelConverter {
  /// Converts PDF to Excel with smart table detection
  static Future<String> convert({
    required File pdfFile,
    required ProgressCallback onProgress,
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
      
      onProgress(0.10, 'Analyzing document structure...');
      
      // Create Excel workbook
      final excel = excel_lib.Excel.createExcel();
      excel.delete('Sheet1'); // Remove default sheet
      
      final textExtractor = sf_pdf.PdfTextExtractor(pdfDocument);
      
      for (int i = 0; i < pageCount; i++) {
        onProgress(0.10 + (0.80 * (i / pageCount)), 'Processing page ${i + 1} of $pageCount...');
        
        final pageText = textExtractor.extractText(startPageIndex: i, endPageIndex: i);
        
        if (pageText.isEmpty) continue;
        
        // Create sheet for each page
        final sheetName = 'Page ${i + 1}';
        final sheet = excel[sheetName];
        
        // Detect and parse tables from text
        final rows = _detectTables(pageText);
        
        // Write rows to Excel
        for (int rowIdx = 0; rowIdx < rows.length; rowIdx++) {
          final row = rows[rowIdx];
          for (int colIdx = 0; colIdx < row.length; colIdx++) {
            final cellValue = row[colIdx].trim();
            if (cellValue.isNotEmpty) {
              final cell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx));
              
              // Try to parse as number
              final numValue = double.tryParse(cellValue.replaceAll(',', ''));
              if (numValue != null) {
                cell.value = excel_lib.DoubleCellValue(numValue);
              } else {
                cell.value = excel_lib.TextCellValue(cellValue);
              }
            }
          }
        }
        
        // Auto-width columns (approximate)
        // Not directly supported, but data is structured
      }
      
      onProgress(0.95, 'Saving Excel file...');
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${outputDir.path}/smart_converted_$timestamp.xlsx';
      
      final excelBytes = excel.encode();
      await File(outputPath).writeAsBytes(excelBytes!);
      
      onProgress(1.0, 'Done!');
      return outputPath;
      
    } catch (e) {
      throw Exception('Smart Excel conversion failed: $e');
    } finally {
      pdfDocument?.dispose();
    }
  }
  
  /// Detect tables in text by analyzing delimiters and structure
  static List<List<String>> _detectTables(String text) {
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final rows = <List<String>>[];
    
    for (final line in lines) {
      List<String> cells;
      
      // Try different delimiters to detect table structure
      if (line.contains('\t')) {
        // Tab-separated
        cells = line.split('\t');
      } else if (line.contains('|')) {
        // Pipe-separated (common in PDF tables)
        cells = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      } else if (_hasConsistentSpacing(line)) {
        // Multiple spaces as delimiter (common in PDFs)
        cells = _splitByMultipleSpaces(line);
      } else {
        // Single column
        cells = [line.trim()];
      }
      
      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }
    
    // Normalize column count (fill missing cells)
    if (rows.isNotEmpty) {
      final maxCols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      for (int i = 0; i < rows.length; i++) {
        while (rows[i].length < maxCols) {
          rows[i].add('');
        }
      }
    }
    
    return rows;
  }
  
  /// Check if line has consistent spacing pattern (table-like)
  static bool _hasConsistentSpacing(String line) {
    // Check for 2+ consecutive spaces (table delimiter)
    return RegExp(r'\s{2,}').hasMatch(line) && line.split(RegExp(r'\s{2,}')).length > 1;
  }
  
  /// Split line by multiple consecutive spaces
  static List<String> _splitByMultipleSpaces(String line) {
    return line.split(RegExp(r'\s{2,}')).map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
  }
}
