import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:developer' as developer;

void statusxpLog(String message) {
  // Always print to Dart console
  developer.log(message, name: 'StatusXP');
  print(message);

  // Web-specific browser console logging removed to support mobile builds
  // kIsWeb flag can still be used for other web-specific logic if needed
}
