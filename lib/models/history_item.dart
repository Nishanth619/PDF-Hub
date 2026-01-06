class HistoryItem {
  final String id;
  final String fileName;
  final String toolName;
  final DateTime processedDate;
  final int fileSize; // in bytes
  final String filePath;
  final String toolId;

  HistoryItem({
    required this.id,
    required this.fileName,
    required this.toolName,
    required this.processedDate,
    required this.fileSize,
    required this.filePath,
    required this.toolId,
  });

  // Format file size for display
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Format date for display
  String get formattedDate {
    return '${processedDate.day}/${processedDate.month}/${processedDate.year} ${processedDate.hour}:${processedDate.minute.toString().padLeft(2, '0')}';
  }

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'toolName': toolName,
      'processedDate': processedDate.millisecondsSinceEpoch,
      'fileSize': fileSize,
      'filePath': filePath,
      'toolId': toolId,
    };
  }

  // Create from map
  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'],
      fileName: map['fileName'],
      toolName: map['toolName'],
      processedDate: DateTime.fromMillisecondsSinceEpoch(map['processedDate']),
      fileSize: map['fileSize'],
      filePath: map['filePath'],
      toolId: map['toolId'],
    );
  }
}