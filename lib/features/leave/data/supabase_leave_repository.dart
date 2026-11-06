import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/domain/app_user.dart';
import '../domain/attachment.dart';
import '../domain/attachment_policy.dart';
import '../domain/leave_policy.dart';
import '../domain/leave_request.dart';
import '../domain/leave_status.dart';
import 'leave_repository.dart';

/// Supabase/Postgres implementation of [LeaveRepository].
///
/// Matches the schema and RPCs deployed from
/// `supabase/migrations/20261106080000_initial_leave_schema.sql` (`submit_leave`,
/// `decide_leave`, `cancel_leave`) and private bucket `leave-attachments`.
class SupabaseLeaveRepository implements LeaveRepository {
  SupabaseLeaveRepository(this._client);

  final SupabaseClient _client;

  static const String _bucketName = 'leave-attachments';
  static const String _selectQuery = '''
    *,
    profiles!leave_requests_employee_id_fkey(full_name, manager_id),
    leave_approvals(*, profiles(full_name)),
    leave_attachments(*)
  ''';

  static String _generateUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  @override
  Future<List<LeaveRequest>> getMyRequests(String userId) async {
    try {
      final rows = await _client
          .from('leave_requests')
          .select(_selectQuery)
          .eq('employee_id', userId)
          .order('created_at', ascending: false);

      return (rows as List<dynamic>)
          .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapToAppException(e);
    }
  }

  @override
  Future<List<LeaveRequest>> getPendingFor(AppUser approver) async {
    try {
      final targetStatus = approver.role == Role.hr
          ? LeaveStatus.pendingHr.dbValue
          : LeaveStatus.pendingManager.dbValue;

      final rows = await _client
          .from('leave_requests')
          .select(_selectQuery)
          .eq('status', targetStatus)
          .order('created_at', ascending: false);

      return (rows as List<dynamic>)
          .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapToAppException(e);
    }
  }

  @override
  Future<List<LeaveRequest>> getHistoryFor(AppUser approver) async {
    try {
      final rows = await _client
          .from('leave_requests')
          .select(_selectQuery)
          .order('updated_at', ascending: false);

      return (rows as List<dynamic>)
          .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapToAppException(e);
    }
  }

  @override
  Future<LeaveRequest?> getById(String id) async {
    try {
      final row = await _client
          .from('leave_requests')
          .select(_selectQuery)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return LeaveRequest.fromJson(row);
    } catch (e) {
      throw mapToAppException(e);
    }
  }

  @override
  Future<LeaveRequest> submit(
    NewLeaveRequest req,
    List<PickedAttachment> files,
  ) async {
    final workingDays = LeavePolicy.countWorkingDays(req.startDate, req.endDate);
    final proofReq = AttachmentPolicy.proofRequirement(
      req.leaveType,
      workingDays,
    );
    final validationErr = AttachmentPolicy.validateSet(files, proofReq);
    if (validationErr != null) {
      throw ValidationException(validationErr);
    }

    try {
      final requestId = _generateUuidV4();
      final attachmentPayloads = <Map<String, dynamic>>[];

      // 1. Upload files to private storage bucket before inserting DB rows.
      // Path starts with `{employeeId}/` to satisfy storage RLS policies.
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final fileUuid = _generateUuidV4();
        final path = '${req.employeeId}/$requestId/${fileUuid}_${f.name}';
        await _client.storage.from(_bucketName).uploadBinary(
              path,
              f.bytes,
              fileOptions: FileOptions(contentType: f.mimeType),
            );
        attachmentPayloads.add({
          'file_name': f.name,
          'storage_path': path,
          'mime_type': f.mimeType,
          'size_bytes': f.sizeBytes,
        });
      }

      // 2. Atomic RPC call to insert request and attachment metadata together.
      final res = await _client.rpc(
        'submit_leave',
        params: {
          'p_id': requestId,
          'p_leave_type': req.leaveType.dbValue,
          'p_start_date': req.startDate.toIso8601String().split('T').first,
          'p_end_date': req.endDate.toIso8601String().split('T').first,
          'p_reason': req.reason.trim(),
          'p_attachments': attachmentPayloads,
        },
      );

      return LeaveRequest.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      if (e is StorageException) {
        throw AppException('Upload failed, retry.', cause: e);
      }
      throw mapToAppException(e);
    }
  }

  @override
  Future<LeaveRequest> decide(
    String id,
    Decision d,
    String? comment,
  ) async {
    if (d == Decision.reject && (comment == null || comment.trim().isEmpty)) {
      throw const ValidationException(
        'A comment is required when rejecting a leave request.',
      );
    }

    try {
      final res = await _client.rpc(
        'decide_leave',
        params: {
          'request_id': id,
          'decision': d.dbValue,
          'comment': comment?.trim(),
        },
      );
      return LeaveRequest.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      throw mapToAppException(e);
    }
  }

  @override
  Future<void> cancel(String id) async {
    try {
      await _client.rpc('cancel_leave', params: {'request_id': id});
    } catch (e) {
      throw mapToAppException(e);
    }
  }

  @override
  Future<Uri> getAttachmentUrl(Attachment a) async {
    try {
      final signed = await _client.storage
          .from(_bucketName)
          .createSignedUrl(a.storagePath, 60);
      return Uri.parse(signed);
    } catch (e) {
      throw mapToAppException(e);
    }
  }
}
