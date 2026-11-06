import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/logging/logging_observer.dart';
import 'core/logging/setup_logging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogging();

  final connected = await AppConfig.initSupabaseIfConfigured();
  if (connected) {
    Logger('Bootstrap').info('Supabase backend initialized');
  } else {
    Logger('Bootstrap').info(
      'No SUPABASE_URL configured yet; awaiting credentials or running demo fallback',
    );
  }

  FlutterError.onError = (FlutterErrorDetails d) =>
      Logger('Flutter').severe('Framework error', d.exception, d.stack);

  PlatformDispatcher.instance.onError = (Object e, StackTrace s) {
    Logger('Platform').severe('Uncaught error', e, s);
    return true;
  };

  runApp(
    const ProviderScope(
      observers: [LoggingObserver()],
      child: App(),
    ),
  );
}
