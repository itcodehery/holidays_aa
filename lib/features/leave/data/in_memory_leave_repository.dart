import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../domain/attachment.dart';
import '../domain/attachment_policy.dart';
import '../domain/leave_approval.dart';
import '../domain/leave_policy.dart';
import '../domain/leave_request.dart';
import '../domain/leave_status.dart';
import 'leave_repository.dart';

/// In-memory implementation of [LeaveRepository] with full domain validation,
/// binary attachment storage, and optional demo seed data.
class InMemoryLeaveRepository implements LeaveRepository {
  InMemoryLeaveRepository({
    List<LeaveRequest>? initialRequests,
    Map<String, Uint8List>? initialBlobs,
    this.currentUserResolver,
  }) : _requests = List<LeaveRequest>.from(initialRequests ?? const []),
       _blobs = Map<String, Uint8List>.from(initialBlobs ?? const {});

  /// Creates an instance pre-populated with realistic requests and attachments
  /// across employee, manager, and HR stages.
  factory InMemoryLeaveRepository.seeded({
    AppUser? Function()? currentUserResolver,
  }) {
    final samplePdfBytes = Uint8List.fromList(
      utf8.encode('%PDF-1.4 Sample supporting document'),
    );
    // Minimal 1x1 transparent PNG
    final samplePngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );

    final blobs = <String, Uint8List>{
      'leave-attachments/usr-emp-1/req-seed-2/medical_certificate.png':
          samplePngBytes,
      'leave-attachments/usr-emp-2/req-seed-4/wedding_invitation.pdf':
          samplePdfBytes,
    };

    final seededRequests = <LeaveRequest>[
      // 1. Short casual leave (2 days) - Pending Manager (Stage 1)
      LeaveRequest(
        id: 'req-seed-1',
        employeeId: DemoUsers.employee.id,
        employeeName: DemoUsers.employee.fullName,
        managerId: DemoUsers.manager.id,
        leaveType: LeaveType.casual,
        startDate: DateTime(2026, 12, 14),
        endDate: DateTime(2026, 12, 15),
        totalDays: 2,
        reason: 'Attending a family event out of town for two days.',
        status: LeaveStatus.pendingManager,
        requiresSecondApproval: false,
        createdAt: DateTime(2026, 10, 28, 9, 30),
        updatedAt: DateTime(2026, 10, 28, 9, 30),
      ),
      // 2. Long annual leave (5 working days) - Approved by Manager, now Pending HR (Stage 2)
      LeaveRequest(
        id: 'req-seed-2',
        employeeId: DemoUsers.employee.id,
        employeeName: DemoUsers.employee.fullName,
        managerId: DemoUsers.manager.id,
        leaveType: LeaveType.sick,
        startDate: DateTime(2026, 10, 19),
        endDate: DateTime(2026, 10, 23),
        totalDays: 5,
        reason:
            'Post-procedure recovery advised by physician for a full work week.',
        status: LeaveStatus.pendingHr,
        requiresSecondApproval: true,
        createdAt: DateTime(2026, 10, 15, 10, 0),
        updatedAt: DateTime(2026, 10, 16, 14, 20),
        approvals: [
          LeaveApproval(
            id: 'apr-seed-1',
            requestId: 'req-seed-2',
            approverId: DemoUsers.manager.id,
            approverName: DemoUsers.manager.fullName,
            stage: 1,
            decision: Decision.approve,
            comment: 'Wishing you a speedy recovery. Forwarding to HR.',
            decidedAt: DateTime(2026, 10, 16, 14, 20),
          ),
        ],
        attachments: [
          Attachment(
            id: 'att-seed-1',
            requestId: 'req-seed-2',
            fileName: 'medical_certificate.png',
            storagePath:
                'leave-attachments/usr-emp-1/req-seed-2/medical_certificate.png',
            mimeType: 'image/png',
            sizeBytes: samplePngBytes.lengthInBytes,
            uploadedAt: DateTime(2026, 10, 15, 10, 0),
          ),
        ],
      ),
      // 3. Completed short leave - Approved
      LeaveRequest(
        id: 'req-seed-3',
        employeeId: DemoUsers.employee.id,
        employeeName: DemoUsers.employee.fullName,
        managerId: DemoUsers.manager.id,
        leaveType: LeaveType.annual,
        startDate: DateTime(2026, 10, 5),
        endDate: DateTime(2026, 10, 6),
        totalDays: 2,
        reason: 'Taking a short autumn break with family.',
        status: LeaveStatus.approved,
        requiresSecondApproval: false,
        createdAt: DateTime(2026, 10, 1, 11, 15),
        updatedAt: DateTime(2026, 10, 2, 9, 0),
        approvals: [
          LeaveApproval(
            id: 'apr-seed-2',
            requestId: 'req-seed-3',
            approverId: DemoUsers.manager.id,
            approverName: DemoUsers.manager.fullName,
            stage: 1,
            decision: Decision.approve,
            comment: 'Enjoy your time off!',
            decidedAt: DateTime(2026, 10, 2, 9, 0),
          ),
        ],
      ),
      // 4. Second employee marriage leave (5 working days) - Pending Manager
      LeaveRequest(
        id: 'req-seed-4',
        employeeId: DemoUsers.employee2.id,
        employeeName: DemoUsers.employee2.fullName,
        managerId: DemoUsers.manager.id,
        leaveType: LeaveType.marriage,
        startDate: DateTime(2026, 12, 7),
        endDate: DateTime(2026, 12, 11),
        totalDays: 5,
        reason: 'Marriage ceremony and family celebrations in Jaipur.',
        status: LeaveStatus.pendingManager,
        requiresSecondApproval: true,
        createdAt: DateTime(2026, 10, 25, 16, 45),
        updatedAt: DateTime(2026, 10, 25, 16, 45),
        attachments: [
          Attachment(
            id: 'att-seed-2',
            requestId: 'req-seed-4',
            fileName: 'wedding_invitation.pdf',
            storagePath:
                'leave-attachments/usr-emp-2/req-seed-4/wedding_invitation.pdf',
            mimeType: 'application/pdf',
            sizeBytes: samplePdfBytes.lengthInBytes,
            uploadedAt: DateTime(2026, 10, 25, 16, 45),
          ),
        ],
      ),
    ];

    return InMemoryLeaveRepository(
      initialRequests: seededRequests,
      initialBlobs: blobs,
      currentUserResolver: currentUserResolver,
    );
  }

  final List<LeaveRequest> _requests;
  final Map<String, Uint8List> _blobs;
  final AppUser? Function()? currentUserResolver;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  AppUser? _actingUser;
  int _idCounter = 100;

  /// Overrides the active user context for repository operations (useful in
  /// unit tests to switch between employee, manager, and HR roles).
  void actAs(AppUser user) {
    _actingUser = user;
  }

  AppUser get _effectiveActor =>
      _actingUser ?? currentUserResolver?.call() ?? DemoUsers.manager;

  String _nextId(String prefix) {
    _idCounter++;
    return '$prefix-$_idCounter';
  }

  @override
  Future<List<LeaveRequest>> getMyRequests(String userId) async {
    final list = _requests.where((r) => r.employeeId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<LeaveRequest>> getPendingFor(AppUser approver) async {
    if (approver.role == Role.manager) {
      final list = _requests
          .where(
            (r) =>
                r.status == LeaveStatus.pendingManager &&
                r.employeeId != approver.id &&
                (r.managerId == null || r.managerId == approver.id),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    if (approver.role == Role.hr) {
      final list = _requests
          .where(
            (r) =>
                r.status == LeaveStatus.pendingHr &&
                r.employeeId != approver.id,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    return const [];
  }

  @override
  Future<List<LeaveRequest>> getHistoryFor(AppUser approver) async {
    if (approver.role == Role.hr) {
      final list = List<LeaveRequest>.from(_requests)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }
    if (approver.role == Role.manager) {
      final list = _requests
          .where(
            (r) =>
                r.managerId == approver.id ||
                r.approvals.any((a) => a.approverId == approver.id),
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }
    return getMyRequests(approver.id);
  }

  @override
  Future<LeaveRequest?> getById(String id) async {
    for (final r in _requests) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<LeaveRequest> submit(
    NewLeaveRequest req,
    List<PickedAttachment> files,
  ) async {
    final dateErr = LeavePolicy.validateDates(req.startDate, req.endDate);
    if (dateErr != null) {
      throw ValidationException(dateErr);
    }

    final reasonErr = LeavePolicy.validateReason(req.reason);
    if (reasonErr != null) {
      throw ValidationException(reasonErr);
    }

    final workingDays = LeavePolicy.countWorkingDays(req.startDate, req.endDate);
    final proofReq = AttachmentPolicy.proofRequirement(
      req.leaveType,
      workingDays,
    );
    final fileErr = AttachmentPolicy.validateSet(files, proofReq);
    if (fileErr != null) {
      throw ValidationException(fileErr);
    }

    final existingForUser =
        _requests.where((r) => r.employeeId == req.employeeId).toList();
    if (LeavePolicy.hasOverlap(req.startDate, req.endDate, existingForUser)) {
      throw const ValidationException(
        'This date range overlaps with an existing pending or approved leave request.',
      );
    }

    final applicant = DemoUsers.byId(req.employeeId) ??
        (_actingUser?.id == req.employeeId ? _actingUser : null) ??
        AppUser(
          id: req.employeeId,
          email: 'employee@company.com',
          fullName: 'Alex Rivera',
          role: Role.employee,
          managerId: DemoUsers.manager.id,
        );

    final requestId = _nextId('req');
    final now = DateTime.now();

    // 1. Upload files to in-memory blob map first (matching Supabase sequence)
    final uploadedAttachments = <Attachment>[];
    for (final file in files) {
      final attId = _nextId('att');
      final path =
          'leave-attachments/${req.employeeId}/$requestId/${attId}_${file.name}';
      _blobs[path] = file.bytes;
      uploadedAttachments.add(
        Attachment(
          id: attId,
          requestId: requestId,
          fileName: file.name,
          storagePath: path,
          mimeType: file.mimeType,
          sizeBytes: file.sizeBytes,
          uploadedAt: now,
        ),
      );
    }

    // 2. Insert request and attachments atomically
    final initialStatus = LeavePolicy.initialStatus(
      applicant.role,
      workingDays,
    );
    final needsSecond = LeavePolicy.requiresSecondApproval(workingDays);

    final created = LeaveRequest(
      id: requestId,
      employeeId: applicant.id,
      employeeName: applicant.fullName,
      managerId: applicant.managerId ?? DemoUsers.manager.id,
      leaveType: req.leaveType,
      startDate: DateTime(
        req.startDate.year,
        req.startDate.month,
        req.startDate.day,
      ),
      endDate: DateTime(req.endDate.year, req.endDate.month, req.endDate.day),
      totalDays: workingDays,
      reason: req.reason.trim(),
      status: initialStatus,
      requiresSecondApproval: needsSecond,
      createdAt: now,
      updatedAt: now,
      approvals: const [],
      attachments: uploadedAttachments,
    );

    _requests.insert(0, created);
    _changes.add(null);
    return created;
  }

  @override
  Future<LeaveRequest> decide(
    String id,
    Decision d,
    String? comment,
  ) async {
    final index = _requests.indexWhere((r) => r.id == id);
    if (index == -1) {
      throw const NotFoundException('Leave request not found.');
    }

    final current = _requests[index];
    final actor = _effectiveActor;

    final permErr = LeavePolicy.validateDecisionPermission(actor, current);
    if (permErr != null) {
      throw UnauthorizedException(permErr);
    }

    final trimmedComment = comment?.trim();
    if (d == Decision.reject &&
        (trimmedComment == null || trimmedComment.isEmpty)) {
      throw const ValidationException(
        'A comment is required when rejecting a leave request.',
      );
    }

    final stage = current.status == LeaveStatus.pendingManager ? 1 : 2;
    if (current.approvals.any((a) => a.stage == stage)) {
      throw const ValidationException(
        'This approval stage has already been decided.',
      );
    }

    final nextStatus = LeavePolicy.nextStatus(
      current.status,
      d,
      current.requiresSecondApproval,
    );

    final approval = LeaveApproval(
      id: _nextId('apr'),
      requestId: current.id,
      approverId: actor.id,
      approverName: actor.fullName,
      stage: stage,
      decision: d,
      comment: (trimmedComment != null && trimmedComment.isNotEmpty)
          ? trimmedComment
          : null,
      decidedAt: DateTime.now(),
    );

    final updated = current.copyWith(
      status: nextStatus,
      updatedAt: DateTime.now(),
      approvals: [...current.approvals, approval],
    );

    _requests[index] = updated;
    _changes.add(null);
    return updated;
  }

  @override
  Future<void> cancel(String id) async {
    final index = _requests.indexWhere((r) => r.id == id);
    if (index == -1) {
      throw const NotFoundException('Leave request not found.');
    }

    final current = _requests[index];
    if (!current.status.isPending) {
      throw ValidationException(
        'Only pending leave requests can be cancelled (current status: ${current.status.label}).',
      );
    }

    _requests[index] = current.copyWith(
      status: LeaveStatus.cancelled,
      updatedAt: DateTime.now(),
    );
    _changes.add(null);
  }

  @override
  Future<Uri> getAttachmentUrl(Attachment a) async {
    final bytes = _blobs[a.storagePath];
    if (bytes != null) {
      return Uri.dataFromBytes(bytes, mimeType: a.mimeType);
    }
    return Uri.parse('https://example.com/${a.storagePath}');
  }

  @override
  Stream<void> watchChanges() => _changes.stream;

  /// Exposes raw attachment bytes when running in-memory for instant preview.
  Uint8List? getAttachmentBytes(String storagePath) => _blobs[storagePath];
}
