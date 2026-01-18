import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ilovepdf_flutter/services/premium_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  int _operationCount = 0;
  int _featureVisitCount = 0;
  static const int _featureVisitInterval = 3; // Show interstitial every 3 feature visits
  int _interstitialRetryCount = 0;
  static const int _maxRetries = 3;
  bool _isLoadingInterstitial = false;
  
  // Preloaded banner ads for faster display
  BannerAd? _preloadedBannerAd;
  bool _isBannerLoaded = false;
  
  // Reference to premium service (set during initialization)
  PremiumService? _premiumService;
  
  /// Set premium service reference for checking premium status
  void setPremiumService(PremiumService service) {
    _premiumService = service;
  }
  
  /// Check if user is premium (no ads)
  bool get _isPremium => _premiumService?.isPremium ?? false;
  
  /// Check if ads should be shown (public getter)
  bool get shouldShowAds => !_isPremium;
  
  /// Check if interstitial is ready
  bool get isInterstitialReady => _interstitialAd != null;
  
  /// Get preloaded banner ad
  BannerAd? get preloadedBannerAd => _isBannerLoaded ? _preloadedBannerAd : null;

  // Test Ad Unit IDs (Replace with your real IDs for production)
  static String get bannerAdUnitId {
    if (kDebugMode) {
      // Test IDs
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/2934735716';
      }
    }
    // Production IDs - Use environment variables for security
    if (Platform.isAndroid) {
      return const String.fromEnvironment('BANNER_AD_ID', defaultValue: 'ca-app-pub-3940256099942544/6300978111');
    } else if (Platform.isIOS) {
      return const String.fromEnvironment('BANNER_AD_ID_IOS', defaultValue: 'ca-app-pub-3940256099942544/2934735716');
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      // Test IDs
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/1033173712';
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/4411468910';
      }
    }
    // Production IDs - Use environment variables for security
    if (Platform.isAndroid) {
      return const String.fromEnvironment('INTERSTITIAL_AD_ID', defaultValue: 'ca-app-pub-3940256099942544/1033173712');
    } else if (Platform.isIOS) {
      return const String.fromEnvironment('INTERSTITIAL_AD_ID_IOS', defaultValue: 'ca-app-pub-3940256099942544/4411468910');
    }
    return '';
  }

  /// Initialize Mobile Ads SDK
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('AdMob initialized successfully');
      
      // Pre-load ads immediately if not premium
      if (!_isPremium) {
        // Start loading both ad types immediately
        _loadInterstitialAd();
        _preloadBannerAd();
      }
    } catch (e) {
      debugPrint('Failed to initialize AdMob: $e');
    }
  }

  /// Preload a banner ad for faster display
  void _preloadBannerAd() {
    if (_isPremium || _preloadedBannerAd != null) return;
    
    debugPrint('Preloading banner ad...');
    _preloadedBannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Preloaded banner ad ready');
          _isBannerLoaded = true;
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Preload banner failed: ${error.message}');
          ad.dispose();
          _preloadedBannerAd = null;
          _isBannerLoaded = false;
          // Retry after 5 seconds
          Future.delayed(const Duration(seconds: 5), _preloadBannerAd);
        },
      ),
    )..load();
  }

  /// Load Interstitial Ad with retry logic
  void _loadInterstitialAd() {
    // Skip if premium user
    if (_isPremium) return;
    
    // Skip if already loading or loaded
    if (_isLoadingInterstitial || _interstitialAd != null) {
      debugPrint('Interstitial: Already loading or loaded');
      return;
    }
    
    // Skip if max retries reached
    if (_interstitialRetryCount >= _maxRetries) {
      debugPrint('Interstitial ad: Max retries reached, will try on next operation');
      return;
    }
    
    _isLoadingInterstitial = true;
    debugPrint('Loading interstitial ad...');
    
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✓ Interstitial ad loaded and READY');
          _isLoadingInterstitial = false;
          _interstitialRetryCount = 0; // Reset on success
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              debugPrint('✓ Interstitial ad SHOWING');
            },
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('Interstitial ad dismissed');
              ad.dispose();
              _interstitialAd = null;
              // Load next ad immediately
              Future.delayed(const Duration(milliseconds: 500), _loadInterstitialAd);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Interstitial ad failed to show: ${error.message}');
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
            onAdImpression: (ad) {
              debugPrint('Interstitial ad impression recorded');
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: ${error.message} (code: ${error.code})');
          _isLoadingInterstitial = false;
          _interstitialAd = null;
          
          // Retry with exponential backoff
          _interstitialRetryCount++;
          final delay = Duration(seconds: 5 * _interstitialRetryCount);
          debugPrint('Interstitial: Retrying in ${delay.inSeconds}s (attempt $_interstitialRetryCount/$_maxRetries)');
          Future.delayed(delay, _loadInterstitialAd);
        },
      ),
    );
  }

  /// Show Interstitial Ad after PDF operations (shows after EVERY operation)
  void showInterstitialAfterOperation() {
    // Skip if premium user
    if (_isPremium) return;
    
    _operationCount++;
    debugPrint('Operation completed: $_operationCount (showing interstitial)');
    
    // Show interstitial after every completed operation
    // Also reset feature visit counter since user completed a task
    _featureVisitCount = 0;
    showInterstitialAd();
  }
  
  /// Track feature screen visits (shows interstitial after 3 visits)
  void onFeatureVisit() {
    // Skip if premium user
    if (_isPremium) return;
    
    _featureVisitCount++;
    debugPrint('Feature visit count: $_featureVisitCount/$_featureVisitInterval (interstitial ready: ${_interstitialAd != null})');
    
    if (_featureVisitCount >= _featureVisitInterval) {
      _featureVisitCount = 0;
      showInterstitialAd();
    } else if (_interstitialAd == null) {
      // Preload if not ready
      _interstitialRetryCount = 0;
      _loadInterstitialAd();
    }
  }

  /// Show Interstitial Ad
  void showInterstitialAd() {
    // Skip if premium user
    if (_isPremium) return;
    
    if (_interstitialAd != null) {
      debugPrint('>>> SHOWING interstitial ad NOW <<<');
      _interstitialAd!.show();
    } else {
      debugPrint('Interstitial not ready - loading now');
      _interstitialRetryCount = 0; // Reset retry count
      _loadInterstitialAd();
    }
  }
  
  /// Force reload ads (call when returning to app or on error)
  void forceReloadAds() {
    if (_isPremium) return;
    
    debugPrint('Force reloading all ads...');
    _interstitialRetryCount = 0;
    _loadInterstitialAd();
    if (!_isBannerLoaded) {
      _preloadBannerAd();
    }
  }
  
  /// Reload ads (call when premium status changes)
  void reloadAdsIfNeeded() {
    if (!_isPremium && _interstitialAd == null) {
      _interstitialRetryCount = 0;
      _loadInterstitialAd();
    }
  }
  
  /// Clear all ads (call when user becomes premium)
  void clearAds() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _preloadedBannerAd?.dispose();
    _preloadedBannerAd = null;
    _isBannerLoaded = false;
  }

  /// Dispose ads
  void dispose() {
    _interstitialAd?.dispose();
    _preloadedBannerAd?.dispose();
  }
}
