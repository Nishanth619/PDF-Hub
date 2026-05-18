import 'dart:typed_data';

import 'platform_file_utils_mobile.dart' if (dart.library.js) 'platform_file_utils_web.dart';

class PlatformFileUtils {
  static Future<void> saveFile(String fileName, Uint8List bytes) {
    return saveFileImpl(fileName, bytes);
  }
}
