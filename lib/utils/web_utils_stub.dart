// Stub for non-web platforms (mobile/desktop)
class WebUtils {
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
