import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';
import 'package:ilovepdf_flutter/widgets/banner_ad_widget.dart';

/// BaseScreen provides consistent navigation behavior across the app.
/// It includes a banner ad at the bottom of every screen.
/// It also tracks feature visits for interstitial ad triggering.
class BaseScreen extends StatefulWidget {
  final Widget child;
  final bool canPop;
  final String? popTarget;
  final bool showBannerAd;
  final bool trackFeatureVisit;

  const BaseScreen({
    super.key,
    required this.child,
    this.canPop = true,
    this.popTarget,
    this.showBannerAd = true, // Show banner ad by default
    this.trackFeatureVisit = true, // Track feature visits by default
  });

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  @override
  void initState() {
    super.initState();
    // Track feature visit for interstitial ad triggering
    if (widget.trackFeatureVisit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AdService().onFeatureVisit();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // We handle pop ourselves
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // Already handled
        
        final router = GoRouter.of(context);
        
        // If we have a specific target, navigate there
        if (widget.popTarget != null) {
          router.go(widget.popTarget!);
          return;
        }
        
        // Try to go back in navigation stack
        if (router.canPop()) {
          router.pop();
          return;
        }
        
        // If nowhere to go back to, go to home screen
        router.go('/');
      },
      child: Column(
        children: [
          // Main content takes all available space
          Expanded(child: widget.child),
          // Banner ad at bottom of every screen
          if (widget.showBannerAd) const BottomBannerAd(),
        ],
      ),
    );
  }
}
