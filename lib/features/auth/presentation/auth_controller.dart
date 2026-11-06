import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

/// Tracks whether the app is currently connected to a live Supabase backend.
class SupabaseBackendModeNotifier extends Notifier<bool> {
  @override
  bool build() => AppConfig.isSupabaseInitialized;

  void markConnected() => state = true;
}

final supabaseBackendModeProvider =
    NotifierProvider<SupabaseBackendModeNotifier, bool>(
      SupabaseBackendModeNotifier.new,
    );

/// Provides the underlying [AuthRepository] implementation.
/// Uses [SupabaseAuthRepository] when Supabase is initialized.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final isSupabase = ref.watch(supabaseBackendModeProvider);
  if (isSupabase) {
    return SupabaseAuthRepository(Supabase.instance.client);
  }
  return FakeAuthRepository();
});

/// Exposes the currently authenticated [AppUser] (or `null` when logged out).
final currentUserProvider = Provider<AppUser?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.value ?? ref.read(authRepositoryProvider).currentUser;
});

/// Simple [ChangeNotifier] bridging [authControllerProvider] changes to
/// `go_router`'s `refreshListenable`.
class AuthRouterNotifier extends ChangeNotifier {
  AuthRouterNotifier(Ref ref) {
    ref.listen<AsyncValue<AppUser?>>(authControllerProvider, (_, _) {
      notifyListeners();
    });
  }
}

final authRouterNotifierProvider = Provider<AuthRouterNotifier>((ref) {
  final notifier = AuthRouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Manages sign-in, quick demo persona switching, and sign-out.
class AuthController extends AsyncNotifier<AppUser?> {
  static final _log = Logger('AuthController');

  @override
  FutureOr<AppUser?> build() {
    return ref.read(authRepositoryProvider).currentUser;
  }

  Future<bool> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signInWithEmailPassword(email, password);
      _log.info('signIn ok (userId=${user.id}, role=${user.role.name})');
      state = AsyncData(user);
      return true;
    } catch (e, s) {
      final mapped = mapToAppException(e);
      _log.warning('signIn failed (type=${mapped.runtimeType})');
      state = AsyncError(mapped, s);
      return false;
    }
  }

  Future<bool> signInAsDemo(Role role) async {
    state = const AsyncLoading();
    try {
      final user = await ref.read(authRepositoryProvider).signInAsDemo(role);
      _log.info('signInAsDemo ok (userId=${user.id}, role=${user.role.name})');
      state = AsyncData(user);
      return true;
    } catch (e, s) {
      final mapped = mapToAppException(e);
      _log.warning('signInAsDemo failed (role=${role.name})');
      state = AsyncError(mapped, s);
      return false;
    }
  }

  Future<void> signOut() async {
    final prevId = state.value?.id;
    await ref.read(authRepositoryProvider).signOut();
    _log.info('signOut ok (userId=$prevId)');
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);
