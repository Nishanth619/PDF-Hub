import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovepdf_flutter/features/home/home_screen.dart';
import 'package:ilovepdf_flutter/features/history/history_screen.dart';
import 'package:ilovepdf_flutter/features/convert/convert_screen.dart';
import 'package:ilovepdf_flutter/features/merge/merge_screen.dart';
import 'package:ilovepdf_flutter/features/split/split_screen.dart';
import 'package:ilovepdf_flutter/features/compress/compress_screen.dart';
import 'package:ilovepdf_flutter/features/rotate/rotate_screen.dart';
import 'package:ilovepdf_flutter/features/watermark/watermark_screen.dart';
import 'package:ilovepdf_flutter/features/page_number/page_number_screen.dart';
import 'package:ilovepdf_flutter/features/ocr/ocr_screen.dart';
import 'package:ilovepdf_flutter/features/image_to_pdf/image_to_pdf_screen.dart';
import 'package:ilovepdf_flutter/features/form_filler/form_filler_screen.dart';
import 'package:ilovepdf_flutter/features/annotate/annotate_screen.dart';
import 'package:ilovepdf_flutter/services/history_service.dart';
import 'package:ilovepdf_flutter/services/favorites_service.dart';
import 'package:ilovepdf_flutter/services/api_service.dart';
import 'package:ilovepdf_flutter/models/app_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke tests for navigation - verifies all screens can load
/// Note: Settings and Premium screens are excluded as they require
/// PremiumService which needs platform-specific initialization.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Navigation Smoke Tests', () {
    Widget createTestableWidget(Widget screen) {
      return MultiProvider(
        providers: [
          Provider<ApiService>(create: (_) => ApiService()),
          ChangeNotifierProvider<HistoryService>(create: (_) => HistoryService()),
          ChangeNotifierProvider<FavoritesService>(create: (_) => FavoritesService()),
          ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()),
        ],
        child: MaterialApp(home: screen),
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    // Test each screen individually loads without crashing
    
    testWidgets('Home screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const HomeScreen()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('PDF Hub'), findsWidgets);
    });

    testWidgets('History screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const HistoryScreen()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('History'), findsWidgets);
    });

    testWidgets('Convert screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const ConvertScreen()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Merge screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const MergeScreen()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Split screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const SplitScreen()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Compress screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const CompressScreen()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Rotate screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const RotateScreen()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Watermark screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const AddWatermarkScreen()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Page Numbers screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const AddPageNumbersPage()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('OCR screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const OcrScreen()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Image to PDF screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const ImageToPdfScreen()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Form Filler screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const FormFillerScreen()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Annotate screen loads', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableWidget(const AnnotateScreen()));
      await tester.pump();
      
      expect(find.byType(Scaffold), findsOneWidget);
    });

    // Note: Settings and Premium screens are excluded from smoke tests
    // as they require PremiumService which depends on platform-specific
    // in-app purchase initialization.
  });
}
