import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_user.dart';

/// Persists and restores the currently logged-in [AppUser] across app restarts
/// using [SharedPreferences].
class SessionStorage {
  const SessionStorage._();

  static const String _kSessionUserKey = 'holiday.session.user.v1';
  static final _log = Logger('SessionStorage');

  static SharedPreferences? _prefs;
  static AppUser? _cachedUser;

  /// Synchronously accessible user restored during [init] or saved during
  /// [saveUser].
  static AppUser? get cachedUser => _cachedUser;

  /// Initializes [SharedPreferences] and restores any persisted [AppUser]
  /// before `runApp` so routing has immediate synchronous access to the session.
  static Future<AppUser?> init() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_kSessionUserKey);
      if (raw == null || raw.isEmpty) {
        _cachedUser = null;
        return null;
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _cachedUser = AppUser.fromJson(decoded);
      _log.info(
        'Restored persisted session (userId=${_cachedUser!.id}, role=${_cachedUser!.role.name})',
      );
      return _cachedUser;
    } catch (e, s) {
      _log.warning('Failed to restore persisted session', e, s);
      _cachedUser = null;
      return null;
    }
  }

  /// Persists [user] to [SharedPreferences].
  static Future<void> saveUser(AppUser user) async {
    _cachedUser = user;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_kSessionUserKey, jsonEncode(user.toJson()));
      _log.fine('Saved session for userId=${user.id}');
    } catch (e, s) {
      _log.warning('Failed to persist session to SharedPreferences', e, s);
    }
  }

  /// Clears the persisted [AppUser] from memory and [SharedPreferences].
  static Future<void> clearUser() async {
    _cachedUser = null;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_kSessionUserKey);
      _log.fine('Cleared persisted session');
    } catch (e, s) {
      _log.warning('Failed to clear session from SharedPreferences', e, s);
    }
  }
}
