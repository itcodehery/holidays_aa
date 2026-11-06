import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Riverpod [ProviderObserver] that logs provider failures without logging PII.
final class LoggingObserver extends ProviderObserver {
  const LoggingObserver();

  static final _log = Logger('Provider');

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    _log.warning(
      '${context.provider.name ?? context.provider.runtimeType} failed',
      error,
      stackTrace,
    );
  }
}
