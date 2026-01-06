import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage favorite tools
class FavoritesService with ChangeNotifier {
  static const String _favoritesKey = 'favorite_tools';
  Set<String> _favorites = {};

  Set<String> get favorites => Set.unmodifiable(_favorites);

  FavoritesService() {
    _loadFavorites();
  }

  /// Check if a tool is favorited
  bool isFavorite(String toolId) => _favorites.contains(toolId);

  /// Toggle favorite status
  Future<void> toggleFavorite(String toolId) async {
    if (_favorites.contains(toolId)) {
      _favorites.remove(toolId);
    } else {
      _favorites.add(toolId);
    }
    notifyListeners();
    await _saveFavorites();
  }

  /// Add to favorites
  Future<void> addFavorite(String toolId) async {
    if (!_favorites.contains(toolId)) {
      _favorites.add(toolId);
      notifyListeners();
      await _saveFavorites();
    }
  }

  /// Remove from favorites
  Future<void> removeFavorite(String toolId) async {
    if (_favorites.contains(toolId)) {
      _favorites.remove(toolId);
      notifyListeners();
      await _saveFavorites();
    }
  }

  /// Clear all favorites
  Future<void> clearFavorites() async {
    _favorites.clear();
    notifyListeners();
    await _saveFavorites();
  }

  /// Load favorites from storage
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesString = prefs.getString(_favoritesKey);
      if (favoritesString != null) {
        final List<dynamic> favoritesList = json.decode(favoritesString);
        _favorites = favoritesList.map((e) => e.toString()).toSet();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      _favorites = {};
    }
  }

  /// Save favorites to storage
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesString = json.encode(_favorites.toList());
      await prefs.setString(_favoritesKey, favoritesString);
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }
}
