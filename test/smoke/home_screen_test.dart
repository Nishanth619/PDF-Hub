import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovepdf_flutter/features/home/home_screen.dart';
import 'package:ilovepdf_flutter/models/pdf_tool.dart';
import 'package:ilovepdf_flutter/services/history_service.dart';
import 'package:ilovepdf_flutter/services/favorites_service.dart';
import 'package:ilovepdf_flutter/models/app_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke tests for the Home Screen (Dashboard)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Home Screen Smoke Tests', () {
    Widget createTestableHomeScreen() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<HistoryService>(create: (_) => HistoryService()),
          ChangeNotifierProvider<FavoritesService>(create: (_) => FavoritesService()),
          ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      );
    }

    setUp(() async {
      // Initialize SharedPreferences with mock values
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Home screen loads without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableHomeScreen());
      await tester.pump();
      
      // Should find some widget - screen loaded
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Home screen displays app title', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableHomeScreen());
      await tester.pump();
      
      // Should show PDF Hub in app bar
      expect(find.text('PDF Hub'), findsWidgets);
    });

    testWidgets('Home screen has settings icon', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableHomeScreen());
      await tester.pump();
      
      // Should have settings icon (uses settings_rounded in app)
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });

    testWidgets('Home screen has history icon', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableHomeScreen());
      await tester.pump();
      
      // Should have history icon (uses history_rounded in app)
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('PDF tools list has correct count', (WidgetTester tester) async {
      // Verify that the number of tools matches expected
      expect(pdfTools.length, 11);
    });

    testWidgets('Home screen responds to scroll', (WidgetTester tester) async {
      await tester.pumpWidget(createTestableHomeScreen());
      await tester.pump();
      
      // Find a scrollable widget
      final scrollable = find.byType(Scrollable);
      expect(scrollable, findsWidgets);
    });
  });
}
