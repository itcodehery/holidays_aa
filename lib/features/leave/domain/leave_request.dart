import 'attachment.dart';
import 'leave_approval.dart';
import 'leave_status.dart';

/// Value object representing a new leave request prior to persistence.
class NewLeaveRequest {
  final String employeeId;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;

  const NewLeaveRequest({
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
  });
}

/// Complete domain entity for an employee leave request, including its
/// approval timeline and uploaded attachment metadata.
class LeaveRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String? managerId;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String reason;
  final LeaveStatus status;
  final bool requiresSecondApproval;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<LeaveApproval> approvals;
  final List<Attachment> attachments;

  const LeaveRequest({
    required this.id,
    required this.employeeId,
    this.employeeName = 'Employee',
    this.managerId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    required this.status,
    required this.requiresSecondApproval,
    required this.createdAt,
    required this.updatedAt,
    this.approvals = const [],
    this.attachments = const [],
  });

  /// Returns the current approval stage number (1 for Manager, 2 for HR).
  int get currentStage => status == LeaveStatus.pendingHr ? 2 : 1;

  LeaveRequest copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? managerId,
    LeaveType? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    int? totalDays,
    String? reason,
    LeaveStatus? status,
    bool? requiresSecondApproval,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<LeaveApproval>? approvals,
    List<Attachment>? attachments,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      managerId: managerId ?? this.managerId,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalDays: totalDays ?? this.totalDays,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      requiresSecondApproval:
          requiresSecondApproval ?? this.requiresSecondApproval,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvals: approvals ?? this.approvals,
      attachments: attachments ?? this.attachments,
    );
  }

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final rawApprovals = (json['leave_approvals'] as List<dynamic>?) ?? const [];
    final rawAttachments =
        (json['leave_attachments'] as List<dynamic>?) ?? const [];

    final approvals = rawApprovals
        .map((e) => LeaveApproval.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.stage.compareTo(b.stage));

    final attachments = rawAttachments
        .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
        .toList();

    return LeaveRequest(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      employeeName: (json['employee_name'] as String?) ??
          (profile?['full_name'] as String?) ??
          'Employee',
      managerId:
          (json['manager_id'] as String?) ?? (profile?['manager_id'] as String?),
      leaveType: LeaveType.fromString(json['leave_type'] as String),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      totalDays: (json['total_days'] as num).toInt(),
      reason: json['reason'] as String,
      status: LeaveStatus.fromString(json['status'] as String),
      requiresSecondApproval:
          (json['requires_second_approval'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      approvals: approvals,
      attachments: attachments,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'manager_id': managerId,
        'leave_type': leaveType.dbValue,
        'start_date': _dateIso(startDate),
        'end_date': _dateIso(endDate),
        'total_days': totalDays,
        'reason': reason,
        'status': status.dbValue,
        'requires_second_approval': requiresSecondApproval,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static String _dateIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
