import 'package:flutter_test/flutter_test.dart';
import 'package:ilovepdf_flutter/models/history_item.dart';

void main() {
  group('HistoryItem', () {
    late HistoryItem testItem;

    setUp(() {
      testItem = HistoryItem(
        id: 'test-id-123',
        fileName: 'test_document.pdf',
        toolName: 'Compress',
        processedDate: DateTime(2024, 12, 17, 14, 30),
        fileSize: 1048576, // 1 MB
        filePath: '/path/to/file.pdf',
        toolId: 'compress',
      );
    });

    group('formattedFileSize', () {
      test('formats bytes correctly', () {
        final smallItem = HistoryItem(
          id: 'test-1',
          fileName: 'small.pdf',
          toolName: 'Test',
          processedDate: DateTime.now(),
          fileSize: 512,
          filePath: '/path',
          toolId: 'test',
        );
        expect(smallItem.formattedFileSize, '512 B');
      });

      test('formats kilobytes correctly', () {
        final kbItem = HistoryItem(
          id: 'test-2',
          fileName: 'medium.pdf',
          toolName: 'Test',
          processedDate: DateTime.now(),
          fileSize: 5120, // 5 KB
          filePath: '/path',
          toolId: 'test',
        );
        expect(kbItem.formattedFileSize, '5.0 KB');
      });

      test('formats megabytes correctly', () {
        expect(testItem.formattedFileSize, '1.0 MB');
      });

      test('formats gigabytes correctly', () {
        final gbItem = HistoryItem(
          id: 'test-3',
          fileName: 'large.pdf',
          toolName: 'Test',
          processedDate: DateTime.now(),
          fileSize: 2147483648, // 2 GB
          filePath: '/path',
          toolId: 'test',
        );
        expect(gbItem.formattedFileSize, '2.0 GB');
      });

      test('handles edge case at exact boundary (1024 bytes)', () {
        final boundaryItem = HistoryItem(
          id: 'test-4',
          fileName: 'boundary.pdf',
          toolName: 'Test',
          processedDate: DateTime.now(),
          fileSize: 1024, // Exactly 1 KB
          filePath: '/path',
          toolId: 'test',
        );
        expect(boundaryItem.formattedFileSize, '1.0 KB');
      });

      test('handles zero bytes', () {
        final zeroItem = HistoryItem(
          id: 'test-5',
          fileName: 'empty.pdf',
          toolName: 'Test',
          processedDate: DateTime.now(),
          fileSize: 0,
          filePath: '/path',
          toolId: 'test',
        );
        expect(zeroItem.formattedFileSize, '0 B');
      });
    });

    group('formattedDate', () {
      test('formats date correctly', () {
        expect(testItem.formattedDate, '17/12/2024 14:30');
      });

      test('pads minutes with leading zero', () {
        final earlyItem = HistoryItem(
          id: 'test-6',
          fileName: 'early.pdf',
          toolName: 'Test',
          processedDate: DateTime(2024, 1, 5, 9, 5),
          fileSize: 100,
          filePath: '/path',
          toolId: 'test',
        );
        expect(earlyItem.formattedDate, '5/1/2024 9:05');
      });

      test('handles midnight correctly', () {
        final midnightItem = HistoryItem(
          id: 'test-7',
          fileName: 'midnight.pdf',
          toolName: 'Test',
          processedDate: DateTime(2024, 12, 31, 0, 0),
          fileSize: 100,
          filePath: '/path',
          toolId: 'test',
        );
        expect(midnightItem.formattedDate, '31/12/2024 0:00');
      });
    });

    group('toMap and fromMap', () {
      test('toMap serializes all fields correctly', () {
        final map = testItem.toMap();

        expect(map['id'], 'test-id-123');
        expect(map['fileName'], 'test_document.pdf');
        expect(map['toolName'], 'Compress');
        expect(map['processedDate'], isA<int>());
        expect(map['fileSize'], 1048576);
        expect(map['filePath'], '/path/to/file.pdf');
        expect(map['toolId'], 'compress');
      });

      test('fromMap deserializes all fields correctly', () {
        final map = {
          'id': 'restored-id',
          'fileName': 'restored.pdf',
          'toolName': 'Merge',
          'processedDate': DateTime(2024, 6, 15, 10, 30).millisecondsSinceEpoch,
          'fileSize': 2097152,
          'filePath': '/restored/path.pdf',
          'toolId': 'merge',
        };

        final restored = HistoryItem.fromMap(map);

        expect(restored.id, 'restored-id');
        expect(restored.fileName, 'restored.pdf');
        expect(restored.toolName, 'Merge');
        expect(restored.processedDate.year, 2024);
        expect(restored.processedDate.month, 6);
        expect(restored.processedDate.day, 15);
        expect(restored.fileSize, 2097152);
        expect(restored.filePath, '/restored/path.pdf');
        expect(restored.toolId, 'merge');
      });

      test('round-trip serialization preserves data', () {
        final map = testItem.toMap();
        final restored = HistoryItem.fromMap(map);

        expect(restored.id, testItem.id);
        expect(restored.fileName, testItem.fileName);
        expect(restored.toolName, testItem.toolName);
        expect(restored.fileSize, testItem.fileSize);
        expect(restored.filePath, testItem.filePath);
        expect(restored.toolId, testItem.toolId);
        // Date comparison (millisecond precision)
        expect(
          restored.processedDate.millisecondsSinceEpoch,
          testItem.processedDate.millisecondsSinceEpoch,
        );
      });
    });
  });
}
