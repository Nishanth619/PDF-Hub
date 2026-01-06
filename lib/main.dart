import 'package:flutter/material.dart';
import 'package:ilovepdf_flutter/core/theme.dart';
import 'package:ilovepdf_flutter/services/api_service.dart';
import 'package:ilovepdf_flutter/services/navigation_service.dart';
import 'package:ilovepdf_flutter/services/history_service.dart';
import 'package:ilovepdf_flutter/services/favorites_service.dart';
import 'package:ilovepdf_flutter/services/premium_service.dart';
import 'package:ilovepdf_flutter/models/app_settings.dart';
import 'package:ilovepdf_flutter/services/notification_service.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';
import 'package:provider/provider.dart';

void main() async {
  // Ensure widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create premium service first
  final premiumService = PremiumService();
  
  // Connect premium service to ad service
  AdService().setPremiumService(premiumService);
  
  // Start app immediately, initialize services in background
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider<HistoryService>(create: (_) => HistoryService()),
        ChangeNotifierProvider<FavoritesService>(create: (_) => FavoritesService()),
        ChangeNotifierProvider<PremiumService>.value(value: premiumService),
        ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()),
      ],
      child: const MyApp(),
    ),
  );
  
  // Initialize services in background (don't block app startup)
  _initializeServices();
}

Future<void> _initializeServices() async {
  // Initialize notification service
  await NotificationService().init();
  
  // Initialize AdMob
  await AdService().initialize();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, child) {
        // Schedule daily notification when settings change
        if (settings.enableNotifications) {
          NotificationService().scheduleDailyNotification(
            hour: 9,
            minute: 0,
          );
        } else {
          NotificationService().cancelDailyNotification();
        }
        
        return MaterialApp.router(
          title: 'PDF Hub',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          routerConfig: NavigationService.router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return ResponsiveScaling(child: child!);
          },
        );
      },
    );
  }
}

/// Widget that applies responsive scaling for tablets and large screens
class ResponsiveScaling extends StatelessWidget {
  final Widget child;
  
  const ResponsiveScaling({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    
    // Calculate text scale factor based on screen size
    // Phones: 1.0, Large phones: 1.1, Tablets: 1.25, Desktop: 1.35
    double textScale = 1.0;
    double iconScale = 1.0;
    
    if (screenWidth >= 1200) {
      // Desktop / Large tablet
      textScale = 1.35;
      iconScale = 1.4;
    } else if (screenWidth >= 900) {
      // Tablet
      textScale = 1.25;
      iconScale = 1.3;
    } else if (screenWidth >= 600) {
      // Large phone / Small tablet
      textScale = 1.1;
      iconScale = 1.15;
    }
    
    // Apply text scaling via MediaQuery
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: TextScaler.linear(
          mediaQuery.textScaler.scale(1.0) * textScale,
        ),
      ),
      child: IconTheme(
        data: IconThemeData(
          size: 24 * iconScale,
        ),
        child: child,
      ),
    );
  }
}