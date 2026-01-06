import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ilovepdf_flutter/services/history_service.dart';
import 'package:ilovepdf_flutter/models/history_item.dart';

void main() {
  group('HistoryService', () {
    late HistoryService service;

    HistoryItem createTestItem({
      String id = 'test-id',
      String fileName = 'test.pdf',
      String toolName = 'Compress',
      String toolId = 'compress',
    }) {
      return HistoryItem(
        id: id,
        fileName: fileName,
        toolName: toolName,
        processedDate: DateTime.now(),
        fileSize: 1024,
        filePath: '/path/to/$fileName',
        toolId: toolId,
      );
    }

    setUp(() async {
      // Initialize SharedPreferences with empty values for testing
      SharedPreferences.setMockInitialValues({});
      service = HistoryService();
      // Wait for async initialization to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    group('initialization', () {
      test('starts with empty history', () {
        expect(service.history.isEmpty, true);
      });

      test('loads saved history on init', () async {
        final testDate = DateTime(2024, 12, 17, 10, 30);
        SharedPreferences.setMockInitialValues({
          'pdf_processing_history': '''[
            {
              "id": "saved-1",
              "fileName": "saved.pdf",
              "toolName": "Merge",
              "processedDate": ${testDate.millisecondsSinceEpoch},
              "fileSize": 2048,
              "filePath": "/path/saved.pdf",
              "toolId": "merge"
            }
          ]''',
        });
        
        final loadedService = HistoryService();
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(loadedService.history.length, 1);
        expect(loadedService.history.first.fileName, 'saved.pdf');
      });
    });

    group('addHistoryItem', () {
      test('adds item to history', () async {
        final item = createTestItem();
        await service.addHistoryItem(item);
        
        expect(service.history.length, 1);
        expect(service.history.first.id, 'test-id');
      });

      test('adds new items at the beginning (most recent first)', () async {
        final item1 = createTestItem(id: 'first');
        final item2 = createTestItem(id: 'second');
        
        await service.addHistoryItem(item1);
        await service.addHistoryItem(item2);
        
        expect(service.history.length, 2);
        expect(service.history[0].id, 'second'); // Most recent
        expect(service.history[1].id, 'first');
      });

      test('can add multiple items', () async {
        for (int i = 0; i < 5; i++) {
          await service.addHistoryItem(createTestItem(id: 'item-$i'));
        }
        
        expect(service.history.length, 5);
      });
    });

    group('removeHistoryItem', () {
      test('removes item by id', () async {
        await service.addHistoryItem(createTestItem(id: 'to-remove'));
        await service.addHistoryItem(createTestItem(id: 'to-keep'));
        
        await service.removeHistoryItem('to-remove');
        
        expect(service.history.length, 1);
        expect(service.history.first.id, 'to-keep');
      });

      test('does nothing when removing non-existent id', () async {
        await service.addHistoryItem(createTestItem(id: 'existing'));
        
        await service.removeHistoryItem('non-existent');
        
        expect(service.history.length, 1);
      });
    });

    group('clearHistory', () {
      test('removes all items', () async {
        await service.addHistoryItem(createTestItem(id: 'item-1'));
        await service.addHistoryItem(createTestItem(id: 'item-2'));
        await service.addHistoryItem(createTestItem(id: 'item-3'));
        
        expect(service.history.length, 3);
        
        await service.clearHistory();
        
        expect(service.history.isEmpty, true);
      });

      test('clearing empty history does not throw', () async {
        expect(service.history.isEmpty, true);
        await service.clearHistory();
        expect(service.history.isEmpty, true);
      });
    });

    group('getHistoryItemById', () {
      test('returns item when found', () async {
        await service.addHistoryItem(createTestItem(id: 'findable'));
        
        final found = service.getHistoryItemById('findable');
        
        expect(found, isNotNull);
        expect(found!.id, 'findable');
      });

      test('returns null when not found', () async {
        await service.addHistoryItem(createTestItem(id: 'existing'));
        
        final notFound = service.getHistoryItemById('non-existent');
        
        expect(notFound, isNull);
      });

      test('returns correct item among multiple', () async {
        await service.addHistoryItem(createTestItem(id: 'item-1', fileName: 'first.pdf'));
        await service.addHistoryItem(createTestItem(id: 'item-2', fileName: 'second.pdf'));
        await service.addHistoryItem(createTestItem(id: 'item-3', fileName: 'third.pdf'));
        
        final found = service.getHistoryItemById('item-2');
        
        expect(found, isNotNull);
        expect(found!.fileName, 'second.pdf');
      });
    });

    group('history getter', () {
      test('returns unmodifiable list', () async {
        await service.addHistoryItem(createTestItem());
        final history = service.history;
        
        // Trying to modify should throw
        expect(() => history.add(createTestItem(id: 'new')), throwsUnsupportedError);
      });
    });

    group('persistence', () {
      test('history persists across service instances', () async {
        SharedPreferences.setMockInitialValues({});
        
        // First service instance - add items
        final service1 = HistoryService();
        await Future.delayed(const Duration(milliseconds: 100));
        await service1.addHistoryItem(createTestItem(id: 'persisted'));
        
        // Get saved prefs
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('pdf_processing_history');
        expect(saved, isNotNull);
        
        // Second service instance with same prefs
        SharedPreferences.setMockInitialValues({
          'pdf_processing_history': saved!,
        });
        
        final service2 = HistoryService();
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(service2.history.length, 1);
        expect(service2.history.first.id, 'persisted');
      });
    });

    group('edge cases', () {
      test('handles item with special characters in fileName', () async {
        final item = HistoryItem(
          id: 'special',
          fileName: 'file with spaces & symbols!.pdf',
          toolName: 'Compress',
          processedDate: DateTime.now(),
          fileSize: 1024,
          filePath: '/path/file.pdf',
          toolId: 'compress',
        );
        
        await service.addHistoryItem(item);
        
        expect(service.history.first.fileName, 'file with spaces & symbols!.pdf');
      });

      test('handles large file sizes', () async {
        final item = HistoryItem(
          id: 'large',
          fileName: 'large.pdf',
          toolName: 'Compress',
          processedDate: DateTime.now(),
          fileSize: 9999999999, // ~10 GB
          filePath: '/path/large.pdf',
          toolId: 'compress',
        );
        
        await service.addHistoryItem(item);
        
        expect(service.history.first.fileSize, 9999999999);
      });
    });
  });
}
