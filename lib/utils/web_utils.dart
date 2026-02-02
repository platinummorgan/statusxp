// Web-specific utilities using dart:html
import 'dart:html' as html;

class WebUtils {
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
