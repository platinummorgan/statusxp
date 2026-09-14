// Stub for non-web platforms (mobile/desktop)
class WebUtils {
  static String? readSessionValue(String key) =>
      throw UnsupportedError('Session storage is only available on web');
  static void writeSessionValue(String key, String value) =>
      throw UnsupportedError('Session storage is only available on web');
  static void removeSessionValue(String key) =>
      throw UnsupportedError('Session storage is only available on web');

  static String getCurrentUrl() {
    throw UnimplementedError('getCurrentUrl is only available on web');
  }

  static void replaceUrl(String url) {
    throw UnimplementedError('replaceUrl is only available on web');
  }

  static void redirectTo(String url) {
    throw UnimplementedError('redirectTo is only available on web');
  }
}
