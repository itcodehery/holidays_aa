import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/in_memory_leave_repository.dart';
import '../data/leave_repository.dart';
import '../data/logging_leave_repository.dart';
import '../data/supabase_leave_repository.dart';
import '../domain/attachment.dart';
import '../domain/leave_request.dart';
import '../domain/leave_status.dart';

/// Singleton in-memory store instance so data persists across role switches
/// during a demo session.
final inMemoryLeaveRepositoryProvider = Provider<InMemoryLeaveRepository>((ref) {
  return InMemoryLeaveRepository.seeded(
    currentUserResolver: () =>
        ref.read(currentUserProvider) ??
        ref.read(authRepositoryProvider).currentUser,
  );
});

/// Primary [LeaveRepository] provider wrapped in [LoggingLeaveRepository].
/// Automatically uses [SupabaseLeaveRepository] when Supabase is initialized,
/// or [InMemoryLeaveRepository] as fallback in local tests.
final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  final isSupabase = ref.watch(supabaseBackendModeProvider);
  if (isSupabase) {
    return LoggingLeaveRepository(
      SupabaseLeaveRepository(Supabase.instance.client),
    );
  }
  final inner = ref.watch(inMemoryLeaveRepositoryProvider);
  return LoggingLeaveRepository(inner);
});

/// Current status filter chip selection on the Employee "My Requests" screen.
/// `null` means "All".
enum LeaveListFilter { all, pending, approved, rejected }

class MyRequestsFilterNotifier extends Notifier<LeaveListFilter> {
  @override
  LeaveListFilter build() => LeaveListFilter.all;

  void select(LeaveListFilter filter) => state = filter;
}

final myRequestsFilterProvider =
    NotifierProvider<MyRequestsFilterNotifier, LeaveListFilter>(
      MyRequestsFilterNotifier.new,
    );

/// Stream provider emitting whenever `leave_requests` or `leave_approvals`
/// change in realtime (`⭐ Realtime updates`).
final leaveRealtimeChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(leaveRepositoryProvider);
  return repo.watchChanges();
});

/// Fetches the current employee's own submitted leave requests.
final myRequestsProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  ref.watch(leaveRealtimeChangesProvider);
  final user = ref.watch(currentUserProvider) ?? DemoUsers.employee;
  final repo = ref.watch(leaveRepositoryProvider);
  return repo.getMyRequests(user.id);
});

/// Fetches pending leave requests for the currently logged-in Manager or HR.
final pendingRequestsProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  ref.watch(leaveRealtimeChangesProvider);
  final user = ref.watch(currentUserProvider) ?? DemoUsers.manager;
  final repo = ref.watch(leaveRepositoryProvider);
  return repo.getPendingFor(user);
});

/// Fetches historical / decided leave requests for Manager or HR.
final historyRequestsProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  ref.watch(leaveRealtimeChangesProvider);
  final user = ref.watch(currentUserProvider) ?? DemoUsers.manager;
  final repo = ref.watch(leaveRepositoryProvider);
  return repo.getHistoryFor(user);
});

/// Fetches a single leave request by ID.
final leaveDetailProvider =
    FutureProvider.family<LeaveRequest?, String>((ref, id) async {
      ref.watch(leaveRealtimeChangesProvider);
      final repo = ref.watch(leaveRepositoryProvider);
      return repo.getById(id);
    });

/// Controller for mutating leave actions: `submit`, `decide`, and `cancel`.
/// Invalidates list providers only on success.
class LeaveActionsController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  void _invalidateLists({String? requestId}) {
    ref.invalidate(myRequestsProvider);
    ref.invalidate(pendingRequestsProvider);
    ref.invalidate(historyRequestsProvider);
    if (requestId != null) {
      ref.invalidate(leaveDetailProvider(requestId));
    }
  }

  /// Submits a new leave request with optional [files].
  /// Returns the created [LeaveRequest] on success, or `null` on failure.
  Future<LeaveRequest?> submit(
    NewLeaveRequest req,
    List<PickedAttachment> files,
  ) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(leaveRepositoryProvider);
      final created = await repo.submit(req, files);
      state = const AsyncData(null);
      _invalidateLists(requestId: created.id);
      return created;
    } catch (e, s) {
      state = AsyncError(mapToAppException(e), s);
      return null;
    }
  }

  /// Approves or rejects a leave request with an optional (or required on
  /// reject) [comment].
  Future<LeaveRequest?> decide(
    String id,
    Decision decision,
    String? comment,
  ) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(leaveRepositoryProvider);
      final updated = await repo.decide(id, decision, comment);
      state = const AsyncData(null);
      _invalidateLists(requestId: id);
      return updated;
    } catch (e, s) {
      state = AsyncError(mapToAppException(e), s);
      return null;
    }
  }

  /// Cancels a pending leave request.
  Future<bool> cancel(String id) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(leaveRepositoryProvider);
      await repo.cancel(id);
      state = const AsyncData(null);
      _invalidateLists(requestId: id);
      return true;
    } catch (e, s) {
      state = AsyncError(mapToAppException(e), s);
      return false;
    }
  }
}

final leaveActionsProvider =
    AsyncNotifierProvider<LeaveActionsController, void>(
      LeaveActionsController.new,
    );
