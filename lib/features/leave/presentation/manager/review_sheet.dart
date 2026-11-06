import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/leave_policy.dart';
import '../../domain/leave_request.dart';
import '../../domain/leave_status.dart';
import '../leave_providers.dart';
import '../widgets/approval_timeline.dart';
import '../widgets/attachment_tile.dart';

/// Borderless Manager / HR review component that adapts to bottom sheets
/// (`< 600px`), modal dialogs (`600-1024px`), or an embedded master-detail pane
/// (`> 1024px`).
class ReviewSheet extends ConsumerStatefulWidget {
  final LeaveRequest request;
  final bool embedded;

  const ReviewSheet({
    super.key,
    required this.request,
    this.embedded = false,
  });

  static Future<void> showAdaptive(
    BuildContext context,
    LeaveRequest request,
  ) async {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppTheme.ivoryCard,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: ReviewSheet(request: request),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: AppTheme.ivoryCard,
          insetPadding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(dialogContext).bottom,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
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
  final _scrollController = ScrollController();
  final _commentFocusNode = FocusNode();
  String? _commentError;

  @override
  void initState() {
    super.initState();
    _commentFocusNode.addListener(_onCommentFocusChanged);
  }

  void _onCommentFocusChanged() {
    if (_commentFocusNode.hasFocus) {
      _scrollToBottomSoon();
    }
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _commentFocusNode
      ..removeListener(_onCommentFocusChanged)
      ..dispose();
    _scrollController.dispose();
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.ivoryCard,
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

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardInset > 0 && _commentFocusNode.hasFocus) {
      _scrollToBottomSoon();
    }

    return SingleChildScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                      '${liveRequest.leaveType.label} · ${liveRequest.totalDays} working ${liveRequest.totalDays == 1 ? 'day' : 'days'}',
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
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.alabasterCanvas,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.calendarDays,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppDateUtils.formatRange(
                        liveRequest.startDate,
                        liveRequest.endDate,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (liveRequest.requiresSecondApproval)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.terracottaSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '2-Stage (> 3 days)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.terracotta,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
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
            const SizedBox(height: 20),
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
              focusNode: _commentFocusNode,
              enabled: !isSubmitting,
              maxLines: 2,
              scrollPadding: const EdgeInsets.only(bottom: 140),
              decoration: InputDecoration(
                fillColor: AppTheme.alabasterCanvas,
                labelText: 'Reviewer Comment (Required on Reject)',
                hintText: 'Add a note for the employee or HR…',
                errorText: _commentError,
              ),
              onTap: _scrollToBottomSoon,
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
                      backgroundColor: const Color(0xFFFADCD9),
                      foregroundColor: const Color(0xFFB42318),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(LucideIcons.x, size: 18),
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.check, size: 18),
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
