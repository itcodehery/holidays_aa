import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart';
import '../../domain/leave_policy.dart';

/// Interactive start/end date range selector with a live "Working days: N"
/// counter and a multi-stage approval info banner when N > 3.
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
      helpText: 'Select Leave Start & End Dates',
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
    final needsTwoStage = LeavePolicy.requiresSecondApproval(days);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('date_range_picker_button'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickDateRange(context),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Leave Dates (Start – End)',
              errorText: errorText,
              prefixIcon: const Icon(Icons.date_range_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasRange)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Working days: $days',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  const Icon(Icons.edit_calendar_outlined),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            child: Text(
              hasRange
                  ? AppDateUtils.formatRange(startDate!, endDate!)
                  : 'Tap to choose start and end dates',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: hasRange ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (hasRange && days == 0) ...[
          const SizedBox(height: 8),
          _InfoBanner(
            icon: Icons.warning_amber_rounded,
            color: scheme.error,
            backgroundColor: scheme.errorContainer.withValues(alpha: 0.4),
            message:
                'Selected dates fall on a weekend/holiday (0 working days). Please pick working days (Mon–Fri).',
          ),
        ],
        if (needsTwoStage) ...[
          const SizedBox(height: 10),
          _InfoBanner(
            key: const Key('two_stage_approval_banner'),
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF1E40AF),
            backgroundColor: const Color(0xFFDBEAFE),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
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
