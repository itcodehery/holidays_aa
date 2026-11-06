import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/leave_request.dart';
import '../../domain/leave_status.dart';

/// Borderless summary card for a [LeaveRequest] styled with the two-tone
/// editorial design system: soft ivory card (`#F7F5F0`) on warm stone canvas
/// (`#EAE6DD`), `48x48` squircle Lucide icon container, inline pill badges, and
/// trailing action icon.
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
        return LucideIcons.sun;
      case LeaveType.sick:
        return LucideIcons.stethoscope;
      case LeaveType.casual:
        return LucideIcons.sparkles;
      case LeaveType.unpaid:
        return LucideIcons.coins;
      case LeaveType.marriage:
        return LucideIcons.heart;
      case LeaveType.bereavement:
        return LucideIcons.heartHandshake;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActionable = request.status.isPending;
    final dayLabel =
        '${request.totalDays} working ${request.totalDays == 1 ? 'day' : 'days'}';

    // Squircle badge uses terracotta blush or solid terracotta when pending,
    // and warm taupe for completed/historical requests.
    final squircleBg = request.requiresSecondApproval && isActionable
        ? AppTheme.terracotta
        : isActionable
            ? AppTheme.terracottaSoft
            : AppTheme.warmTaupe;
    final squircleFg = request.requiresSecondApproval && isActionable
        ? Colors.white
        : isActionable
            ? AppTheme.terracotta
            : AppTheme.inkDark;

    return Card(
      elevation: 0,
      color: selected ? const Color(0xFFF2E6DF) : AppTheme.ivoryCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: squircleBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _leaveTypeIcon(request.leaveType),
                      color: squircleFg,
                      size: 21,
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
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                            if (request.requiresSecondApproval)
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
                  const SizedBox(width: 6),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
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
                        icon: LucideIcons.paperclip,
                        label:
                            '${request.attachments.length} ${request.attachments.length == 1 ? 'proof file' : 'proof files'}',
                      ),
                    if (showStageBadge && request.status.isPending)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.alabasterCanvas,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
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
