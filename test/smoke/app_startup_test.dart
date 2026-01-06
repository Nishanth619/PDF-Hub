import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovepdf_flutter/services/api_service.dart';
import 'package:ilovepdf_flutter/services/history_service.dart';
import 'package:ilovepdf_flutter/services/favorites_service.dart';
import 'package:ilovepdf_flutter/models/app_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke tests to verify the app starts correctly
/// Note: These tests don't use MyApp directly to avoid PremiumService initialization
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('App Startup Smoke Tests', () {
    setUp(() async {
      // Initialize SharedPreferences with mock values
      SharedPreferences.setMockInitialValues({
        'terms_accepted': true, // Skip terms screen
      });
    });

    testWidgets('Core providers can be initialized', (WidgetTester tester) async {
      bool providersAccessible = true;
      
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>(create: (_) => ApiService()),
            ChangeNotifierProvider<HistoryService>(create: (_) => HistoryService()),
            ChangeNotifierProvider<FavoritesService>(create: (_) => FavoritesService()),
            ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()),
          ],
          child: Builder(
            builder: (context) {
              try {
                // Try to access all providers
                Provider.of<ApiService>(context, listen: false);
                Provider.of<HistoryService>(context, listen: false);
                Provider.of<FavoritesService>(context, listen: false);
                Provider.of<AppSettings>(context, listen: false);
              } catch (e) {
                providersAccessible = false;
              }
              return const MaterialApp(home: Scaffold());
            },
          ),
        ),
      );

      await tester.pump();
      expect(providersAccessible, true);
    });

    testWidgets('ApiService can be instantiated', (WidgetTester tester) async {
      final apiService = ApiService();
      expect(apiService, isNotNull);
    });

    testWidgets('HistoryService can be instantiated', (WidgetTester tester) async {
      final historyService = HistoryService();
      expect(historyService, isNotNull);
      expect(historyService.history, isEmpty);
    });

    testWidgets('FavoritesService can be instantiated', (WidgetTester tester) async {
      final favoritesService = FavoritesService();
      expect(favoritesService, isNotNull);
      expect(favoritesService.favorites, isEmpty);
    });

    testWidgets('AppSettings can be instantiated', (WidgetTester tester) async {
      final appSettings = AppSettings();
      expect(appSettings, isNotNull);
      // Default values
      expect(appSettings.themeMode, ThemeMode.system);
      expect(appSettings.language, 'en');
    });
  });
}
