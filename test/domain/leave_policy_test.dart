import 'package:flutter_test/flutter_test.dart';
import 'package:holidays/features/auth/domain/app_user.dart';
import 'package:holidays/features/leave/domain/leave_policy.dart';
import 'package:holidays/features/leave/domain/leave_request.dart';
import 'package:holidays/features/leave/domain/leave_status.dart';

LeaveRequest req(DateTime start, DateTime end, LeaveStatus status) {
  return LeaveRequest(
    id: 'req-test',
    employeeId: 'usr-emp-1',
    leaveType: LeaveType.annual,
    startDate: start,
    endDate: end,
    totalDays: LeavePolicy.countWorkingDays(start, end),
    reason: 'Family holiday trip',
    status: status,
    requiresSecondApproval: false,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );
}

void main() {
  group('countWorkingDays', () {
    test('single weekday = 1', () {
      expect(
        LeavePolicy.countWorkingDays(
          DateTime(2026, 11, 9),
          DateTime(2026, 11, 9),
        ),
        1,
      );
    });

    test('Mon-Fri = 5', () {
      expect(
        LeavePolicy.countWorkingDays(
          DateTime(2026, 11, 9),
          DateTime(2026, 11, 13),
        ),
        5,
      );
    });

    test('weekend only = 0', () {
      expect(
        LeavePolicy.countWorkingDays(
          DateTime(2026, 11, 7),
          DateTime(2026, 11, 8),
        ),
        0,
      );
    });

    test('Fri to Mon skips the weekend = 2', () {
      expect(
        LeavePolicy.countWorkingDays(
          DateTime(2026, 11, 6),
          DateTime(2026, 11, 9),
        ),
        2,
      );
    });

    test('holidays are excluded', () {
      final h = {DateTime(2026, 11, 10)};
      expect(
        LeavePolicy.countWorkingDays(
          DateTime(2026, 11, 9),
          DateTime(2026, 11, 11),
          holidays: h,
        ),
        2,
      );
    });
  });

  group('approval rule (boundary)', () {
    test('3 days -> single approval', () {
      expect(LeavePolicy.requiresSecondApproval(3), false);
    });

    test('4 days -> two-stage', () {
      expect(LeavePolicy.requiresSecondApproval(4), true);
    });
  });

  group('initialStatus', () {
    test('employee short leave -> pendingManager', () {
      expect(
        LeavePolicy.initialStatus(Role.employee, 2),
        LeaveStatus.pendingManager,
      );
    });

    test('manager own leave routes straight to HR', () {
      expect(
        LeavePolicy.initialStatus(Role.manager, 2),
        LeaveStatus.pendingHr,
      );
    });
  });

  group('nextStatus (state machine)', () {
    test('manager approves long leave -> pendingHr', () {
      expect(
        LeavePolicy.nextStatus(
          LeaveStatus.pendingManager,
          Decision.approve,
          true,
        ),
        LeaveStatus.pendingHr,
      );
    });

    test('manager approves short leave -> approved', () {
      expect(
        LeavePolicy.nextStatus(
          LeaveStatus.pendingManager,
          Decision.approve,
          false,
        ),
        LeaveStatus.approved,
      );
    });

    test('HR approves -> approved', () {
      expect(
        LeavePolicy.nextStatus(
          LeaveStatus.pendingHr,
          Decision.approve,
          true,
        ),
        LeaveStatus.approved,
      );
    });

    test('reject at any stage -> rejected', () {
      for (final s in [LeaveStatus.pendingManager, LeaveStatus.pendingHr]) {
        expect(
          LeavePolicy.nextStatus(s, Decision.reject, true),
          LeaveStatus.rejected,
        );
      }
    });

    test('finalised requests cannot be decided', () {
      for (final s in [
        LeaveStatus.approved,
        LeaveStatus.rejected,
        LeaveStatus.cancelled,
      ]) {
        expect(
          () => LeavePolicy.nextStatus(s, Decision.approve, false),
          throwsStateError,
        );
      }
    });
  });

  group('overlap', () {
    final existing = [
      req(DateTime(2026, 11, 10), DateTime(2026, 11, 12), LeaveStatus.approved),
    ];

    test('overlapping range detected', () {
      expect(
        LeavePolicy.hasOverlap(
          DateTime(2026, 11, 12),
          DateTime(2026, 11, 14),
          existing,
        ),
        true,
      );
    });

    test('adjacent range is fine', () {
      expect(
        LeavePolicy.hasOverlap(
          DateTime(2026, 11, 13),
          DateTime(2026, 11, 14),
          existing,
        ),
        false,
      );
    });

    test('rejected/cancelled requests are ignored', () {
      final dead = [
        req(
          DateTime(2026, 11, 10),
          DateTime(2026, 11, 12),
          LeaveStatus.rejected,
        ),
      ];
      expect(
        LeavePolicy.hasOverlap(
          DateTime(2026, 11, 10),
          DateTime(2026, 11, 11),
          dead,
        ),
        false,
      );
    });
  });
}
