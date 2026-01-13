import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:developer' as developer;
import 'dart:js' as js if (dart.library.js) 'dart:js';

void statusxpLog(String message) {
  // Always print to Dart console
  developer.log(message, name: 'StatusXP');
  print(message);

  // For Flutter web, also log to browser console
  if (kIsWeb) {
    try {
      // ignore: undefined_prefixed_name
      js.context.callMethod('console.log', [message]);
    } catch (_) {
      // Fallback: ignore if JS interop fails
    }
  }
}
