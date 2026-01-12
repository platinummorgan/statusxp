// Conditional export: uses dart:html on web, stub on mobile
export 'html_stub.dart'
  if (dart.library.html) 'html_web.dart';
