import 'leave_status.dart';

/// Persisted approval/rejection decision at a specific workflow stage.
/// Acts as the immutable audit trail and drives the UI timeline.
class LeaveApproval {
  final String id;
  final String requestId;
  final String approverId;
  final String approverName;
  final int stage; // 1 = Manager, 2 = HR
  final Decision decision;
  final String? comment;
  final DateTime decidedAt;

  const LeaveApproval({
    required this.id,
    required this.requestId,
    required this.approverId,
    required this.approverName,
    required this.stage,
    required this.decision,
    this.comment,
    required this.decidedAt,
  });

  String get stageLabel => stage == 1 ? 'Manager' : 'HR / Admin';

  factory LeaveApproval.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return LeaveApproval(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      approverId: json['approver_id'] as String,
      approverName: (json['approver_name'] as String?) ??
          (profile?['full_name'] as String?) ??
          'Approver',
      stage: (json['stage'] as num).toInt(),
      decision: Decision.fromString(json['decision'] as String),
      comment: json['comment'] as String?,
      decidedAt: json['decided_at'] != null
          ? DateTime.parse(json['decided_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'request_id': requestId,
        'approver_id': approverId,
        'approver_name': approverName,
        'stage': stage,
        'decision': decision.dbValue,
        'comment': comment,
        'decided_at': decidedAt.toIso8601String(),
      };
}
