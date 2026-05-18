// Conditional export for path_provider
// Uses real path_provider on mobile, stub on web

export 'path_provider_mobile.dart'
  if (dart.library.html) 'path_provider_stub.dart';
