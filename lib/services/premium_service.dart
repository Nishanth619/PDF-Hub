import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage premium subscription and ad removal
class PremiumService with ChangeNotifier {
  static const String _premiumKey = 'is_premium_user';
  static const String productId = 'remove_ads_forever';
  
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  bool _isAvailable = false;
  bool _isPremium = false;
  bool _isLoading = false;
  ProductDetails? _product;
  String? _errorMessage;

  bool get isAvailable => _isAvailable;
  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  ProductDetails? get product => _product;
  String? get errorMessage => _errorMessage;
  
  /// Price string for display
  String get priceString => _product?.price ?? '₹499';

  PremiumService() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Load saved premium status first
    await _loadPremiumStatus();
    
    // Initialize in-app purchase
    _isAvailable = await _iap.isAvailable();
    
    if (_isAvailable) {
      // Listen to purchase updates
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (error) {
          debugPrint('Purchase stream error: $error');
        },
      );
      
      // Load product details
      await _loadProducts();
    }
    
    notifyListeners();
  }

  Future<void> _loadPremiumStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPremium = prefs.getBool(_premiumKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading premium status: $e');
    }
  }

  Future<void> _savePremiumStatus(bool isPremium) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_premiumKey, isPremium);
      _isPremium = isPremium;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving premium status: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails({productId});
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Product not found: ${response.notFoundIDs}');
        _errorMessage = 'Product not available';
      }
      
      if (response.productDetails.isNotEmpty) {
        _product = response.productDetails.first;
        _errorMessage = null;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading products: $e');
      _errorMessage = 'Failed to load product';
      notifyListeners();
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) {
      _isLoading = true;
      notifyListeners();
    } else {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Grant premium access
        await _savePremiumStatus(true);
        _isLoading = false;
        _errorMessage = null;
      } else if (purchase.status == PurchaseStatus.error) {
        _isLoading = false;
        _errorMessage = purchase.error?.message ?? 'Purchase failed';
      } else if (purchase.status == PurchaseStatus.canceled) {
        _isLoading = false;
        _errorMessage = null;
      }
      
      notifyListeners();
      
      // Complete the purchase
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// Purchase the remove ads product
  Future<bool> purchaseRemoveAds() async {
    if (!_isAvailable || _product == null) {
      _errorMessage = 'Purchase not available';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: _product!);
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Purchase failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      _errorMessage = 'Store not available';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _iap.restorePurchases();
      
      // Give some time for restore to complete
      await Future.delayed(const Duration(seconds: 2));
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Restore failed: $e';
      notifyListeners();
    }
  }

  /// For testing - manually set premium status
  Future<void> setPremiumForTesting(bool value) async {
    await _savePremiumStatus(value);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
