import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovepdf_flutter/services/api_service.dart';
import 'package:ilovepdf_flutter/services/history_service.dart';
import 'package:ilovepdf_flutter/services/favorites_service.dart';
import 'package:ilovepdf_flutter/models/app_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App core services initialize successfully', (WidgetTester tester) async {
    // Test that core services can be created without errors
    final apiService = ApiService();
    expect(apiService, isNotNull);
    
    final historyService = HistoryService();
    expect(historyService, isNotNull);
    
    final favoritesService = FavoritesService();
    expect(favoritesService, isNotNull);
    
    final appSettings = AppSettings();
    expect(appSettings, isNotNull);
  });

  testWidgets('Providers can be created and accessed', (WidgetTester tester) async {
    bool providersWork = true;
    
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
              Provider.of<ApiService>(context, listen: false);
              Provider.of<HistoryService>(context, listen: false);
              Provider.of<FavoritesService>(context, listen: false);
              Provider.of<AppSettings>(context, listen: false);
            } catch (_) {
              providersWork = false;
            }
            return const SizedBox();
          },
        ),
      ),
    );

    await tester.pump();
    expect(providersWork, true);
  });
}
