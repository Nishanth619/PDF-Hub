import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ilovepdf_flutter/services/ad_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  AdSize? _adSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load ad with adaptive size based on screen width
    if (AdService().shouldShowAds && _bannerAd == null) {
      _loadAdaptiveAd();
    }
  }

  Future<void> _loadAdaptiveAd() async {
    // Don't load if premium or max retries reached
    if (!AdService().shouldShowAds) return;
    if (_retryCount >= _maxRetries) {
      debugPrint('Banner ad: Max retries reached');
      return;
    }

    // Get the adaptive ad size based on screen width
    final width = MediaQuery.of(context).size.width.truncate();
    
    // For tablets (width > 600), use leaderboard; otherwise use banner
    if (width > 600) {
      _adSize = AdSize.leaderboard; // 728x90 - fits well on tablets
    } else {
      _adSize = AdSize.banner; // 320x50 - standard for phones
    }
    
    debugPrint('Loading adaptive banner ad (width: $width, size: ${_adSize!.width}x${_adSize!.height})...');
    
    _bannerAd?.dispose();
    
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: _adSize!,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✓ Banner ad loaded (${_adSize!.width}x${_adSize!.height})');
          _retryCount = 0;
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed: ${error.message} (code: ${error.code})');
          ad.dispose();
          _bannerAd = null;
          if (mounted) {
            setState(() => _isLoaded = false);
          }
          
          // Retry with shorter backoff
          _retryCount++;
          final delay = Duration(seconds: 3 * _retryCount);
          debugPrint('Banner: Retrying in ${delay.inSeconds}s (attempt $_retryCount/$_maxRetries)');
          Future.delayed(delay, () {
            if (mounted) _loadAdaptiveAd();
          });
        },
        onAdOpened: (ad) => debugPrint('Banner ad opened'),
        onAdClosed: (ad) {
          debugPrint('Banner ad closed');
          if (mounted) _loadAdaptiveAd();
        },
        onAdImpression: (ad) => debugPrint('Banner impression'),
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if premium
    if (!AdService().shouldShowAds) {
      return const SizedBox.shrink();
    }
    
    if (!_isLoaded || _bannerAd == null || _adSize == null) {
      // Show loading placeholder
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Use full width container with banner centered
    return Container(
      width: double.infinity,
      height: _adSize!.height.toDouble(),
      alignment: Alignment.center,
      child: SizedBox(
        width: _adSize!.width.toDouble(),
        height: _adSize!.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}

/// A container for the banner ad at the bottom of screens
class BottomBannerAd extends StatelessWidget {
  const BottomBannerAd({super.key});

  @override
  Widget build(BuildContext context) {
    // Don't show if premium
    if (!AdService().shouldShowAds) {
      return const SizedBox.shrink();
    }
    
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const SafeArea(
        top: false,
        child: BannerAdWidget(),
      ),
    );
  }
}
