import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilovepdf_flutter/models/history_item.dart';

class HistoryService with ChangeNotifier {
  static const String _historyKey = 'pdf_processing_history';
  List<HistoryItem> _history = [];

  List<HistoryItem> get history => List.unmodifiable(_history);

  HistoryService() {
    _loadHistory();
  }

  // Add a new item to history
  Future<void> addHistoryItem(HistoryItem item) async {
    _history.insert(0, item); // Add to the beginning of the list
    notifyListeners();
    await _saveHistory();
  }

  // Remove a specific item from history
  Future<void> removeHistoryItem(String id) async {
    _history.removeWhere((item) => item.id == id);
    notifyListeners();
    await _saveHistory();
  }

  // Clear all history
  Future<void> clearHistory() async {
    _history.clear();
    notifyListeners();
    await _saveHistory();
  }

  // Get history item by ID
  HistoryItem? getHistoryItemById(String id) {
    try {
      return _history.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  // Load history from shared preferences
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyString = prefs.getString(_historyKey);
      
      if (historyString != null) {
        final List<dynamic> historyList = json.decode(historyString);
        _history = historyList
            .map((item) => HistoryItem.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      // Notify listeners after loading so UI updates
      notifyListeners();
    } catch (e) {
      // If there's an error loading history, start with an empty list
      _history = [];
      notifyListeners();
    }
  }

  // Save history to shared preferences
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = _history.map((item) => item.toMap()).toList();
      final historyString = json.encode(historyList);
      await prefs.setString(_historyKey, historyString);
    } catch (e) {
      // Handle save error silently
      debugPrint('Error saving history: $e');
    }
  }
}