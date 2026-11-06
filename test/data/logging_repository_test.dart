import 'package:flutter_test/flutter_test.dart';
import 'package:holidays/features/auth/domain/app_user.dart';
import 'package:holidays/features/leave/data/leave_repository.dart';
import 'package:holidays/features/leave/data/logging_leave_repository.dart';
import 'package:holidays/features/leave/domain/attachment.dart';
import 'package:holidays/features/leave/domain/leave_request.dart';
import 'package:holidays/features/leave/domain/leave_status.dart';
import 'package:logging/logging.dart';

class FailingRepository implements LeaveRepository {
  @override
  Future<void> cancel(String id) async => throw Exception('Cancel failed');

  @override
  Future<LeaveRequest> decide(String id, Decision d, String? comment) async =>
      throw Exception('Decide failed');

  @override
  Future<Uri> getAttachmentUrl(Attachment a) async =>
      throw Exception('URL failed');

  @override
  Future<LeaveRequest?> getById(String id) async =>
      throw Exception('getById failed');

  @override
  Future<List<LeaveRequest>> getHistoryFor(AppUser approver) async =>
      throw Exception('getHistoryFor failed');

  @override
  Future<List<LeaveRequest>> getMyRequests(String userId) async =>
      throw Exception('getMyRequests failed');

  @override
  Future<List<LeaveRequest>> getPendingFor(AppUser approver) async =>
      throw Exception('getPendingFor failed');

  @override
  Future<LeaveRequest> submit(
    NewLeaveRequest req,
    List<PickedAttachment> files,
  ) async =>
      throw Exception('submit failed');

  @override
  Stream<void> watchChanges() => const Stream.empty();
}

void main() {
  test('logs severe on failure and rethrows', () async {
    final records = <LogRecord>[];
    Logger.root.level = Level.ALL;
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);

    final repo = LoggingLeaveRepository(FailingRepository());
    await expectLater(repo.cancel('x'), throwsException);
    expect(records.any((r) => r.level == Level.SEVERE), true);
  });
}
