// Stub for path_provider on web
// This file provides dummy implementations for web platform
// On web, we don't use file paths - we use browser downloads instead

class Directory {
  final String path;
  Directory(this.path);
}

Future<Directory> getApplicationDocumentsDirectory() async {
  // Return a dummy directory for web
  // The actual file saving is handled by PlatformFileUtils
  return Directory('/web-downloads');
}

Future<Directory> getTemporaryDirectory() async {
  return Directory('/web-temp');
}

Future<Directory> getApplicationSupportDirectory() async {
  return Directory('/web-support');
}
