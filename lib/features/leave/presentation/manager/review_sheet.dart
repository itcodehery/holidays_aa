import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/leave_policy.dart';
import '../../domain/leave_request.dart';
import '../../domain/leave_status.dart';
import '../leave_providers.dart';
import '../widgets/approval_timeline.dart';
import '../widgets/attachment_tile.dart';

/// Manager / HR review component that adapts to bottom sheets (`< 600px`),
/// modal dialogs (`600-1024px`), or an embedded master-detail pane (`> 1024px`).
class ReviewSheet extends ConsumerStatefulWidget {
  final LeaveRequest request;
  final bool embedded;

  const ReviewSheet({
    super.key,
    required this.request,
    this.embedded = false,
  });

  /// Opens [ReviewSheet] as a bottom sheet on compact screens (`< 600px`) or
  /// as a centered dialog on medium screens (`>= 600px`).
  static Future<void> showAdaptive(
    BuildContext context,
    LeaveRequest request,
  ) async {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ReviewSheet(request: request),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
            child: ReviewSheet(request: request),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  final _commentController = TextEditingController();
  String? _commentError;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleDecision(Decision decision) async {
    final comment = _commentController.text.trim();
    if (decision == Decision.reject && comment.isEmpty) {
      setState(() {
        _commentError = 'A comment is required when rejecting a request.';
      });
      return;
    }
    setState(() => _commentError = null);

    // Confirmation step to prevent accidental approvals/rejections
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          decision == Decision.approve
              ? 'Confirm Approval'
              : 'Confirm Rejection',
        ),
        content: Text(
          decision == Decision.approve
              ? (widget.request.status == LeaveStatus.pendingManager &&
                        widget.request.requiresSecondApproval
                    ? 'Approve Stage 1 and forward this ${widget.request.totalDays}-day request to HR/Admin?'
                    : 'Approve this leave request for ${widget.request.employeeName}?')
              : 'Reject this leave request for ${widget.request.employeeName}? Rejection is final.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: decision == Decision.reject
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              decision == Decision.approve ? 'Approve' : 'Reject Request',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final updated = await ref
        .read(leaveActionsProvider.notifier)
        .decide(widget.request.id, decision, comment.isEmpty ? null : comment);

    if (!mounted) return;

    if (updated != null) {
      _commentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.status == LeaveStatus.pendingHr
                ? 'Stage 1 approved! Request advanced to Pending HR.'
                : 'Request ${updated.status.label.toLowerCase()}.',
          ),
        ),
      );
      if (!widget.embedded && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      final err = ref.read(leaveActionsProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err?.toString() ?? 'Could not record decision.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentUser = ref.watch(currentUserProvider);
    final actionState = ref.watch(leaveActionsProvider);
    final isSubmitting = actionState.isLoading;

    final liveRequest =
        ref.watch(leaveDetailProvider(widget.request.id)).value ??
        widget.request;

    final canDecide =
        currentUser != null &&
        LeavePolicy.validateDecisionPermission(currentUser, liveRequest) ==
            null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      liveRequest.employeeName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${liveRequest.leaveType.label} • ${liveRequest.totalDays} working ${liveRequest.totalDays == 1 ? 'day' : 'days'}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(status: liveRequest.status),
              if (!widget.embedded) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppDateUtils.formatRange(
                        liveRequest.startDate,
                        liveRequest.endDate,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (liveRequest.requiresSecondApproval)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '2-Stage Required (> 3 days)',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onTertiaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 20),
                Text(
                  'Employee Reason',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(liveRequest.reason),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Supporting Documents (${liveRequest.attachments.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (liveRequest.attachments.isEmpty)
            Text(
              'No supporting files attached.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            for (final att in liveRequest.attachments)
              AttachmentTile(attachment: att),
          const SizedBox(height: 16),
          Text(
            'Approval Timeline',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ApprovalTimeline(request: liveRequest),
          if (canDecide) ...[
            const Divider(height: 28),
            Text(
              liveRequest.status == LeaveStatus.pendingManager
                  ? 'Stage 1 Decision (Manager)'
                  : 'Stage 2 Final Decision (HR / Admin)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('review_comment_field'),
              controller: _commentController,
              enabled: !isSubmitting,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reviewer Comment (Required on Reject)',
                hintText: 'Add a note for the employee or HR…',
                errorText: _commentError,
              ),
              onChanged: (_) {
                if (_commentError != null) {
                  setState(() => _commentError = null);
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('reject_request_button'),
                    onPressed: isSubmitting
                        ? null
                        : () => _handleDecision(Decision.reject),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('approve_request_button'),
                    onPressed: isSubmitting
                        ? null
                        : () => _handleDecision(Decision.approve),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      liveRequest.status == LeaveStatus.pendingManager &&
                              liveRequest.requiresSecondApproval
                          ? 'Approve → HR'
                          : 'Approve',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
