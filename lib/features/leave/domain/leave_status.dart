/// Lifecycle states of a leave request.
enum LeaveStatus {
  pendingManager('pending_manager', 'Pending Manager'),
  pendingHr('pending_hr', 'Pending HR'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  cancelled('cancelled', 'Cancelled');

  final String dbValue;
  final String label;
  const LeaveStatus(this.dbValue, this.label);

  bool get isPending =>
      this == LeaveStatus.pendingManager || this == LeaveStatus.pendingHr;

  bool get isFinalised =>
      this == LeaveStatus.approved ||
      this == LeaveStatus.rejected ||
      this == LeaveStatus.cancelled;

  static LeaveStatus fromString(String value) {
    return LeaveStatus.values.firstWhere(
      (s) => s.dbValue == value || s.name == value,
      orElse: () => LeaveStatus.pendingManager,
    );
  }
}

/// Categories of employee leave.
enum LeaveType {
  annual('annual', 'Annual Leave'),
  sick('sick', 'Sick Leave'),
  casual('casual', 'Casual Leave'),
  unpaid('unpaid', 'Unpaid Leave'),
  marriage('marriage', 'Marriage Leave'),
  bereavement('bereavement', 'Bereavement Leave');

  final String dbValue;
  final String label;
  const LeaveType(this.dbValue, this.label);

  static LeaveType fromString(String value) {
    return LeaveType.values.firstWhere(
      (t) => t.dbValue == value || t.name == value,
      orElse: () => LeaveType.annual,
    );
  }
}

/// Approver decision on a pending leave request.
enum Decision {
  approve('approved', 'Approve'),
  reject('rejected', 'Reject');

  final String dbValue;
  final String label;
  const Decision(this.dbValue, this.label);

  static Decision fromString(String value) {
    if (value == 'rejected' || value == 'reject') return Decision.reject;
    return Decision.approve;
  }
}
