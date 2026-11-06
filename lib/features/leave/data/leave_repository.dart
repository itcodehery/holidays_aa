import '../../auth/domain/app_user.dart';
import '../domain/attachment.dart';
import '../domain/leave_request.dart';
import '../domain/leave_status.dart';

/// Repository contract for leave request persistence and attachment storage.
///
/// The presentation layer interacts exclusively with this interface. Concrete
/// implementations ([InMemoryLeaveRepository], [SupabaseLeaveRepository]) can
/// be swapped with a single Riverpod provider override.
abstract class LeaveRepository {
  /// Returns all leave requests submitted by [userId], newest first.
  Future<List<LeaveRequest>> getMyRequests(String userId);

  /// Returns requests awaiting a decision from [approver] at their stage:
  /// - Manager: direct reports' requests in [LeaveStatus.pendingManager]
  /// - HR: any request in [LeaveStatus.pendingHr]
  Future<List<LeaveRequest>> getPendingFor(AppUser approver);

  /// Returns historical / already-decided requests visible to [approver].
  Future<List<LeaveRequest>> getHistoryFor(AppUser approver);

  /// Fetches a single leave request by [id].
  Future<LeaveRequest?> getById(String id);

  /// Submits a new leave request and uploads its [files] atomically.
  Future<LeaveRequest> submit(
    NewLeaveRequest req,
    List<PickedAttachment> files,
  );

  /// Records an approval or rejection decision at the current stage and
  /// transitions the request status.
  Future<LeaveRequest> decide(String id, Decision d, String? comment);

  /// Cancels a pending leave request.
  Future<void> cancel(String id);

  /// Generates a short-lived signed URI (or in-memory data URI) to view [a].
  Future<Uri> getAttachmentUrl(Attachment a);
}
