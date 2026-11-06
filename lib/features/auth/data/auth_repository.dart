import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/app_user.dart';

/// Seeded demo personas for quick evaluator login and automated tests.
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
  );

  static const AppUser employee2 = AppUser(
    id: 'usr-emp-2',
    email: 'samira@company.com',
    fullName: 'Samira Patel',
    role: Role.employee,
    managerId: 'usr-mgr-1',
  );

  static const List<AppUser> all = [employee, manager, hr, employee2];

  static AppUser? byId(String id) {
    for (final u in all) {
      if (u.id == id) return u;
    }
    return null;
  }
}

/// Repository contract for authentication and session inspection.
abstract class AuthRepository {
  AppUser? get currentUser;
  Future<AppUser> signInWithEmailPassword(String email, String password);
  Future<AppUser> signInAsDemo(Role role);
  Future<void> signOut();
}

/// In-memory authentication repository with seeded demo accounts.
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

    for (final user in DemoUsers.all) {
      if (user.email.toLowerCase() == normalized) {
        _currentUser = user;
        return user;
      }
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
  Future<AppUser> signInAsDemo(Role role) async {
    switch (role) {
      case Role.employee:
        _currentUser = DemoUsers.employee;
        return DemoUsers.employee;
      case Role.manager:
        _currentUser = DemoUsers.manager;
        return DemoUsers.manager;
      case Role.hr:
        _currentUser = DemoUsers.hr;
        return DemoUsers.hr;
    }
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}

/// Supabase-backed implementation of [AuthRepository].
///
/// Works seamlessly with the seeded accounts in
/// `supabase/migrations/20261106080100_seed_demo_data.sql` (`alex@company.com`,
/// `manager@company.com`, `hr@company.com`) and also supports dynamic sign-up
/// provisioning via `ensure_demo_profile`.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  AppUser? _cachedUser;

  @override
  AppUser? get currentUser => _cachedUser;

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
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      _cachedUser = AppUser.fromJson(profile, email: user.email ?? cleanEmail);
      return _cachedUser!;
    } catch (e) {
      throw mapToAppException(e);
    }
  }

  @override
  Future<AppUser> signInAsDemo(Role role) async {
    final targetDemo = switch (role) {
      Role.employee => DemoUsers.employee,
      Role.manager => DemoUsers.manager,
      Role.hr => DemoUsers.hr,
    };

    try {
      return await signInWithEmailPassword(targetDemo.email, 'demo1234');
    } catch (_) {
      // Fallback: if the demo account was not pre-seeded yet, sign up and
      // invoke `ensure_demo_profile` RPC to configure its role and manager.
      try {
        final signUpRes = await _client.auth.signUp(
          email: targetDemo.email,
          password: 'demo1234',
          data: {'full_name': targetDemo.fullName},
        );
        final user = signUpRes.user;
        if (user == null) {
          throw const UnauthorizedException(
            'Unable to provision demo account in Supabase Auth.',
          );
        }
        final profileMap = await _client.rpc(
          'ensure_demo_profile',
          params: {
            'p_role': role.dbValue,
            'p_full_name': targetDemo.fullName,
            'p_manager_email':
                role == Role.employee ? DemoUsers.manager.email : null,
          },
        );
        _cachedUser = AppUser.fromJson(
          profileMap as Map<String, dynamic>,
          email: targetDemo.email,
        );
        return _cachedUser!;
      } catch (e) {
        throw mapToAppException(e);
      }
    }
  }

  @override
  Future<void> signOut() async {
    _cachedUser = null;
    await _client.auth.signOut();
  }
}
