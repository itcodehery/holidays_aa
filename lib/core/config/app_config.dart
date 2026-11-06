import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Application-wide constants and Supabase `.env` / `--dart-define` configuration.
class AppConfig {
  const AppConfig._();

  /// Working days threshold above which a leave request requires two-stage
  /// approval (Manager -> HR/Admin).
  static const int kMultiApprovalThreshold = 3;

  /// Compile-time `--dart-define` values.
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

  static String get supabaseUrl {
    if (_runtimeUrl.isNotEmpty) return _runtimeUrl;
    final fromDotEnv = dotenv.isInitialized
        ? (dotenv.maybeGet('SUPABASE_URL') ?? '')
        : '';
    return fromDotEnv.trim();
  }

  static String get supabasePublishableKey {
    if (_runtimeKey.isNotEmpty) return _runtimeKey;
    if (!dotenv.isInitialized) return '';
    final pubKey = dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY') ?? '';
    if (pubKey.trim().isNotEmpty) return pubKey.trim();
    return (dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '').trim();
  }

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static bool get isSupabaseInitialized => _supabaseInitialized;

  /// Loads `.env` via `flutter_dotenv` and initializes [Supabase].
  static Future<bool> initSupabaseIfConfigured() async {
    if (_supabaseInitialized) return true;

    try {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: '.env');
      }
    } catch (_) {
      // `.env` might not be loaded in unit test environments.
    }

    final url = supabaseUrl;
    final key = supabasePublishableKey;
    if (url.isEmpty || key.isEmpty) return false;

    try {
      await Supabase.initialize(
        url: url,
        publishableKey: key,
      );
      _runtimeUrl = url;
      _runtimeKey = key;
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
