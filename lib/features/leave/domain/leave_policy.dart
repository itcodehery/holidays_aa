import '../../../core/config/app_config.dart';
import '../../auth/domain/app_user.dart';
import 'leave_request.dart';
import 'leave_status.dart';

/// Pure Dart business rules for leave requests: working-day counting,
/// multi-stage approval threshold, state machine transitions, and date overlap.
class LeavePolicy {
  const LeavePolicy._();

  /// Normalizes a [DateTime] to local midnight (`yyyy-MM-dd`).
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Counts working days (Monday–Friday) between [start] and [end], inclusive,
  /// excluding any dates present in [holidays].
  static int countWorkingDays(
    DateTime start,
    DateTime end, {
    Set<DateTime> holidays = const {},
  }) {
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    if (e.isBefore(s)) return 0;

    final normalizedHolidays = holidays.map(_dateOnly).toSet();
    var count = 0;
    var cursor = s;
    while (!cursor.isAfter(e)) {
      final isWeekend =
          cursor.weekday == DateTime.saturday ||
          cursor.weekday == DateTime.sunday;
      if (!isWeekend && !normalizedHolidays.contains(cursor)) {
        count++;
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return count;
  }

  /// Returns `true` when [workingDays] exceeds [kMultiApprovalThreshold] (3),
  /// triggering two-stage approval (Manager -> HR/Admin).
  static bool requiresSecondApproval(int workingDays) {
    return workingDays > kMultiApprovalThreshold;
  }

  /// Determines the initial status of a newly submitted leave request.
  /// If a manager (or HR) applies for their own leave, it routes straight to HR.
  static LeaveStatus initialStatus(Role applicantRole, int workingDays) {
    if (applicantRole == Role.manager || applicantRole == Role.hr) {
      return LeaveStatus.pendingHr;
    }
    return LeaveStatus.pendingManager;
  }

  /// State machine transition for an approval or rejection decision.
  /// Throws [StateError] if [current] is already finalised.
  static LeaveStatus nextStatus(
    LeaveStatus current,
    Decision decision,
    bool requiresSecondApproval,
  ) {
    if (current.isFinalised) {
      throw StateError(
        'Cannot decide a request that is already ${current.label}.',
      );
    }

    if (decision == Decision.reject) {
      return LeaveStatus.rejected;
    }

    switch (current) {
      case LeaveStatus.pendingManager:
        return requiresSecondApproval
            ? LeaveStatus.pendingHr
            : LeaveStatus.approved;
      case LeaveStatus.pendingHr:
        return LeaveStatus.approved;
      case LeaveStatus.approved:
      case LeaveStatus.rejected:
      case LeaveStatus.cancelled:
        throw StateError('Request is already finalised.');
    }
  }

  /// Checks whether the inclusive date range `[start, end]` overlaps with any
  /// existing non-rejected, non-cancelled request in [existing].
  static bool hasOverlap(
    DateTime start,
    DateTime end,
    List<LeaveRequest> existing,
  ) {
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    for (final req in existing) {
      if (req.status == LeaveStatus.rejected ||
          req.status == LeaveStatus.cancelled) {
        continue;
      }
      final reqStart = _dateOnly(req.startDate);
      final reqEnd = _dateOnly(req.endDate);
      // Two inclusive ranges [s, e] and [reqStart, reqEnd] overlap iff
      // s <= reqEnd && e >= reqStart.
      if (!s.isAfter(reqEnd) && !e.isBefore(reqStart)) {
        return true;
      }
    }
    return false;
  }

  /// Validates the leave reason (mandatory, at least 10 characters).
  static String? validateReason(String? reason) {
    final trimmed = reason?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Please enter a reason for your leave.';
    }
    if (trimmed.length < 10) {
      return 'Reason must be at least 10 characters long.';
    }
    return null;
  }

  /// Validates start and end dates, ensuring end >= start, start is not in the
  /// past (relative to [today] if provided), and working days > 0.
  static String? validateDates(
    DateTime? start,
    DateTime? end, {
    DateTime? today,
    Set<DateTime> holidays = const {},
  }) {
    if (start == null || end == null) {
      return 'Please select both start and end dates.';
    }
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    if (e.isBefore(s)) {
      return 'End date cannot be before start date.';
    }
    if (today != null) {
      final t = _dateOnly(today);
      if (s.isBefore(t)) {
        return 'Start date cannot be in the past.';
      }
    }
    final workingDays = countWorkingDays(s, e, holidays: holidays);
    if (workingDays <= 0) {
      return 'Selected range contains 0 working days (weekends/holidays only).';
    }
    return null;
  }

  /// Validates whether [approver] is authorized to decide [request] at its
  /// current stage. Returns `null` if allowed, or an error message if not.
  static String? validateDecisionPermission(
    AppUser approver,
    LeaveRequest request,
  ) {
    if (request.status.isFinalised) {
      return 'This leave request has already been ${request.status.label.toLowerCase()}.';
    }
    if (request.employeeId == approver.id) {
      return 'You cannot approve or reject your own leave request.';
    }
    if (request.status == LeaveStatus.pendingManager) {
      if (approver.role != Role.manager) {
        return 'Only the direct manager can decide a Stage 1 request.';
      }
      if (request.managerId != null && request.managerId != approver.id) {
        return 'You can only decide requests for your direct reports.';
      }
      return null;
    }
    if (request.status == LeaveStatus.pendingHr) {
      if (approver.role != Role.hr) {
        return 'Only HR/Admin can decide a Stage 2 (Pending HR) request.';
      }
      return null;
    }
    return 'Request is not in a decidable state.';
  }
}
