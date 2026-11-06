import 'package:flutter_test/flutter_test.dart';
import 'package:holidays/core/errors/app_exception.dart';
import 'package:holidays/features/auth/data/auth_repository.dart';
import 'package:holidays/features/leave/data/in_memory_leave_repository.dart';
import 'package:holidays/features/leave/domain/leave_request.dart';
import 'package:holidays/features/leave/domain/leave_status.dart';

NewLeaveRequest newRequest({
  required int days,
  String employeeId = 'usr-emp-1',
  LeaveType type = LeaveType.annual,
  DateTime? start,
}) {
  final startDate = start ?? DateTime(2026, 11, 9); // Monday 9 Nov 2026
  // Advance working days
  var cursor = startDate;
  var remaining = days - 1;
  while (remaining > 0) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    if (cursor.weekday != DateTime.saturday &&
        cursor.weekday != DateTime.sunday) {
      remaining--;
    }
  }
  return NewLeaveRequest(
    employeeId: employeeId,
    leaveType: type,
    startDate: startDate,
    endDate: cursor,
    reason: 'Scheduled personal leave request for testing.',
  );
}

void main() {
  const hrUser = DemoUsers.hr;
  const managerUser = DemoUsers.manager;

  test(
    'long leave goes manager -> HR -> approved, and records both approvals',
    () async {
      final repo = InMemoryLeaveRepository.seeded();
      final r = await repo.submit(newRequest(days: 5), []);
      expect(r.status, LeaveStatus.pendingManager);
      expect(r.requiresSecondApproval, true);

      final afterMgr = await repo.decide(
        r.id,
        Decision.approve,
        'Enjoy',
      ); // acting as manager
      expect(afterMgr.status, LeaveStatus.pendingHr);

      repo.actAs(hrUser);
      final done = await repo.decide(r.id, Decision.approve, null);
      expect(done.status, LeaveStatus.approved);
      expect(done.approvals.length, 2);
      expect(done.approvals[0].stage, 1);
      expect(done.approvals[1].stage, 2);
    },
  );

  test('short leave (<= 3 days) is fully approved by manager in one stage', () async {
    final repo = InMemoryLeaveRepository.seeded();
    final r = await repo.submit(newRequest(days: 3), []);
    expect(r.status, LeaveStatus.pendingManager);
    expect(r.requiresSecondApproval, false);

    final done = await repo.decide(r.id, Decision.approve, 'Approved!');
    expect(done.status, LeaveStatus.approved);
    expect(done.approvals.length, 1);
  });

  test('rejecting without a comment throws ValidationException', () async {
    final repo = InMemoryLeaveRepository.seeded();
    final r = await repo.submit(newRequest(days: 2), []);

    await expectLater(
      repo.decide(r.id, Decision.reject, '   '),
      throwsA(isA<ValidationException>()),
    );
  });

  test('manager cannot approve own request', () async {
    final repo = InMemoryLeaveRepository.seeded();
    repo.actAs(managerUser);
    final r = await repo.submit(
      newRequest(days: 2, employeeId: managerUser.id),
      [],
    );
    // Manager's own leave routes straight to HR
    expect(r.status, LeaveStatus.pendingHr);

    await expectLater(
      repo.decide(r.id, Decision.approve, 'Self approve'),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('submit fails when proof is required and missing', () async {
    final repo = InMemoryLeaveRepository.seeded();
    await expectLater(
      repo.submit(newRequest(days: 3, type: LeaveType.sick), []),
      throwsA(isA<ValidationException>()),
    );
  });

  test('cancel only allowed while pending', () async {
    final repo = InMemoryLeaveRepository.seeded();
    final r = await repo.submit(newRequest(days: 2), []);

    final approved = await repo.decide(r.id, Decision.approve, 'OK');
    expect(approved.status, LeaveStatus.approved);

    await expectLater(
      repo.cancel(r.id),
      throwsA(isA<ValidationException>()),
    );
  });
}
