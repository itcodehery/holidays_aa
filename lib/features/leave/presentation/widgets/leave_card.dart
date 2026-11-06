import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/leave_request.dart';
import '../../domain/leave_status.dart';

/// Summary card for a [LeaveRequest] styled with warm editorial minimalism:
/// squircle icon badge, inline pill callouts, and accessible [StatusChip].
class LeaveCard extends StatelessWidget {
  final LeaveRequest request;
  final VoidCallback? onTap;
  final bool showEmployeeName;
  final bool showStageBadge;
  final bool selected;

  const LeaveCard({
    super.key,
    required this.request,
    this.onTap,
    this.showEmployeeName = false,
    this.showStageBadge = false,
    this.selected = false,
  });

  IconData _leaveTypeIcon(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return Icons.beach_access_outlined;
      case LeaveType.sick:
        return Icons.medical_services_outlined;
      case LeaveType.casual:
        return Icons.wb_sunny_outlined;
      case LeaveType.unpaid:
        return Icons.money_off_csred_outlined;
      case LeaveType.marriage:
        return Icons.favorite_border_rounded;
      case LeaveType.bereavement:
        return Icons.spa_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActionable = request.status.isPending;
    final dayLabel =
        '${request.totalDays} working ${request.totalDays == 1 ? 'day' : 'days'}';

    // Squircle badge uses warm terracotta when pending/actionable, or warm taupe
    // for historical/completed items.
    final squircleBg = isActionable
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final squircleFg = isActionable
        ? scheme.primary
        : scheme.onSurfaceVariant;

    return Card(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: squircleBg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      _leaveTypeIcon(request.leaveType),
                      color: squircleFg,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              showEmployeeName
                                  ? request.employeeName
                                  : request.leaveType.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (request.requiresSecondApproval)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.terracottaSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '2-Stage',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.terracotta,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          showEmployeeName
                              ? '${request.leaveType.label} · ${AppDateUtils.formatRange(request.startDate, request.endDate)} · $dayLabel'
                              : '${AppDateUtils.formatRange(request.startDate, request.endDate)} · $dayLabel',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: request.status, compact: true),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                request.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (request.attachments.isNotEmpty ||
                  (showStageBadge && request.status.isPending)) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (request.attachments.isNotEmpty)
                      _MetaPill(
                        icon: Icons.attach_file_rounded,
                        label:
                            '${request.attachments.length} ${request.attachments.length == 1 ? 'proof file' : 'proof files'}',
                      ),
                    if (showStageBadge && request.status.isPending)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          request.status == LeaveStatus.pendingManager
                              ? 'Stage 1: Manager Review'
                              : 'Stage 2: HR Final Review',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onTertiaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
