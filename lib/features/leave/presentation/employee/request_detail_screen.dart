import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/leave_request.dart';
import '../leave_providers.dart';
import '../widgets/approval_timeline.dart';
import '../widgets/attachment_tile.dart';

/// Full detail screen for a single [LeaveRequest] in the two-tone editorial
/// layout, displaying metadata, uploaded proof attachments, the multi-stage
/// [ApprovalTimeline], and a Cancel action while pending.
class RequestDetailScreen extends ConsumerWidget {
  final String requestId;
  final bool embedded;

  const RequestDetailScreen({
    super.key,
    required this.requestId,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncReq = ref.watch(leaveDetailProvider(requestId));

    final content = asyncReq.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(leaveDetailProvider(requestId)),
      ),
      data: (request) {
        if (request == null) {
          return const Center(child: Text('Leave request not found.'));
        }
        return _RequestDetailBody(request: request);
      },
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppTheme.obsidian,
      appBar: AppBar(
        backgroundColor: AppTheme.obsidian,
        title: Text(
          'INTERLUDE',
          style: AppTheme.brandTitleStyle(fontSize: 24),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppTheme.alabasterCanvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _RequestDetailBody extends ConsumerWidget {
  final LeaveRequest request;

  const _RequestDetailBody({required this.request});

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.ivoryCard,
        title: const Text('Cancel Leave Request?'),
        content: const Text(
          'Are you sure you want to cancel this pending leave request? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Request'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Cancel Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await ref
        .read(leaveActionsProvider.notifier)
        .cancel(request.id);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Leave request cancelled.'
              : (ref.read(leaveActionsProvider).error?.toString() ??
                    'Unable to cancel request.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final actionState = ref.watch(leaveActionsProvider);
    final isMutating = actionState.isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.leaveType.label,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Employee: ${request.employeeName}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(status: request.status),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      _DetailStat(
                        label: 'Date Range',
                        value: AppDateUtils.formatRange(
                          request.startDate,
                          request.endDate,
                        ),
                        icon: LucideIcons.calendarDays,
                      ),
                      _DetailStat(
                        label: 'Duration',
                        value:
                            '${request.totalDays} working ${request.totalDays == 1 ? 'day' : 'days'}',
                        icon: LucideIcons.clock,
                      ),
                      _DetailStat(
                        label: 'Approval Workflow',
                        value: request.requiresSecondApproval
                            ? 'Two-Stage (Manager → HR)'
                            : 'Single-Stage (Manager)',
                        icon: LucideIcons.gitBranch,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Reason',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.alabasterCanvas,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(request.reason),
                  ),
                  if (request.status.isPending) ...[
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        key: const Key('cancel_request_button'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppTheme.alabasterCanvas,
                        ),
                        onPressed: isMutating
                            ? null
                            : () => _confirmCancel(context, ref),
                        icon: const Icon(LucideIcons.circleX, size: 17),
                        label: const Text('Cancel Request'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supporting Attachments (${request.attachments.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Attachments are frozen after submission for audit integrity.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (request.attachments.isEmpty)
                    Text(
                      'No supporting documents attached.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    for (final att in request.attachments)
                      AttachmentTile(attachment: att),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Approval Timeline & Audit Trail',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ApprovalTimeline(request: request),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.terracottaSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppTheme.terracotta),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
