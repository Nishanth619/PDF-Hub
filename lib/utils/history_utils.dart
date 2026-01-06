import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ilovepdf_flutter/models/history_item.dart';
import 'package:ilovepdf_flutter/services/history_service.dart';

class HistoryUtils {
  /// Add a processed file to history
  static Future<void> addToHistory({
    required BuildContext context,
    required String fileName,
    required String toolName,
    required String toolId,
    required String filePath,
  }) async {
    try {
      // Get file size
      final file = File(filePath);
      final fileSize = await file.length();
      
      // Create history item
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName,
        toolName: toolName,
        toolId: toolId,
        processedDate: DateTime.now(),
        fileSize: fileSize,
        filePath: filePath,
      );
      
      // Add to history service
      final historyService = Provider.of<HistoryService>(context, listen: false);
      await historyService.addHistoryItem(historyItem);
    } catch (e) {
      debugPrint('Error adding to history: $e');
    }
  }
  
  /// Add a processed file to history with file size provided
  static Future<void> addToHistoryWithSize({
    required BuildContext context,
    required String fileName,
    required String toolName,
    required String toolId,
    required String filePath,
    required int fileSize,
  }) async {
    try {
      // Create history item
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName,
        toolName: toolName,
        toolId: toolId,
        processedDate: DateTime.now(),
        fileSize: fileSize,
        filePath: filePath,
      );
      
      // Add to history service
      final historyService = Provider.of<HistoryService>(context, listen: false);
      await historyService.addHistoryItem(historyItem);
    } catch (e) {
      debugPrint('Error adding to history: $e');
    }
  }
}