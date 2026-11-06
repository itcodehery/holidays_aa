import 'package:flutter/material.dart';

import '../../features/leave/domain/leave_status.dart';
import '../theme/app_theme.dart';

/// Accessible status badge that pairs a semantic icon, text label, and color
/// token for every [LeaveStatus].
class StatusChip extends StatelessWidget {
  final LeaveStatus status;
  final bool compact;

  const StatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final style = AppTheme.statusStyle(status, brightness: brightness);

    return Semantics(
      label: 'Leave status: ${status.label}',
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: style.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              style.icon,
              size: compact ? 14 : 16,
              color: style.foreground,
            ),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: style.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
