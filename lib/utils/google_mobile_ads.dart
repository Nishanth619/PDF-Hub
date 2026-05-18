// Conditional export for google_mobile_ads
// Uses real package on mobile, stub on web

export 'package:google_mobile_ads/google_mobile_ads.dart'
  if (dart.library.html) '../stubs/google_mobile_ads_stub.dart';
