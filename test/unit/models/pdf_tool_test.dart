import 'package:flutter_test/flutter_test.dart';
import 'package:ilovepdf_flutter/models/pdf_tool.dart';

void main() {
  group('PdfTool', () {
    group('PdfTool constructor', () {
      test('creates a PdfTool with all required fields', () {
        final tool = PdfTool(
          id: 'test-tool',
          title: 'Test Tool',
          description: 'A test tool for testing',
          icon: 'assets/icons/test.svg',
          gradientColors: ['#FF0000', '#00FF00'],
          route: '/test',
        );

        expect(tool.id, 'test-tool');
        expect(tool.title, 'Test Tool');
        expect(tool.description, 'A test tool for testing');
        expect(tool.icon, 'assets/icons/test.svg');
        expect(tool.gradientColors, ['#FF0000', '#00FF00']);
        expect(tool.route, '/test');
        expect(tool.category, 'all'); // default value
        expect(tool.isNew, false); // default value
      });

      test('creates a PdfTool with optional fields', () {
        final tool = PdfTool(
          id: 'new-tool',
          title: 'New Feature',
          description: 'A brand new feature',
          icon: 'assets/icons/new.svg',
          gradientColors: ['#FF0000', '#0000FF'],
          route: '/new',
          category: 'convert',
          isNew: true,
        );

        expect(tool.category, 'convert');
        expect(tool.isNew, true);
      });
    });

    group('pdfTools list', () {
      test('contains exactly 11 tools', () {
        expect(pdfTools.length, 11);
      });

      test('all tools have unique IDs', () {
        final ids = pdfTools.map((t) => t.id).toSet();
        expect(ids.length, pdfTools.length);
      });

      test('all tools have unique routes', () {
        final routes = pdfTools.map((t) => t.route).toSet();
        expect(routes.length, pdfTools.length);
      });

      test('all tools have non-empty titles', () {
        for (final tool in pdfTools) {
          expect(tool.title.isNotEmpty, true, reason: 'Tool ${tool.id} has empty title');
        }
      });

      test('all tools have non-empty descriptions', () {
        for (final tool in pdfTools) {
          expect(tool.description.isNotEmpty, true, reason: 'Tool ${tool.id} has empty description');
        }
      });

      test('all tools have valid icon paths', () {
        for (final tool in pdfTools) {
          expect(tool.icon.startsWith('assets/icons/'), true,
              reason: 'Tool ${tool.id} has invalid icon path: ${tool.icon}');
          expect(tool.icon.endsWith('.svg'), true,
              reason: 'Tool ${tool.id} icon is not SVG: ${tool.icon}');
        }
      });

      test('all tools have valid routes starting with /', () {
        for (final tool in pdfTools) {
          expect(tool.route.startsWith('/'), true,
              reason: 'Tool ${tool.id} has invalid route: ${tool.route}');
        }
      });

      test('all tools have exactly 2 gradient colors', () {
        for (final tool in pdfTools) {
          expect(tool.gradientColors.length, 2,
              reason: 'Tool ${tool.id} has ${tool.gradientColors.length} gradient colors');
        }
      });

      test('all gradient colors are valid hex colors', () {
        final hexColorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
        for (final tool in pdfTools) {
          for (final color in tool.gradientColors) {
            expect(hexColorPattern.hasMatch(color), true,
                reason: 'Tool ${tool.id} has invalid color: $color');
          }
        }
      });
    });

    group('specific tools verification', () {
      test('Convert tool is configured correctly', () {
        final convert = pdfTools.firstWhere((t) => t.id == 'convert');
        expect(convert.title, 'Convert');
        expect(convert.route, '/convert');
        expect(convert.category, 'convert');
      });

      test('Merge tool is configured correctly', () {
        final merge = pdfTools.firstWhere((t) => t.id == 'merge');
        expect(merge.title, 'Merge PDF');
        expect(merge.route, '/merge');
        expect(merge.category, 'organize');
      });

      test('Split tool is configured correctly', () {
        final split = pdfTools.firstWhere((t) => t.id == 'split');
        expect(split.title, 'Split PDF');
        expect(split.route, '/split');
        expect(split.category, 'organize');
      });

      test('Compress tool is configured correctly', () {
        final compress = pdfTools.firstWhere((t) => t.id == 'compress');
        expect(compress.title, 'Compress');
        expect(compress.route, '/compress');
        expect(compress.category, 'organize');
      });

      test('Rotate tool is configured correctly', () {
        final rotate = pdfTools.firstWhere((t) => t.id == 'rotate');
        expect(rotate.title, 'Rotate');
        expect(rotate.route, '/rotate');
        expect(rotate.category, 'edit');
      });

      test('Watermark tool is configured correctly', () {
        final watermark = pdfTools.firstWhere((t) => t.id == 'watermark');
        expect(watermark.title, 'Watermark');
        expect(watermark.route, '/watermark');
        expect(watermark.category, 'edit');
      });

      test('OCR tool is marked as new', () {
        final ocr = pdfTools.firstWhere((t) => t.id == 'ocr');
        expect(ocr.isNew, true);
        expect(ocr.title, 'OCR');
        expect(ocr.route, '/ocr');
        expect(ocr.category, 'convert');
      });

      test('Form Filler tool is configured correctly', () {
        final formFiller = pdfTools.firstWhere((t) => t.id == 'formfiller');
        expect(formFiller.title, 'Form Filler');
        expect(formFiller.route, '/formfiller');
        expect(formFiller.category, 'forms');
      });

      test('Image to PDF tool is configured correctly', () {
        final imageToPdf = pdfTools.firstWhere((t) => t.id == 'imagetopdf');
        expect(imageToPdf.title, 'Image to PDF');
        expect(imageToPdf.route, '/imagetopdf');
        expect(imageToPdf.category, 'convert');
      });

      test('Annotate tool is configured correctly', () {
        final annotate = pdfTools.firstWhere((t) => t.id == 'annotate');
        expect(annotate.title, 'Annotate');
        expect(annotate.route, '/annotate');
        expect(annotate.category, 'edit');
      });

      test('Page Numbers tool is configured correctly', () {
        final pageNumber = pdfTools.firstWhere((t) => t.id == 'pagenumber');
        expect(pageNumber.title, 'Page Numbers');
        expect(pageNumber.route, '/pagenumber');
        expect(pageNumber.category, 'edit');
      });
    });

    group('category distribution', () {
      test('has tools in edit category', () {
        final editTools = pdfTools.where((t) => t.category == 'edit');
        expect(editTools.isNotEmpty, true);
      });

      test('has tools in convert category', () {
        final convertTools = pdfTools.where((t) => t.category == 'convert');
        expect(convertTools.isNotEmpty, true);
      });

      test('has tools in organize category', () {
        final organizeTools = pdfTools.where((t) => t.category == 'organize');
        expect(organizeTools.isNotEmpty, true);
      });

      test('has tools in forms category', () {
        final formsTools = pdfTools.where((t) => t.category == 'forms');
        expect(formsTools.isNotEmpty, true);
      });
    });
  });
}
