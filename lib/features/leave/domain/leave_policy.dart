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

  /// Standard annual leave allocation (in working days) per [LeaveType].
  static int allocatedDaysFor(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return 18;
      case LeaveType.casual:
        return 8;
      case LeaveType.sick:
        return 10;
      case LeaveType.marriage:
        return 5;
      case LeaveType.bereavement:
        return 5;
      case LeaveType.unpaid:
        return 15;
    }
  }

  /// Computes a live [LeaveBalancePreview] for [leaveType] given the employee's
  /// [existingRequests] and the currently selected [requestedWorkingDays].
  static LeaveBalancePreview computeBalancePreview({
    required LeaveType leaveType,
    required List<LeaveRequest> existingRequests,
    required int requestedWorkingDays,
    int? year,
  }) {
    final allocated = allocatedDaysFor(leaveType);
    var used = 0;
    for (final req in existingRequests) {
      if (req.leaveType != leaveType) continue;
      if (req.status == LeaveStatus.rejected ||
          req.status == LeaveStatus.cancelled) {
        continue;
      }
      if (year == null ||
          req.startDate.year == year ||
          req.endDate.year == year) {
        used += req.totalDays;
      }
    }
    final remainingBefore = (allocated - used).clamp(0, allocated);
    final remainingAfter = remainingBefore - requestedWorkingDays;
    return LeaveBalancePreview(
      leaveType: leaveType,
      allocated: allocated,
      used: used,
      remainingBefore: remainingBefore,
      requestedDays: requestedWorkingDays,
      remainingAfter: remainingAfter,
    );
  }

  /// Returns a detailed [WorkingDayBreakdown] between [start] and [end],
  /// explaining how many weekend days and public holidays were skipped.
  static WorkingDayBreakdown explainWorkingDays(
    DateTime start,
    DateTime end, {
    Set<DateTime> holidays = const {},
    List<PublicHoliday>? namedHolidays,
  }) {
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    if (e.isBefore(s)) {
      return const WorkingDayBreakdown(
        workingDays: 0,
        weekendDaysSkipped: 0,
        holidaysSkipped: 0,
        skippedHolidayNames: [],
      );
    }

    final effectiveHolidays = namedHolidays ?? kDefaultPublicHolidays;
    final holidayNameByDate = <DateTime, String>{
      for (final h in effectiveHolidays) _dateOnly(h.date): h.name,
    };
    final normalizedHolidays = <DateTime>{
      ...holidays.map(_dateOnly),
      ...holidayNameByDate.keys,
    };

    var working = 0;
    var weekends = 0;
    var holidaysCount = 0;
    final skippedNames = <String>[];

    var cursor = s;
    while (!cursor.isAfter(e)) {
      final isWeekend =
          cursor.weekday == DateTime.saturday ||
          cursor.weekday == DateTime.sunday;
      if (isWeekend) {
        weekends++;
      } else if (normalizedHolidays.contains(cursor)) {
        holidaysCount++;
        final name = holidayNameByDate[cursor];
        if (name != null && !skippedNames.contains(name)) {
          skippedNames.add(name);
        }
      } else {
        working++;
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    return WorkingDayBreakdown(
      workingDays: working,
      weekendDaysSkipped: weekends,
      holidaysSkipped: holidaysCount,
      skippedHolidayNames: skippedNames,
    );
  }

  /// Finds overlapping active (pending or approved) leave requests from other
  /// teammates across `[target.startDate, target.endDate]`.
  static List<LeaveRequest> findTeamConflicts(
    LeaveRequest target,
    List<LeaveRequest> teamRequests,
  ) {
    final s = _dateOnly(target.startDate);
    final e = _dateOnly(target.endDate);
    final conflicts = <LeaveRequest>[];
    final seenIds = <String>{target.id};

    for (final req in teamRequests) {
      if (seenIds.contains(req.id)) continue;
      if (req.employeeId == target.employeeId) continue;
      if (req.status == LeaveStatus.rejected ||
          req.status == LeaveStatus.cancelled) {
        continue;
      }
      final reqStart = _dateOnly(req.startDate);
      final reqEnd = _dateOnly(req.endDate);
      if (!s.isAfter(reqEnd) && !e.isBefore(reqStart)) {
        seenIds.add(req.id);
        conflicts.add(req);
      }
    }
    return conflicts;
  }
}

/// Corporate / public holiday entry used by the smart date picker (`⭐ Smart date picker`).
class PublicHoliday {
  final DateTime date;
  final String name;

  const PublicHoliday({required this.date, required this.name});
}

/// Default Akasa Air / Indian corporate holiday calendar for 2026–2027.
final List<PublicHoliday> kDefaultPublicHolidays = [
  PublicHoliday(date: DateTime(2026, 1, 26), name: 'Republic Day'),
  PublicHoliday(date: DateTime(2026, 3, 4), name: 'Holi'),
  PublicHoliday(date: DateTime(2026, 5, 1), name: 'Maharashtra / Labour Day'),
  PublicHoliday(date: DateTime(2026, 8, 15), name: 'Independence Day'),
  PublicHoliday(date: DateTime(2026, 9, 14), name: 'Ganesh Chaturthi'),
  PublicHoliday(date: DateTime(2026, 10, 2), name: 'Gandhi Jayanti'),
  PublicHoliday(date: DateTime(2026, 10, 20), name: 'Dussehra'),
  PublicHoliday(date: DateTime(2026, 11, 24), name: 'Guru Nanak Jayanti'),
  PublicHoliday(date: DateTime(2026, 12, 25), name: 'Christmas Day'),
  PublicHoliday(date: DateTime(2027, 1, 1), name: 'New Year\'s Day'),
  PublicHoliday(date: DateTime(2027, 1, 26), name: 'Republic Day'),
  PublicHoliday(date: DateTime(2027, 3, 22), name: 'Holi'),
];

/// Detailed breakdown of working days vs skipped weekend/holiday days.
class WorkingDayBreakdown {
  final int workingDays;
  final int weekendDaysSkipped;
  final int holidaysSkipped;
  final List<String> skippedHolidayNames;

  const WorkingDayBreakdown({
    required this.workingDays,
    required this.weekendDaysSkipped,
    required this.holidaysSkipped,
    required this.skippedHolidayNames,
  });

  String get explanationText {
    final dayWord = workingDays == 1 ? 'working day' : 'working days';
    final skippedParts = <String>[];
    if (weekendDaysSkipped > 0) {
      skippedParts.add(
        '$weekendDaysSkipped weekend ${weekendDaysSkipped == 1 ? 'day' : 'days'} skipped',
      );
    }
    if (holidaysSkipped > 0) {
      final names = skippedHolidayNames.isNotEmpty
          ? ': ${skippedHolidayNames.join(', ')}'
          : '';
      skippedParts.add(
        '$holidaysSkipped public ${holidaysSkipped == 1 ? 'holiday' : 'holidays'} skipped$names',
      );
    }
    if (skippedParts.isEmpty) {
      return '$workingDays $dayWord (no weekends or holidays in range)';
    }
    return '$workingDays $dayWord (${skippedParts.join(' · ')})';
  }
}

/// Live preview of an employee's leave balance before and after a request.
class LeaveBalancePreview {
  final LeaveType leaveType;
  final int allocated;
  final int used;
  final int remainingBefore;
  final int requestedDays;
  final int remainingAfter;

  const LeaveBalancePreview({
    required this.leaveType,
    required this.allocated,
    required this.used,
    required this.remainingBefore,
    required this.requestedDays,
    required this.remainingAfter,
  });

  bool get exceedsBalance => remainingAfter < 0;
}

