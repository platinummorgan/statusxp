import 'dart:io' show Platform;

final bool isFlutterTestEnvironment = Platform.environment.containsKey(
  'FLUTTER_TEST',
);
