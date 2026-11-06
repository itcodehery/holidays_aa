import 'package:flutter/material.dart';

import '../../features/leave/domain/leave_status.dart';
import '../theme/app_theme.dart';

/// Borderless accessible status pill that pairs a Lucide icon, text label, and
/// soft tonal background for every [LeaveStatus].
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
    final style = AppTheme.statusStyle(status);

    return Semantics(
      label: 'Leave status: ${status.label}',
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              style.icon,
              size: compact ? 13 : 15,
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
