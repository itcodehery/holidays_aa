import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/app_user.dart';
import 'session_storage.dart';

/// Test fixture personas used by unit and widget tests.
class DemoUsers {
  const DemoUsers._();

  static const AppUser manager = AppUser(
    id: 'usr-mgr-1',
    email: 'manager@company.com',
    fullName: 'Priya Sharma (Manager)',
    role: Role.manager,
  );

  static const AppUser hr = AppUser(
    id: 'usr-hr-1',
    email: 'hr@company.com',
    fullName: 'Marcus Vance (HR Admin)',
    role: Role.hr,
  );

  static const AppUser employee = AppUser(
    id: 'usr-emp-1',
    email: 'alex@company.com',
    fullName: 'Alex Rivera',
    role: Role.employee,
    managerId: 'usr-mgr-1',
    managerName: 'Priya Sharma',
  );

  static const AppUser employee2 = AppUser(
    id: 'usr-emp-2',
    email: 'samira@company.com',
    fullName: 'Samira Patel',
    role: Role.employee,
    managerId: 'usr-mgr-1',
    managerName: 'Priya Sharma',
  );

  static const List<AppUser> all = [employee, manager, hr, employee2];

  static AppUser? byId(String id) {
    for (final u in all) {
      if (u.id == id) return u;
    }
    return null;
  }

  static AppUser? byEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final u in all) {
      if (u.email.toLowerCase() == normalized) return u;
    }
    return null;
  }
}

/// Repository contract for authentication and session inspection.
abstract class AuthRepository {
  AppUser? get currentUser;
  Future<AppUser> signInWithEmailPassword(String email, String password);
  Future<void> signOut();
}

/// In-memory authentication repository used in automated tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? initialUser}) : _currentUser = initialUser;

  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser> signInWithEmailPassword(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) {
      throw const ValidationException('Email and password are required.');
    }

    final matched = DemoUsers.byEmail(normalized);
    if (matched != null) {
      _currentUser = matched;
      return matched;
    }

    if (normalized.contains('hr')) {
      _currentUser = DemoUsers.hr;
      return DemoUsers.hr;
    }
    if (normalized.contains('mgr') || normalized.contains('manager')) {
      _currentUser = DemoUsers.manager;
      return DemoUsers.manager;
    }

    _currentUser = DemoUsers.employee;
    return DemoUsers.employee;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}

/// Live Supabase-backed implementation of [AuthRepository] with
/// [SessionStorage] persistence across app restarts.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client) : _cachedUser = SessionStorage.cachedUser;

  final SupabaseClient _client;
  AppUser? _cachedUser;

  @override
  AppUser? get currentUser => _cachedUser ?? SessionStorage.cachedUser;

  Future<AppUser> _fetchAndPersistProfile(User user, {String fallbackEmail = ''}) async {
    final profile = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    String? managerName;
    final managerId = profile['manager_id'] as String?;
    if (managerId != null && managerId.isNotEmpty) {
      final mgrRow = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', managerId)
          .maybeSingle();
      if (mgrRow != null) {
        managerName = (mgrRow['full_name'] as String?)
            ?.replaceAll(' (Manager)', '')
            .trim();
      }
    }

    final appUser = AppUser.fromJson(
      profile,
      email: user.email ?? fallbackEmail,
      managerName: managerName,
    );
    _cachedUser = appUser;
    await SessionStorage.saveUser(appUser);
    return appUser;
  }

  /// Restores or refreshes the active Supabase session on app startup.
  Future<AppUser?> restoreSession() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      // No active Supabase auth token; clear any stale cached user.
      if (SessionStorage.cachedUser != null) {
        await SessionStorage.clearUser();
      }
      _cachedUser = null;
      return null;
    }

    try {
      return await _fetchAndPersistProfile(authUser);
    } catch (_) {
      // If offline on launch, keep the persisted SessionStorage user.
      return _cachedUser ?? SessionStorage.cachedUser;
    }
  }

  @override
  Future<AppUser> signInWithEmailPassword(String email, String password) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      throw const ValidationException('Email and password are required.');
    }
    try {
      final res = await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );
      final user = res.user;
      if (user == null) {
        throw const UnauthorizedException('Invalid login credentials.');
      }
      return await _fetchAndPersistProfile(user, fallbackEmail: cleanEmail);
    } catch (e) {
      throw mapToAppException(e);
    }
  }

  @override
  Future<void> signOut() async {
    _cachedUser = null;
    await SessionStorage.clearUser();
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }
}
