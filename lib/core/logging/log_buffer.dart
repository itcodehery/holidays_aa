import 'dart:collection';

/// Ring buffer holding the most recent [capacity] log lines in memory.
class LogBuffer {
  LogBuffer._();

  static final LogBuffer instance = LogBuffer._();

  static const int capacity = 200;
  final ListQueue<String> _lines = ListQueue<String>();

  void add(String line) {
    if (_lines.length >= capacity) {
      _lines.removeFirst();
    }
    _lines.addLast(line);
  }

  List<String> get lines => List<String>.unmodifiable(_lines);

  void clear() => _lines.clear();
}
