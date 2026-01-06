import 'package:flutter/material.dart';

/// Mock PremiumService for testing that doesn't connect to in-app purchase
class MockPremiumService with ChangeNotifier {
  bool _isAvailable = false;
  bool _isPremium = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isAvailable => _isAvailable;
  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get priceString => '₹199';

  /// For testing - manually set premium status
  void setPremiumForTesting(bool value) {
    _isPremium = value;
    notifyListeners();
  }
  
  void setAvailableForTesting(bool value) {
    _isAvailable = value;
    notifyListeners();
  }

  Future<bool> purchaseRemoveAds() async {
    return false;
  }

  Future<void> restorePurchases() async {
    // No-op for testing
  }
}
