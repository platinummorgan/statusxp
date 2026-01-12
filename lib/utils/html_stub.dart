// Stub for non-web platforms
class Window {
  final Storage localStorage = Storage();
  final Storage sessionStorage = Storage();
  final History history = History();
  final Location location = Location();
}

class Storage {
  void clear() {}
  void remove(String key) {}
  int get length => 0;
}

class History {
  void replaceState(dynamic data, String title, String url) {}
}

class Location {
  String get origin => '';
}

class Document {
  String? get cookie => null;
  set cookie(String value) {}
}

final window = Window();
final document = Document();
