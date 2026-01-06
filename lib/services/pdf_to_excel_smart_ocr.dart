import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:printing/printing.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Advanced: Smart table detection with column alignment
class PDFToExcelSmartOCR {
  /// Advanced Excel conversion with smart table detection
  static Future<String> convert({
    required File pdfFile,
    required Function(double progress, String message) onProgress,
    int dpi = 300,
  }) async {
    sf_pdf.PdfDocument? pdfDocument;
    xlsio.Workbook? workbook;
    final textRecognizer = TextRecognizer();
    
    try {
      onProgress(0.05, 'Loading PDF...');
      final bytes = await pdfFile.readAsBytes();
      pdfDocument = sf_pdf.PdfDocument(inputBytes: bytes);
      final pageCount = pdfDocument.pages.count;
      
      if (pageCount == 0) {
        throw Exception('PDF has no pages');
      }
      
      onProgress(0.10, 'Initializing OCR...');
      workbook = xlsio.Workbook();
      
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDir = Directory('${outputDir.path}/temp_smart_$timestamp');
      await tempDir.create(recursive: true);
      
      int sheetIndex = 0;
      
      // Process each page
      int currentPage = 0;
      
      await for (var page in Printing.raster(bytes, dpi: dpi.toDouble())) {
        currentPage++;
        onProgress(
          0.10 + (0.75 * (currentPage / pageCount)),
          'Processing page $currentPage with smart OCR...',
        );
        
        // Create new sheet for each page
        xlsio.Worksheet sheet;
        if (sheetIndex == 0) {
          sheet = workbook.worksheets[0];
        } else {
          sheet = workbook.worksheets.add();
        }
        sheet.name = 'Page $currentPage';
        sheetIndex++;
        
        try {
          // Save page as image
          final imageBytes = await page.toPng();
          final imagePath = '${tempDir.path}/page_$currentPage.png';
          await File(imagePath).writeAsBytes(imageBytes);
          
          // OCR
          final inputImage = InputImage.fromFilePath(imagePath);
          final recognizedText = await textRecognizer.processImage(inputImage);
          
          // Smart table detection
          final tableData = _detectSmartTable(recognizedText);
          
          if (tableData.isNotEmpty) {
            // Add table with formatting
            for (int r = 0; r < tableData.length; r++) {
              final rowData = tableData[r];
              
              for (int c = 0; c < rowData.length; c++) {
                final cell = sheet.getRangeByIndex(r + 1, c + 1);
                cell.setText(rowData[c]);
                
                // Format first row as header
                if (r == 0) {
                  cell.cellStyle.bold = true;
                  cell.cellStyle.backColor = '#366092';
                  cell.cellStyle.fontColor = '#FFFFFF';
                }
                
                // Add borders
                cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
              }
            }
            
            // Auto-fit columns
            for (int i = 1; i <= tableData[0].length; i++) {
              sheet.autoFitColumn(i);
            }
          } else {
            // Add as text
            sheet.getRangeByIndex(1, 1).setText(recognizedText.text);
          }
          
          await File(imagePath).delete();
          
        } catch (e) {
          print('Error on page $currentPage: $e');
          sheet.getRangeByIndex(1, 1).setText('[Error processing page]');
        }
        
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      onProgress(0.90, 'Saving Excel...');
      final outputPath = '${outputDir.path}/smart_ocr_$timestamp.xlsx';
      
      final excelBytes = workbook.saveAsStream();
      await File(outputPath).writeAsBytes(excelBytes);
      
      await tempDir.delete(recursive: true);
      
      onProgress(1.0, 'Done!');
      return outputPath;
      
    } catch (e) {
      throw Exception('Smart OCR failed: $e');
    } finally {
      pdfDocument?.dispose();
      workbook?.dispose();
      textRecognizer.close();
    }
  }
  
  /// Detect table with column alignment
  static List<List<String>> _detectSmartTable(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return [];
    
    // Group blocks by rows (Y-coordinate)
    final Map<int, List<TextElement>> rowMap = {};
    
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final rowKey = (element.boundingBox.top / 15).round() * 15;
          
          if (!rowMap.containsKey(rowKey)) {
            rowMap[rowKey] = [];
          }
          rowMap[rowKey]!.add(element);
        }
      }
    }
    
    // Sort rows
    final sortedRowKeys = rowMap.keys.toList()..sort();
    
    if (sortedRowKeys.length < 2) return [];
    
    // Detect column positions from first few rows
    final columnPositions = _detectColumnPositions(rowMap, sortedRowKeys);
    
    if (columnPositions.length < 2) return [];
    
    // Build table
    final tableData = <List<String>>[];
    
    for (final rowKey in sortedRowKeys) {
      final elements = rowMap[rowKey]!;
      elements.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      
      final row = List<String>.filled(columnPositions.length, '');
      
      for (final element in elements) {
        final colIndex = _findColumnIndex(element.boundingBox.left, columnPositions);
        if (colIndex >= 0 && colIndex < row.length) {
          row[colIndex] += '${element.text} ';
        }
      }
      
      tableData.add(row.map((s) => s.trim()).toList());
    }
    
    return tableData;
  }
  
  static List<double> _detectColumnPositions(
    Map<int, List<TextElement>> rowMap,
    List<int> sortedRowKeys,
  ) {
    final columnStarts = <double>{};
    
    // Analyze first 5 rows to find column positions
    for (int i = 0; i < sortedRowKeys.length && i < 5; i++) {
      final elements = rowMap[sortedRowKeys[i]]!;
      
      for (final element in elements) {
        columnStarts.add((element.boundingBox.left / 20).round() * 20.0);
      }
    }
    
    final sorted = columnStarts.toList()..sort();
    return sorted;
  }
  
  static int _findColumnIndex(double position, List<double> columnPositions) {
    for (int i = 0; i < columnPositions.length; i++) {
      if ((position - columnPositions[i]).abs() < 30) {
        return i;
      }
    }
    return 0;
  }
}

// Simple OCR to Excel converter
class SimplePDFToExcelOCR {
  /// Simple conversion for quick testing
  static Future<String> convert({
    required File pdfFile,
    required Function(double progress, String message) onProgress,
  }) async {
    final textRecognizer = TextRecognizer();
    
    try {
      onProgress(0.05, 'Loading...');
      final bytes = await pdfFile.readAsBytes();
      
      final doc = sf_pdf.PdfDocument(inputBytes: bytes);
      final pageCount = doc.pages.count;
      doc.dispose();
      
      onProgress(0.10, 'Creating Excel...');
      
      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'OCR Data';
      
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDir = Directory('${outputDir.path}/temp_$timestamp');
      await tempDir.create();
      
      int row = 1;
      int page = 0;
      
      await for (var rasterPage in Printing.raster(bytes, dpi: 300)) {
        page++;
        onProgress(0.10 + (0.80 * (page / pageCount)), 'Page $page...');
        
        final imgBytes = await rasterPage.toPng();
        final imgPath = '${tempDir.path}/p$page.png';
        await File(imgPath).writeAsBytes(imgBytes);
        
        final inputImage = InputImage.fromFilePath(imgPath);
        final result = await textRecognizer.processImage(inputImage);
        
        // Add page header
        sheet.getRangeByIndex(row, 1).setText('Page $page');
        sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
        row++;
        
        // Add text
        if (result.text.isNotEmpty) {
          final lines = result.text.split('\n');
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              sheet.getRangeByIndex(row, 1).setText(line.trim());
              row++;
            }
          }
        }
        
        row++; // Space
        await File(imgPath).delete();
      }
      
      // Auto-fit
      sheet.autoFitColumn(1);
      
      onProgress(0.92, 'Saving...');
      
      final outputPath = '${outputDir.path}/simple_ocr_$timestamp.xlsx';
      await File(outputPath).writeAsBytes(workbook.saveAsStream());
      
      workbook.dispose();
      await tempDir.delete(recursive: true);
      
      onProgress(1.0, 'Done!');
      return outputPath;
      
    } finally {
      textRecognizer.close();
    }
  }
}