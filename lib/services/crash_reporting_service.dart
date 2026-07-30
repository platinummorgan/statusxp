import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashReportingService {
  CrashReportingService._();

  static final CrashReportingService instance = CrashReportingService._();

  bool _ready = false;

  Future<void> initialize() async {
    if (kIsWeb) return;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );
    _ready = true;
  }

  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {
    if (!_ready) return;
    await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  }

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    String? reason,
  }) async {
    if (!_ready) return;
    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: fatal,
      reason: reason,
    );
  }
}
