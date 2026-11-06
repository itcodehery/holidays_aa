import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/leave_policy.dart';

/// Borderless interactive start/end date range selector with a live
/// "Working days: N" counter, a weekend/holiday explanation (`⭐ Smart date picker`),
/// and a multi-stage approval info banner when N > 3.
class DateRangeField extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTimeRange> onRangeSelected;
  final String? errorText;

  const DateRangeField({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onRangeSelected,
    this.errorText,
  });

  int get workingDays {
    if (startDate == null || endDate == null) return 0;
    return LeavePolicy.countWorkingDays(startDate!, endDate!);
  }

  WorkingDayBreakdown? get breakdown {
    if (startDate == null || endDate == null) return null;
    return LeavePolicy.explainWorkingDays(startDate!, endDate!);
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialStart = startDate ?? today;
    final initialEnd = endDate ?? initialStart;
    final firstAllowed = initialStart.isBefore(today) ? initialStart : today;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstAllowed,
      lastDate: DateTime(today.year + 2, 12, 31),
      initialDateRange: DateTimeRange(
        start: initialStart,
        end: initialEnd.isBefore(initialStart) ? initialStart : initialEnd,
      ),
      helpText: 'Select Leave Start & End Dates (Weekends & Holidays Skipped)',
    );

    if (picked != null) {
      onRangeSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasRange = startDate != null && endDate != null;
    final days = workingDays;
    final details = breakdown;
    final needsTwoStage = LeavePolicy.requiresSecondApproval(days);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('date_range_picker_button'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => _pickDateRange(context),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Leave Dates (Start – End)',
              errorText: errorText,
              prefixIcon: const Icon(LucideIcons.calendarRange, size: 19),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasRange)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.terracottaSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Working days: $days',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppTheme.terracotta,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  const Icon(LucideIcons.calendarDays, size: 18),
                  const SizedBox(width: 14),
                ],
              ),
            ),
            child: Text(
              hasRange
                  ? AppDateUtils.formatRange(startDate!, endDate!)
                  : 'Tap to choose start and end dates',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: hasRange ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (hasRange && details != null && days > 0) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.calendarCheck2,
                  size: 14,
                  color: AppTheme.inkMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    details.explanationText,
                    key: const Key('working_day_explanation_text'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (hasRange && days == 0) ...[
          const SizedBox(height: 8),
          _InfoBanner(
            icon: LucideIcons.triangleAlert,
            color: scheme.error,
            backgroundColor: const Color(0xFFFADCD9),
            message:
                'Selected dates fall on a weekend/holiday (0 working days). Please pick working days (Mon–Fri).',
          ),
        ],
        if (needsTwoStage) ...[
          const SizedBox(height: 10),
          const _InfoBanner(
            key: Key('two_stage_approval_banner'),
            icon: LucideIcons.info,
            color: Color(0xFFB84724),
            backgroundColor: AppTheme.terracottaSoft,
            message:
                'This request needs approval from your manager and HR (> 3 consecutive working days).',
          ),
        ],
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String message;

  const _InfoBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
