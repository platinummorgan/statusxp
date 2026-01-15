// Stub for non-web platforms
class Window {
  final Storage localStorage = Storage();
  final Storage sessionStorage = Storage();
  final History history = History();
  final Location location = Location();
}

class Storage {
  final Map<String, String> _data = {};

  void clear() {
    _data.clear();
  }

  void remove(String key) {
    _data.remove(key);
  }

  int get length => _data.length;

  bool containsKey(String key) => _data.containsKey(key);

  String? operator [](String key) => _data[key];

  void operator []=(String key, String value) {
    _data[key] = value;
  }

  List<String> get keys => _data.keys.toList(growable: false);
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
