// Stub for google_mobile_ads on web
// This prevents compilation errors when building for web

class MobileAds {
  static Future<void> instance() async {}
}

class ConsentRequestParameters {}

class ConsentInformation {
  static ConsentInformation get instance => ConsentInformation();
  Future<void> requestConsentInfoUpdate(
    ConsentRequestParameters params,
    Function() onSuccess,
    Function(FormError) onError,
  ) async {}
  Future<bool> isConsentFormAvailable() async => false;
}

class ConsentForm {
  static Future<void> loadAndShowConsentFormIfRequired(
    Function(FormError?) callback,
  ) async {}
}

class FormError {
  final String message;
  FormError(this.message);
}
