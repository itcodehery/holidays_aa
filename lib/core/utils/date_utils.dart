import 'package:intl/intl.dart';

/// Date formatting and normalization utilities.
/// All leave dates are stored and compared as date-only values to prevent
/// timezone drift.
class AppDateUtils {
  const AppDateUtils._();

  static final DateFormat _displayFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _shortFormat = DateFormat('dd MMM');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');

  /// Strips time components, returning a local midnight [DateTime].
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Formats a single date as `dd MMM yyyy` (e.g., `09 Nov 2026`).
  static String formatDate(DateTime date) => _displayFormat.format(dateOnly(date));

  /// Formats a date range concisely.
  static String formatRange(DateTime start, DateTime end) {
    final s = dateOnly(start);
    final e = dateOnly(end);
    if (s == e) return formatDate(s);
    if (s.year == e.year) {
      return '${_shortFormat.format(s)} – ${_displayFormat.format(e)}';
    }
    return '${formatDate(s)} – ${formatDate(e)}';
  }

  /// Formats a timestamp for the approval timeline.
  static String formatDateTime(DateTime dt) => _dateTimeFormat.format(dt.toLocal());

  /// Formats file size in human-readable KB or MB.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }
}
