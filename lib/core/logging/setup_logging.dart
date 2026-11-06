import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'log_buffer.dart';

bool _loggingInitialized = false;

/// Configures root logger output and attaches the in-memory [LogBuffer].
void setupLogging() {
  if (_loggingInitialized) return;
  _loggingInitialized = true;

  Logger.root.level = kReleaseMode ? Level.INFO : Level.ALL;
  Logger.root.onRecord.listen((r) {
    final line =
        '${r.time.toIso8601String()} [${r.level.name}] ${r.loggerName}: ${r.message}'
        '${r.error != null ? ' | ${r.error}' : ''}';
    debugPrint(line);
    LogBuffer.instance.add(line);
  });
}
