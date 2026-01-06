import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;
import 'dart:convert';

typedef ProgressCallback = void Function(double progress, String message);

/// Creates a proper PPTX file from PDF pages
class ProperPptxConverter {
  /// Converts PDF to a real PPTX file with embedded images
  static Future<String> convert({
    required File pdfFile,
    required ProgressCallback onProgress,
    int dpi = 150,
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
      
      // Convert pages to images
      List<Uint8List> slideImages = [];
      int pageNum = 0;
      
      await for (var page in Printing.raster(
        bytes,
        pages: List.generate(pageCount, (index) => index),
        dpi: dpi.toDouble(),
      )) {
        pageNum++;
        onProgress(
          0.10 + (0.60 * ((pageNum - 1) / pageCount)),
          'Creating slide $pageNum of $pageCount...',
        );
        
        final imageBytes = await page.toPng();
        slideImages.add(imageBytes);
      }
      
      onProgress(0.75, 'Building PowerPoint file...');
      
      // Build proper PPTX
      final pptxBytes = _buildPptx(slideImages);
      
      onProgress(0.95, 'Saving presentation...');
      final outputDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${outputDir.path}/presentation_$timestamp.pptx';
      
      await File(outputPath).writeAsBytes(pptxBytes);
      
      onProgress(1.0, 'Done!');
      return outputPath;
      
    } catch (e) {
      throw Exception('PowerPoint conversion failed: $e');
    }
  }
  
  /// Build a proper PPTX file (PPTX is a ZIP of XML files)
  static Uint8List _buildPptx(List<Uint8List> slideImages) {
    final archive = Archive();
    
    // [Content_Types].xml
    final contentTypes = _buildContentTypes(slideImages.length);
    archive.addFile(ArchiveFile(
      '[Content_Types].xml',
      contentTypes.length,
      Uint8List.fromList(contentTypes.codeUnits),
    ));
    
    // _rels/.rels
    archive.addFile(ArchiveFile(
      '_rels/.rels',
      _relsXml.length,
      Uint8List.fromList(_relsXml.codeUnits),
    ));
    
    // ppt/presentation.xml
    final presentationXml = _buildPresentationXml(slideImages.length);
    archive.addFile(ArchiveFile(
      'ppt/presentation.xml',
      presentationXml.length,
      Uint8List.fromList(presentationXml.codeUnits),
    ));
    
    // ppt/_rels/presentation.xml.rels
    final presentationRels = _buildPresentationRels(slideImages.length);
    archive.addFile(ArchiveFile(
      'ppt/_rels/presentation.xml.rels',
      presentationRels.length,
      Uint8List.fromList(presentationRels.codeUnits),
    ));
    
    // Add each slide
    for (int i = 0; i < slideImages.length; i++) {
      final slideNum = i + 1;
      
      // ppt/slides/slideX.xml
      final slideXml = _buildSlideXml(slideNum);
      archive.addFile(ArchiveFile(
        'ppt/slides/slide$slideNum.xml',
        slideXml.length,
        Uint8List.fromList(slideXml.codeUnits),
      ));
      
      // ppt/slides/_rels/slideX.xml.rels
      final slideRels = _buildSlideRels(slideNum);
      archive.addFile(ArchiveFile(
        'ppt/slides/_rels/slide$slideNum.xml.rels',
        slideRels.length,
        Uint8List.fromList(slideRels.codeUnits),
      ));
      
      // ppt/media/imageX.png
      archive.addFile(ArchiveFile(
        'ppt/media/image$slideNum.png',
        slideImages[i].length,
        slideImages[i],
      ));
    }
    
    // ppt/slideLayouts/slideLayout1.xml
    archive.addFile(ArchiveFile(
      'ppt/slideLayouts/slideLayout1.xml',
      _slideLayoutXml.length,
      Uint8List.fromList(_slideLayoutXml.codeUnits),
    ));
    
    // ppt/slideLayouts/_rels/slideLayout1.xml.rels
    archive.addFile(ArchiveFile(
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
      _slideLayoutRels.length,
      Uint8List.fromList(_slideLayoutRels.codeUnits),
    ));
    
    // ppt/slideMasters/slideMaster1.xml
    archive.addFile(ArchiveFile(
      'ppt/slideMasters/slideMaster1.xml',
      _slideMasterXml.length,
      Uint8List.fromList(_slideMasterXml.codeUnits),
    ));
    
    // ppt/slideMasters/_rels/slideMaster1.xml.rels
    archive.addFile(ArchiveFile(
      'ppt/slideMasters/_rels/slideMaster1.xml.rels',
      _slideMasterRels.length,
      Uint8List.fromList(_slideMasterRels.codeUnits),
    ));
    
    // ppt/theme/theme1.xml
    archive.addFile(ArchiveFile(
      'ppt/theme/theme1.xml',
      _themeXml.length,
      Uint8List.fromList(_themeXml.codeUnits),
    ));
    
    // Encode as ZIP
    final zipEncoder = ZipEncoder();
    return Uint8List.fromList(zipEncoder.encode(archive)!);
  }
  
  static String _buildContentTypes(int slideCount) {
    final slides = StringBuffer();
    for (int i = 1; i <= slideCount; i++) {
      slides.write('<Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
    }
    
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
  <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
  <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
  ${slides.toString()}
</Types>''';
  }
  
  static String _buildPresentationXml(int slideCount) {
    final slideIds = StringBuffer();
    for (int i = 1; i <= slideCount; i++) {
      slideIds.write('<p:sldId id="${255 + i}" r:id="rId${i + 1}"/>');
    }
    
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" saveSubsetFonts="1">
  <p:sldMasterIdLst>
    <p:sldMasterId id="2147483648" r:id="rId1"/>
  </p:sldMasterIdLst>
  <p:sldIdLst>
    ${slideIds.toString()}
  </p:sldIdLst>
  <p:sldSz cx="9144000" cy="6858000" type="screen4x3"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>''';
  }
  
  static String _buildPresentationRels(int slideCount) {
    final relationships = StringBuffer();
    relationships.write('<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>');
    
    for (int i = 1; i <= slideCount; i++) {
      relationships.write('<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>');
    }
    
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  ${relationships.toString()}
</Relationships>''';
  }
  
  static String _buildSlideXml(int slideNum) {
    // Full slide image covering the entire slide (9144000 x 6858000 EMUs)
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id="1" name=""/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr>
        <a:xfrm>
          <a:off x="0" y="0"/>
          <a:ext cx="0" cy="0"/>
          <a:chOff x="0" y="0"/>
          <a:chExt cx="0" cy="0"/>
        </a:xfrm>
      </p:grpSpPr>
      <p:pic>
        <p:nvPicPr>
          <p:cNvPr id="2" name="Slide Image $slideNum"/>
          <p:cNvPicPr>
            <a:picLocks noChangeAspect="1"/>
          </p:cNvPicPr>
          <p:nvPr/>
        </p:nvPicPr>
        <p:blipFill>
          <a:blip r:embed="rId1"/>
          <a:stretch>
            <a:fillRect/>
          </a:stretch>
        </p:blipFill>
        <p:spPr>
          <a:xfrm>
            <a:off x="0" y="0"/>
            <a:ext cx="9144000" cy="6858000"/>
          </a:xfrm>
          <a:prstGeom prst="rect">
            <a:avLst/>
          </a:prstGeom>
        </p:spPr>
      </p:pic>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr>
    <a:masterClrMapping/>
  </p:clrMapOvr>
</p:sld>''';
  }
  
  static String _buildSlideRels(int slideNum) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image$slideNum.png"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>''';
  }
  
  static const String _relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';
  
  static const String _slideLayoutXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" type="blank">
  <p:cSld name="Blank">
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id="1" name=""/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr/>
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr>
    <a:masterClrMapping/>
  </p:clrMapOvr>
</p:sldLayout>''';
  
  static const String _slideLayoutRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''';
  
  static const String _slideMasterXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld>
    <p:bg>
      <p:bgRef idx="1001">
        <a:schemeClr val="bg1"/>
      </p:bgRef>
    </p:bg>
    <p:spTree>
      <p:nvGrpSpPr>
        <p:cNvPr id="1" name=""/>
        <p:cNvGrpSpPr/>
        <p:nvPr/>
      </p:nvGrpSpPr>
      <p:grpSpPr/>
    </p:spTree>
  </p:cSld>
  <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
  <p:sldLayoutIdLst>
    <p:sldLayoutId id="2147483649" r:id="rId1"/>
  </p:sldLayoutIdLst>
</p:sldMaster>''';
  
  static const String _slideMasterRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>''';
  
  static const String _themeXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
  <a:themeElements>
    <a:clrScheme name="Office">
      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
      <a:dk2><a:srgbClr val="44546A"/></a:dk2>
      <a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>
      <a:accent1><a:srgbClr val="4472C4"/></a:accent1>
      <a:accent2><a:srgbClr val="ED7D31"/></a:accent2>
      <a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>
      <a:accent4><a:srgbClr val="FFC000"/></a:accent4>
      <a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>
      <a:accent6><a:srgbClr val="70AD47"/></a:accent6>
      <a:hlink><a:srgbClr val="0563C1"/></a:hlink>
      <a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="Office">
      <a:majorFont><a:latin typeface="Calibri Light"/></a:majorFont>
      <a:minorFont><a:latin typeface="Calibri"/></a:minorFont>
    </a:fontScheme>
    <a:fmtScheme name="Office">
      <a:fillStyleLst>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
      </a:fillStyleLst>
      <a:lnStyleLst>
        <a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
        <a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
        <a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
      </a:lnStyleLst>
      <a:effectStyleLst>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
        <a:effectStyle><a:effectLst/></a:effectStyle>
      </a:effectStyleLst>
      <a:bgFillStyleLst>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
      </a:bgFillStyleLst>
    </a:fmtScheme>
  </a:themeElements>
</a:theme>''';
}
