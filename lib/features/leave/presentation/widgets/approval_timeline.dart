import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart';
import '../../domain/leave_approval.dart';
import '../../domain/leave_request.dart';
import '../../domain/leave_status.dart';

/// Visual multi-stage approval timeline displaying submission, Stage 1
/// (Manager), and Stage 2 (HR/Admin, when applicable), along with reviewer
/// comments and timestamps.
class ApprovalTimeline extends StatelessWidget {
  final LeaveRequest request;

  const ApprovalTimeline({super.key, required this.request});

  LeaveApproval? _approvalForStage(int stage) {
    for (final a in request.approvals) {
      if (a.stage == stage) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stage1 = _approvalForStage(1);
    final stage2 = _approvalForStage(2);

    // Determine whether Stage 1 was bypassed (e.g., manager's own leave)
    final bypassedStage1 =
        stage1 == null &&
        (request.status == LeaveStatus.pendingHr || stage2 != null);

    final steps = <_TimelineStepData>[
      _TimelineStepData(
        title: 'Request Submitted',
        subtitle:
            'By ${request.employeeName} on ${AppDateUtils.formatDateTime(request.createdAt)}',
        state: _StepVisualState.completed,
      ),
      if (!bypassedStage1)
        _buildStage1Step(stage1),
      if (request.requiresSecondApproval || bypassedStage1 || stage2 != null)
        _buildStage2Step(stage1, stage2, bypassedStage1),
      if (request.status == LeaveStatus.cancelled)
        _TimelineStepData(
          title: 'Cancelled by Employee',
          subtitle: 'Updated ${AppDateUtils.formatDateTime(request.updatedAt)}',
          state: _StepVisualState.cancelled,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineStepTile(
            data: steps[i],
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }

  _TimelineStepData _buildStage1Step(LeaveApproval? stage1) {
    if (stage1 != null) {
      final isApproved = stage1.decision == Decision.approve;
      return _TimelineStepData(
        title:
            'Stage 1: Manager ${isApproved ? 'Approved' : 'Rejected'} (${stage1.approverName})',
        subtitle: AppDateUtils.formatDateTime(stage1.decidedAt),
        comment: stage1.comment,
        state: isApproved
            ? _StepVisualState.completed
            : _StepVisualState.rejected,
      );
    }

    if (request.status == LeaveStatus.pendingManager) {
      return const _TimelineStepData(
        title: 'Stage 1: Manager Review',
        subtitle: 'Awaiting manager decision',
        state: _StepVisualState.active,
      );
    }

    return const _TimelineStepData(
      title: 'Stage 1: Manager Review',
      subtitle: 'Not reached',
      state: _StepVisualState.upcoming,
    );
  }

  _TimelineStepData _buildStage2Step(
    LeaveApproval? stage1,
    LeaveApproval? stage2,
    bool bypassedStage1,
  ) {
    if (stage2 != null) {
      final isApproved = stage2.decision == Decision.approve;
      return _TimelineStepData(
        title:
            'Stage 2: HR / Admin ${isApproved ? 'Approved' : 'Rejected'} (${stage2.approverName})',
        subtitle: AppDateUtils.formatDateTime(stage2.decidedAt),
        comment: stage2.comment,
        state: isApproved
            ? _StepVisualState.completed
            : _StepVisualState.rejected,
      );
    }

    if (request.status == LeaveStatus.pendingHr) {
      return const _TimelineStepData(
        title: 'Stage 2: HR / Admin Final Approval',
        subtitle: 'Awaiting HR review (> 3 working days / direct HR route)',
        state: _StepVisualState.active,
      );
    }

    if (stage1?.decision == Decision.reject) {
      return const _TimelineStepData(
        title: 'Stage 2: HR / Admin Final Approval',
        subtitle: 'Closed after Stage 1 rejection',
        state: _StepVisualState.upcoming,
      );
    }

    return const _TimelineStepData(
      title: 'Stage 2: HR / Admin Final Approval',
      subtitle: 'Pending Stage 1 completion',
      state: _StepVisualState.upcoming,
    );
  }
}

enum _StepVisualState { completed, active, rejected, cancelled, upcoming }

class _TimelineStepData {
  final String title;
  final String subtitle;
  final String? comment;
  final _StepVisualState state;

  const _TimelineStepData({
    required this.title,
    required this.subtitle,
    this.comment,
    required this.state,
  });
}

class _TimelineStepTile extends StatelessWidget {
  final _TimelineStepData data;
  final bool isLast;

  const _TimelineStepTile({required this.data, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (Color dotColor, IconData icon) = switch (data.state) {
      _StepVisualState.completed => (const Color(0xFF16A34A), Icons.check),
      _StepVisualState.active => (
        const Color(0xFFD97706),
        Icons.hourglass_top_rounded,
      ),
      _StepVisualState.rejected => (scheme.error, Icons.close),
      _StepVisualState.cancelled => (scheme.outline, Icons.remove),
      _StepVisualState.upcoming => (
        scheme.outlineVariant,
        Icons.circle_outlined,
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 1.5),
                  ),
                  child: Icon(icon, size: 15, color: dotColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (data.comment != null && data.comment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              data.comment!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
