import 'package:logging/logging.dart';

import '../../auth/domain/app_user.dart';
import '../domain/attachment.dart';
import '../domain/leave_request.dart';
import '../domain/leave_status.dart';
import 'leave_repository.dart';

/// Decorator around [LeaveRepository] that logs every operation's start,
/// completion duration, and errors without exposing PII (reasons, comments,
/// filenames, or emails).
class LoggingLeaveRepository implements LeaveRepository {
  LoggingLeaveRepository(this._inner);

  final LeaveRepository _inner;
  final _log = Logger('LeaveRepository');

  Future<T> _run<T>(String op, Future<T> Function() fn) async {
    final sw = Stopwatch()..start();
    _log.fine('$op started');
    try {
      final r = await fn();
      _log.info('$op ok (${sw.elapsedMilliseconds}ms)');
      return r;
    } catch (e, s) {
      _log.severe('$op failed (${sw.elapsedMilliseconds}ms)', e, s);
      rethrow;
    }
  }

  @override
  Future<List<LeaveRequest>> getMyRequests(String userId) =>
      _run('getMyRequests(userId=$userId)', () => _inner.getMyRequests(userId));

  @override
  Future<List<LeaveRequest>> getPendingFor(AppUser approver) => _run(
        'getPendingFor(approverId=${approver.id}, role=${approver.role.name})',
        () => _inner.getPendingFor(approver),
      );

  @override
  Future<List<LeaveRequest>> getHistoryFor(AppUser approver) => _run(
        'getHistoryFor(approverId=${approver.id}, role=${approver.role.name})',
        () => _inner.getHistoryFor(approver),
      );

  @override
  Future<LeaveRequest?> getById(String id) =>
      _run('getById(id=$id)', () => _inner.getById(id));

  @override
  Future<LeaveRequest> submit(
    NewLeaveRequest req,
    List<PickedAttachment> files,
  ) =>
      _run(
        'submit(employeeId=${req.employeeId}, type=${req.leaveType.name}, files=${files.length})',
        () => _inner.submit(req, files),
      );

  @override
  Future<LeaveRequest> decide(String id, Decision d, String? c) =>
      _run('decide(id=$id, ${d.name})', () => _inner.decide(id, d, c));

  @override
  Future<void> cancel(String id) =>
      _run('cancel(id=$id)', () => _inner.cancel(id));

  @override
  Future<Uri> getAttachmentUrl(Attachment a) => _run(
        'getAttachmentUrl(attachmentId=${a.id})',
        () => _inner.getAttachmentUrl(a),
      );

  @override
  Stream<void> watchChanges() => _inner.watchChanges();
}
