import 'package:go_router/go_router.dart';
import 'package:ilovepdf_flutter/features/annotate/annotate_screen.dart';
import 'package:ilovepdf_flutter/features/compress/compress_screen.dart';
import 'package:ilovepdf_flutter/features/convert/convert_screen.dart';
import 'package:ilovepdf_flutter/features/form_filler/form_filler_screen.dart';
import 'package:ilovepdf_flutter/features/history/history_screen.dart';
import 'package:ilovepdf_flutter/features/home/home_screen.dart';
import 'package:ilovepdf_flutter/features/image_to_pdf/image_to_pdf_screen.dart';
import 'package:ilovepdf_flutter/features/merge/merge_screen.dart';
import 'package:ilovepdf_flutter/features/ocr/ocr_screen.dart';
import 'package:ilovepdf_flutter/features/page_number/page_number_screen.dart';
import 'package:ilovepdf_flutter/features/premium/premium_screen.dart';
import 'package:ilovepdf_flutter/features/rotate/rotate_screen.dart';
import 'package:ilovepdf_flutter/features/settings/settings_screen.dart';
import 'package:ilovepdf_flutter/features/split/split_screen.dart';
import 'package:ilovepdf_flutter/features/watermark/watermark_screen.dart';
import 'package:ilovepdf_flutter/features/welcome/welcome_screen.dart';
import 'package:ilovepdf_flutter/screens/splash_screen.dart';
import 'package:ilovepdf_flutter/screens/terms_screen.dart';
import 'package:ilovepdf_flutter/screens/privacy_policy_screen.dart';

class NavigationService {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) {
          // Check if coming from settings - hide buttons if so
          final fromSettings = state.uri.queryParameters['from'] == 'settings';
          return TermsScreen(showButtons: !fromSettings);
        },
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/annotate',
        builder: (context, state) => const AnnotateScreen(),
      ),
      GoRoute(
        path: '/formfiller',
        builder: (context, state) => const FormFillerScreen(),
      ),
      GoRoute(
        path: '/convert',
        builder: (context, state) => const ConvertScreen(),
      ),
      GoRoute(path: '/merge', builder: (context, state) => const MergeScreen()),
      GoRoute(path: '/split', builder: (context, state) => const SplitScreen()),
      GoRoute(
        path: '/compress',
        builder: (context, state) => const CompressScreen(),
      ),
      GoRoute(
        path: '/rotate',
        builder: (context, state) => const RotateScreen(),
      ),
      GoRoute(
        path: '/watermark',
        builder: (context, state) => const AddWatermarkScreen(),
      ),
      GoRoute(
        path: '/pagenumber',
        builder: (context, state) => const AddPageNumbersPage(),
      ),
      GoRoute(path: '/ocr', builder: (context, state) => const OcrScreen()),
      GoRoute(
        path: '/imagetopdf',
        builder: (context, state) => const ImageToPdfScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/premium',
        builder: (context, state) => const PremiumScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
    ],
  );
}
