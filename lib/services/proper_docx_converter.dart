import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

typedef ProgressCallback = void Function(double progress, String message);

/// Creates a proper DOCX file from PDF text content
class ProperDocxConverter {
  /// Converts PDF to a real DOCX file
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
      
      onProgress(0.15, 'Extracting text...');
      final textExtractor = sf_pdf.PdfTextExtractor(pdfDocument);
      
      // Extract text from all pages
      List<String> pageTexts = [];
      for (int i = 0; i < pageCount; i++) {
        onProgress(0.15 + (0.40 * (i / pageCount)), 'Reading page ${i + 1} of $pageCount...');
        final text = textExtractor.extractText(startPageIndex: i, endPageIndex: i);
        if (text.isNotEmpty) {
          pageTexts.add(text);
        }
      }
      
      onProgress(0.60, 'Creating Word document...');
      
      // Build DOCX structure
      final docxBytes = _buildDocx(pageTexts, pageCount);
      
      onProgress(0.90, 'Saving document...');
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${outputDir.path}/converted_$timestamp.docx';
      
      await File(outputPath).writeAsBytes(docxBytes);
      
      onProgress(1.0, 'Done!');
      return outputPath;
      
    } catch (e) {
      throw Exception('Word conversion failed: $e');
    } finally {
      pdfDocument?.dispose();
    }
  }
  
  /// Build a proper DOCX file (DOCX is a ZIP of XML files)
  static Uint8List _buildDocx(List<String> pageTexts, int pageCount) {
    final archive = Archive();
    
    // [Content_Types].xml
    archive.addFile(ArchiveFile(
      '[Content_Types].xml',
      _contentTypesXml.length,
      Uint8List.fromList(_contentTypesXml.codeUnits),
    ));
    
    // _rels/.rels
    archive.addFile(ArchiveFile(
      '_rels/.rels',
      _relsXml.length,
      Uint8List.fromList(_relsXml.codeUnits),
    ));
    
    // word/_rels/document.xml.rels
    archive.addFile(ArchiveFile(
      'word/_rels/document.xml.rels',
      _documentRelsXml.length,
      Uint8List.fromList(_documentRelsXml.codeUnits),
    ));
    
    // word/styles.xml
    archive.addFile(ArchiveFile(
      'word/styles.xml',
      _stylesXml.length,
      Uint8List.fromList(_stylesXml.codeUnits),
    ));
    
    // word/document.xml - main content
    final documentXml = _buildDocumentXml(pageTexts, pageCount);
    archive.addFile(ArchiveFile(
      'word/document.xml',
      documentXml.length,
      Uint8List.fromList(documentXml.codeUnits),
    ));
    
    // Encode as ZIP
    final zipEncoder = ZipEncoder();
    return Uint8List.fromList(zipEncoder.encode(archive)!);
  }
  
  static String _buildDocumentXml(List<String> pageTexts, int pageCount) {
    final paragraphs = StringBuffer();
    
    // Title
    paragraphs.write('''
      <w:p>
        <w:pPr><w:pStyle w:val="Title"/></w:pPr>
        <w:r><w:t>Converted Document</w:t></w:r>
      </w:p>
      <w:p>
        <w:pPr><w:pStyle w:val="Subtitle"/></w:pPr>
        <w:r><w:t>Extracted from PDF ($pageCount pages)</w:t></w:r>
      </w:p>
    ''');
    
    // Add content from each page
    for (int i = 0; i < pageTexts.length; i++) {
      // Page header
      paragraphs.write('''
        <w:p>
          <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
          <w:r><w:t>Page ${i + 1}</w:t></w:r>
        </w:p>
      ''');
      
      // Split text into paragraphs
      final lines = pageTexts[i].split('\n');
      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          // Escape XML special characters
          final escapedLine = _escapeXml(line.trim());
          paragraphs.write('''
            <w:p>
              <w:r><w:t xml:space="preserve">$escapedLine</w:t></w:r>
            </w:p>
          ''');
        }
      }
      
      // Page break between pages (except last)
      if (i < pageTexts.length - 1) {
        paragraphs.write('''
          <w:p>
            <w:r><w:br w:type="page"/></w:r>
          </w:p>
        ''');
      }
    }
    
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    ${paragraphs.toString()}
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>''';
  }
  
  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
  
  static const String _contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
  
  static const String _relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
  
  static const String _documentRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
  
  static const String _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:sz w:val="22"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr>
      <w:b/>
      <w:sz w:val="56"/>
      <w:color w:val="2E74B5"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Subtitle">
    <w:name w:val="Subtitle"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr>
      <w:i/>
      <w:sz w:val="24"/>
      <w:color w:val="5A5A5A"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="Heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr>
      <w:b/>
      <w:sz w:val="32"/>
      <w:color w:val="2E74B5"/>
    </w:rPr>
    <w:pPr>
      <w:spacing w:before="240" w:after="120"/>
    </w:pPr>
  </w:style>
</w:styles>''';
}
