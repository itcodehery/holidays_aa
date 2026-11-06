import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/logging/logging_observer.dart';
import 'core/logging/setup_logging.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogging();

  // Restore cached user session from SharedPreferences before runApp.
  await SessionStorage.init();

  final connected = await AppConfig.initSupabaseIfConfigured();
  if (connected) {
    Logger('Bootstrap').info('Supabase backend initialized');
    await SupabaseAuthRepository(Supabase.instance.client).restoreSession();
  } else {
    Logger('Bootstrap').info('Running without Supabase connection');
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
