// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

// Web-specific utilities using dart:html
import 'dart:html' as html;

class WebUtils {
  static String? readSessionValue(String key) =>
      html.window.sessionStorage[key];
  static void writeSessionValue(String key, String value) {
    html.window.sessionStorage[key] = value;
  }

  static void removeSessionValue(String key) {
    html.window.sessionStorage.remove(key);
  }

  static String getCurrentUrl() {
    return html.window.location.href;
  }

  static void replaceUrl(String url) {
    html.window.history.replaceState(null, '', url);
  }

  static void redirectTo(String url) {
    html.window.location.assign(url);
  }
}
