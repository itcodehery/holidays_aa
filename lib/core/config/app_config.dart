import 'package:supabase_flutter/supabase_flutter.dart';

/// Application-wide constants and Supabase backend configuration.
class AppConfig {
  const AppConfig._();

  /// Working days threshold above which a leave request requires two-stage
  /// approval (Manager -> HR/Admin).
  static const int kMultiApprovalThreshold = 3;

  /// Compile-time `--dart-define` values (or `.env.json` via `--dart-define-from-file`).
  static const String _envSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String _runtimeUrl = _envSupabaseUrl;
  static String _runtimeKey = _envPublishableKey.isNotEmpty
      ? _envPublishableKey
      : _envAnonKey;
  static bool _supabaseInitialized = false;

  static String get supabaseUrl => _runtimeUrl;
  static String get supabasePublishableKey => _runtimeKey;

  static bool get hasSupabaseConfig =>
      _runtimeUrl.isNotEmpty && _runtimeKey.isNotEmpty;

  static bool get isSupabaseInitialized => _supabaseInitialized;

  /// Initializes [Supabase] when credentials are provided via `--dart-define`
  /// or configured at runtime.
  static Future<bool> initSupabaseIfConfigured() async {
    if (_supabaseInitialized) return true;
    if (!hasSupabaseConfig) return false;

    try {
      await Supabase.initialize(
        url: _runtimeUrl,
        publishableKey: _runtimeKey,
      );
      _supabaseInitialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Connects Supabase project credentials at runtime.
  static Future<void> configureSupabase({
    required String url,
    required String key,
  }) async {
    final cleanUrl = url.trim();
    final cleanKey = key.trim();
    _runtimeUrl = cleanUrl;
    _runtimeKey = cleanKey;

    if (!_supabaseInitialized) {
      await Supabase.initialize(
        url: cleanUrl,
        publishableKey: cleanKey,
      );
      _supabaseInitialized = true;
    }
  }
}

const int kMultiApprovalThreshold = AppConfig.kMultiApprovalThreshold;
