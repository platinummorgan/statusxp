import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kDebugMode;

void statusxpLog(String message) {
  if (!kDebugMode) return;
  developer.log(message, name: 'StatusXP');
}
