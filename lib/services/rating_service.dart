import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle in-app rating prompts
/// Uses smart timing to show rating prompts at optimal moments
class RatingService {
  static final RatingService _instance = RatingService._internal();
  factory RatingService() => _instance;
  RatingService._internal();

  final InAppReview _inAppReview = InAppReview.instance;
  
  // Preference keys
  static const String _keyOperationCount = 'rating_operation_count';
  static const String _keyHasRated = 'rating_has_rated';
  static const String _keyLastPromptTime = 'rating_last_prompt_time';
  static const String _keyPromptCount = 'rating_prompt_count';
  
  // Configuration - when to show rating prompt
  static const int _minOperationsBeforePrompt = 3; // After 3 successful operations
  static const int _daysBetweenPrompts = 7; // Don't show more than once per week
  static const int _maxPrompts = 3; // Stop asking after 3 prompts
  
  /// Track a successful operation and check if we should prompt for rating
  Future<void> trackSuccessfulOperation() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Don't prompt if user has already rated
    if (prefs.getBool(_keyHasRated) ?? false) {
      debugPrint('Rating: User has already rated, skipping');
      return;
    }
    
    // Don't prompt if max prompts reached
    final promptCount = prefs.getInt(_keyPromptCount) ?? 0;
    if (promptCount >= _maxPrompts) {
      debugPrint('Rating: Max prompts reached ($promptCount/$_maxPrompts)');
      return;
    }
    
    // Increment operation count
    final operationCount = (prefs.getInt(_keyOperationCount) ?? 0) + 1;
    await prefs.setInt(_keyOperationCount, operationCount);
    debugPrint('Rating: Operation count: $operationCount');
    
    // Check if enough operations completed
    if (operationCount < _minOperationsBeforePrompt) {
      debugPrint('Rating: Not enough operations yet ($operationCount/$_minOperationsBeforePrompt)');
      return;
    }
    
    // Check if enough time has passed since last prompt
    final lastPromptTime = prefs.getInt(_keyLastPromptTime) ?? 0;
    final daysSinceLastPrompt = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastPromptTime))
        .inDays;
    
    if (lastPromptTime > 0 && daysSinceLastPrompt < _daysBetweenPrompts) {
      debugPrint('Rating: Too soon since last prompt ($daysSinceLastPrompt days)');
      return;
    }
    
    // All conditions met - show rating prompt
    await _showRatingPrompt();
  }
  
  /// Show the native in-app review dialog
  Future<void> _showRatingPrompt() async {
    try {
      final isAvailable = await _inAppReview.isAvailable();
      debugPrint('Rating: In-app review available: $isAvailable');
      
      if (isAvailable) {
        await _inAppReview.requestReview();
        debugPrint('Rating: Review dialog requested');
        
        // Update tracking
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyLastPromptTime, DateTime.now().millisecondsSinceEpoch);
        await prefs.setInt(_keyPromptCount, (prefs.getInt(_keyPromptCount) ?? 0) + 1);
        await prefs.setInt(_keyOperationCount, 0); // Reset operation counter
      } else {
        debugPrint('Rating: In-app review not available, falling back to store');
        // Fallback: Open store listing directly
        await _inAppReview.openStoreListing(
          appStoreId: '', // iOS App Store ID if available
        );
      }
    } catch (e) {
      debugPrint('Rating: Error showing review dialog: $e');
    }
  }
  
  /// Force open the app store for rating (for settings page)
  Future<void> openStoreForRating() async {
    try {
      await _inAppReview.openStoreListing();
      
      // Mark as rated when user explicitly opens store
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasRated, true);
      debugPrint('Rating: User opened store for rating');
    } catch (e) {
      debugPrint('Rating: Error opening store: $e');
    }
  }
  
  /// Mark that user has rated (call when user completes rating)
  Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasRated, true);
    debugPrint('Rating: Marked as rated');
  }
  
  /// Reset rating tracking (for testing)
  Future<void> resetTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOperationCount);
    await prefs.remove(_keyHasRated);
    await prefs.remove(_keyLastPromptTime);
    await prefs.remove(_keyPromptCount);
    debugPrint('Rating: Tracking reset');
  }
  
  /// Get current rating stats (for debugging)
  Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'operationCount': prefs.getInt(_keyOperationCount) ?? 0,
      'hasRated': prefs.getBool(_keyHasRated) ?? false,
      'promptCount': prefs.getInt(_keyPromptCount) ?? 0,
      'lastPromptTime': prefs.getInt(_keyLastPromptTime) ?? 0,
    };
  }
}
