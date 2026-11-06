import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/leave_request.dart';
import '../../domain/leave_status.dart';
import '../leave_providers.dart';

/// Role-aware fullscreen Analytics dashboard on `AppTheme.alabasterCanvas`.
/// Every metric, chart, and breakdown is computed 100% from the logged-in
/// user's real `LeaveRequest`, `LeaveApproval`, and `LeaveAttachment` records.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider) ?? DemoUsers.employee;

    if (user.isEmployee) {
      final myRequestsAsync = ref.watch(myRequestsProvider);
      return myRequestsAsync.when(
        loading: () => const ColoredBox(
          color: AppTheme.alabasterCanvas,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => ColoredBox(
          color: AppTheme.alabasterCanvas,
          child: ErrorView(
            error: err,
            onRetry: () => ref.invalidate(myRequestsProvider),
          ),
        ),
        data: (requests) {
          final ownRequests = requests
              .where((r) => r.employeeId == user.id)
              .toList();
          return _AnalyticsContent(
            user: user,
            requests: ownRequests,
          );
        },
      );
    }

    final pendingAsync = ref.watch(pendingRequestsProvider);
    final historyAsync = ref.watch(historyRequestsProvider);

    if (pendingAsync.isLoading || historyAsync.isLoading) {
      return const ColoredBox(
        color: AppTheme.alabasterCanvas,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (pendingAsync.hasError) {
      return ColoredBox(
        color: AppTheme.alabasterCanvas,
        child: ErrorView(
          error: pendingAsync.error!,
          onRetry: () {
            ref.invalidate(pendingRequestsProvider);
            ref.invalidate(historyRequestsProvider);
          },
        ),
      );
    }

    if (historyAsync.hasError) {
      return ColoredBox(
        color: AppTheme.alabasterCanvas,
        child: ErrorView(
          error: historyAsync.error!,
          onRetry: () {
            ref.invalidate(pendingRequestsProvider);
            ref.invalidate(historyRequestsProvider);
          },
        ),
      );
    }

    final mergedById = <String, LeaveRequest>{};
    for (final r in historyAsync.value ?? const <LeaveRequest>[]) {
      mergedById[r.id] = r;
    }
    for (final r in pendingAsync.value ?? const <LeaveRequest>[]) {
      mergedById[r.id] = r;
    }

    final allVisible = mergedById.values.toList();
    final scopedRequests = user.isManager
        ? allVisible
              .where(
                (r) =>
                    r.managerId == user.id ||
                    r.approvals.any((a) => a.approverId == user.id),
              )
              .toList()
        : allVisible;

    return _AnalyticsContent(
      user: user,
      requests: scopedRequests,
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  final AppUser user;
  final List<LeaveRequest> requests;

  const _AnalyticsContent({
    required this.user,
    required this.requests,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = _LeaveAnalyticsMetrics.fromRequests(
      requests: requests,
      user: user,
    );
    final roleSubtitle = switch (user.role) {
      Role.employee =>
        'Live metrics for ${user.fullName} (${user.email}) based on your ${metrics.totalRequests} submitted leave ${metrics.totalRequests == 1 ? 'request' : 'requests'}',
      Role.manager =>
        'Live Stage 1 & direct-report metrics for ${user.fullName} across ${metrics.totalRequests} team ${metrics.totalRequests == 1 ? 'request' : 'requests'}',
      Role.hr =>
        'Live organization-wide & Stage 2 (HR) metrics for ${user.fullName} across ${metrics.totalRequests} ${metrics.totalRequests == 1 ? 'request' : 'requests'}',
    };

    return ColoredBox(
      color: AppTheme.alabasterCanvas,
      child: SizedBox.expand(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page Title & Logged-in User Identity Pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Leave Analytics',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.inkDark,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              roleSubtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.terracottaSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${user.fullName} · ${user.role.label}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.terracotta,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 1. Top KPI Grid (100% derived from `requests`)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 560;
                      final spacing = isWide ? 12.0 : 10.0;

                      final approvalSubtitle = user.isManager &&
                              metrics.myApprovedDecisionsCount > 0
                          ? '${metrics.approvedCount}/${metrics.totalRequests} fully approved · ${metrics.myApprovedDecisionsCount} Stage 1 by you'
                          : '${metrics.approvedCount} of ${metrics.totalRequests} requests approved (${metrics.rejectedCount} rejected)';

                      final cards = [
                        _KpiMetricCard(
                          icon: LucideIcons.circleCheckBig,
                          accentColor: AppTheme.sageGreen,
                          iconBackground: const Color(0xFFD9EFE2),
                          label: 'Final Approval Rate',
                          value: '${metrics.approvalRatePercent}%',
                          subtitle: approvalSubtitle,
                          progress: metrics.approvalRatePercent / 100.0,
                        ),
                        _KpiMetricCard(
                          icon: LucideIcons.calendarCheck2,
                          accentColor: AppTheme.terracotta,
                          iconBackground: AppTheme.terracottaSoft,
                          label: user.isEmployee
                              ? 'Approved Working Days'
                              : 'Team Approved Days',
                          value: '${metrics.approvedWorkingDays}d',
                          subtitle:
                              '${metrics.totalRequestedWorkingDays}d total requested across ${metrics.totalRequests} ${metrics.totalRequests == 1 ? 'req' : 'reqs'}',
                          progress: metrics.totalRequestedWorkingDays > 0
                              ? (metrics.approvedWorkingDays /
                                        metrics.totalRequestedWorkingDays)
                                    .clamp(0.0, 1.0)
                              : 0.0,
                        ),
                        _KpiMetricCard(
                          icon: LucideIcons.hourglass,
                          accentColor: const Color(0xFFC25E00),
                          iconBackground: const Color(0xFFF6E3CE),
                          label: 'Pending Requests',
                          value: '${metrics.pendingCount}',
                          subtitle:
                              '${metrics.pendingWorkingDays} working ${metrics.pendingWorkingDays == 1 ? 'day' : 'days'} awaiting review',
                          progress: metrics.totalRequests > 0
                              ? (metrics.pendingCount / metrics.totalRequests)
                                    .clamp(0.0, 1.0)
                              : 0.0,
                        ),
                        _KpiMetricCard(
                          icon: LucideIcons.fileCheck2,
                          accentColor: AppTheme.inkDark,
                          iconBackground: AppTheme.warmTaupe,
                          label: 'Requests With Proof',
                          value:
                              '${metrics.withProofCount}/${metrics.totalRequests}',
                          subtitle:
                              '${metrics.totalAttachmentsCount} ${metrics.totalAttachmentsCount == 1 ? 'file' : 'files'} attached · ${metrics.twoStageCount} >3d ${metrics.twoStageCount == 1 ? 'request' : 'requests'}',
                          progress: metrics.proofAttachedPercent / 100.0,
                        ),
                      ];

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: cards[0]),
                              SizedBox(width: spacing),
                              Expanded(child: cards[1]),
                            ],
                          ),
                          SizedBox(height: spacing),
                          Row(
                            children: [
                              Expanded(child: cards[2]),
                              SizedBox(width: spacing),
                              Expanded(child: cards[3]),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // 2. Monthly Working Days Bar Chart (from actual request months)
                  _MonthlyLeaveBarChartCard(
                    buckets: metrics.monthlyBuckets,
                    totalRequests: metrics.totalRequests,
                  ),

                  const SizedBox(height: 16),

                  // 3. Leave Type Distribution (Donut Chart + exact counts)
                  _LeaveTypeDistributionCard(
                    byTypeDays: metrics.daysByType,
                    byTypeCount: metrics.countByType,
                    totalDays: metrics.totalRequestedWorkingDays,
                  ),

                  const SizedBox(height: 16),

                  // 4. Role-Specific Real Data Breakdown:
                  //    - Employee: Exact breakdown of each of the user's leave requests
                  //    - Manager / HR: Approver decision summary + Team Member breakdown
                  if (user.isEmployee)
                    _EmployeeRequestsBreakdownCard(
                      user: user,
                      requests: requests,
                    )
                  else ...[
                    _ApproverDecisionSummaryCard(
                      user: user,
                      metrics: metrics,
                    ),
                    const SizedBox(height: 16),
                    _TeamMemberBreakdownCard(requests: requests),
                  ],

                  const SizedBox(height: 16),

                  // 5. Approval Funnel & Status Breakdown
                  _StatusFunnelCard(metrics: metrics),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiMetricCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final Color iconBackground;
  final String label;
  final String value;
  final String subtitle;
  final double progress;

  const _KpiMetricCard({
    required this.icon,
    required this.accentColor,
    required this.iconBackground,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.ivoryCard,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.inkDark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.inkDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppTheme.alabasterCanvas,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical bar chart showing working days requested/approved/rejected per month.
class _MonthlyLeaveBarChartCard extends StatelessWidget {
  final List<_MonthBucket> buckets;
  final int totalRequests;

  const _MonthlyLeaveBarChartCard({
    required this.buckets,
    required this.totalRequests,
  });

  @override
  Widget build(BuildContext context) {
    final maxDays = buckets.fold<int>(
      1,
      (prev, b) => math.max(prev, b.totalDays),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.ivoryCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leaves by Month',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.inkDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Working days grouped by request start month',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const _LegendDot(
                color: AppTheme.sageGreen,
                label: 'Approved',
              ),
              const SizedBox(width: 10),
              const _LegendDot(
                color: AppTheme.terracotta,
                label: 'Pending',
              ),
              if (buckets.any((b) => b.rejectedDays > 0)) ...[
                const SizedBox(width: 10),
                const _LegendDot(
                  color: Color(0xFFB42318),
                  label: 'Rejected',
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          if (totalRequests == 0 || buckets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No leave requests recorded yet.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.inkMuted,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 168,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final b in buckets)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${b.totalDays}d (${b.requestCount} ${b.requestCount == 1 ? 'req' : 'reqs'})',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.inkDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: LayoutBuilder(
                                  builder: (context, barConstraints) {
                                    final maxBarH = barConstraints.maxHeight;
                                    final approvedH =
                                        (b.approvedDays / maxDays) * maxBarH;
                                    final pendingH =
                                        (b.pendingDays / maxDays) * maxBarH;
                                    final rejectedH =
                                        (b.rejectedDays / maxDays) * maxBarH;

                                    return Container(
                                      width: 36,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (rejectedH > 0)
                                            Container(
                                              height: math.max(6, rejectedH),
                                              color: const Color(0xFFB42318),
                                            ),
                                          if (pendingH > 0)
                                            Container(
                                              height: math.max(6, pendingH),
                                              color: AppTheme.terracotta,
                                            ),
                                          if (approvedH > 0)
                                            Container(
                                              height: math.max(6, approvedH),
                                              color: AppTheme.sageGreen,
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              b.label,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// Editorial Donut Chart + Breakdown showing working days and request count by LeaveType.
class _LeaveTypeDistributionCard extends StatelessWidget {
  final Map<LeaveType, int> byTypeDays;
  final Map<LeaveType, int> byTypeCount;
  final int totalDays;

  const _LeaveTypeDistributionCard({
    required this.byTypeDays,
    required this.byTypeCount,
    required this.totalDays,
  });

  static Color _colorForType(LeaveType type) {
    switch (type) {
      case LeaveType.annual:
        return AppTheme.terracotta;
      case LeaveType.sick:
        return const Color(0xFF2E9E5B);
      case LeaveType.casual:
        return const Color(0xFFD98A2B);
      case LeaveType.marriage:
        return const Color(0xFF7B5EA7);
      case LeaveType.bereavement:
        return const Color(0xFF4A6B82);
      case LeaveType.unpaid:
        return const Color(0xFF8C857B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEntries = LeaveType.values
        .map((t) => MapEntry(t, byTypeDays[t] ?? 0))
        .where((e) => e.value > 0 || (byTypeCount[e.key] ?? 0) > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.ivoryCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leave Type Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.inkDark,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Working days and request count by leave category from your actual records',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          if (activeEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No leave requests submitted yet.',
                style: TextStyle(fontSize: 13, color: AppTheme.inkMuted),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 124,
                  height: 124,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(124, 124),
                        painter: _LeaveTypeDonutPainter(
                          slices: [
                            for (final e in activeEntries)
                              if (e.value > 0)
                                _DonutSlice(
                                  value: e.value.toDouble(),
                                  color: _colorForType(e.key),
                                ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${totalDays}d',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.inkDark,
                            ),
                          ),
                          const Text(
                            'requested',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    children: [
                      for (final e in activeEntries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _colorForType(e.key),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${e.key.label} (${byTypeCount[e.key] ?? 0} ${(byTypeCount[e.key] ?? 0) == 1 ? 'req' : 'reqs'})',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.inkDark,
                                  ),
                                ),
                              ),
                              Text(
                                '${e.value}d (${totalDays > 0 ? ((e.value / totalDays) * 100).round() : 0}%)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DonutSlice {
  final double value;
  final Color color;

  const _DonutSlice({required this.value, required this.color});
}

class _LeaveTypeDonutPainter extends CustomPainter {
  final List<_DonutSlice> slices;

  const _LeaveTypeDonutPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 16.0;
    final rect = const Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppTheme.alabasterCanvas;
    canvas.drawArc(rect, 0, math.pi * 2, false, basePaint);

    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.value / total) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = slice.color;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _LeaveTypeDonutPainter oldDelegate) => true;
}

/// Employee-specific breakdown showing each of the logged-in user's actual
/// leave requests, dates, working days, attachments, and approval stage trail.
class _EmployeeRequestsBreakdownCard extends StatelessWidget {
  final AppUser user;
  final List<LeaveRequest> requests;

  const _EmployeeRequestsBreakdownCard({
    required this.user,
    required this.requests,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...requests]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final fmt = DateFormat('d MMM yyyy');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.ivoryCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${user.fullName}'s Leave Requests",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.inkDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Exact breakdown of your ${sorted.length} recorded leave ${sorted.length == 1 ? 'request' : 'requests'}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            const Text(
              'You have not submitted any leave requests yet.',
              style: TextStyle(fontSize: 13, color: AppTheme.inkMuted),
            )
          else
            for (final r in sorted)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.alabasterCanvas,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.leaveType.label} · ${r.totalDays} working ${r.totalDays == 1 ? 'day' : 'days'}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.inkDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${fmt.format(r.startDate)} – ${fmt.format(r.endDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${r.attachments.length} ${r.attachments.length == 1 ? 'attachment' : 'attachments'} · ${r.requiresSecondApproval ? 'Two-stage (>3d: Manager + HR)' : 'Single-stage (Manager)'}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusChip(status: r.status, compact: true),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Summary of the logged-in Manager or HR officer's own recorded review decisions.
class _ApproverDecisionSummaryCard extends StatelessWidget {
  final AppUser user;
  final _LeaveAnalyticsMetrics metrics;

  const _ApproverDecisionSummaryCard({
    required this.user,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final stageLabel = user.isManager ? 'Stage 1 (Manager)' : 'Stage 2 (HR)';
    final awaitingMyStage = user.isManager
        ? metrics.pendingManagerCount
        : metrics.pendingHrCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.ivoryCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your $stageLabel Review Activity',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.inkDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Decisions recorded by ${user.fullName} (${user.email})',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStatTile(
                  label: 'Approved by You',
                  value:
                      '${metrics.myApprovedDecisionsCount} (${metrics.myApprovedDecisionDays}d)',
                  color: AppTheme.sageGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatTile(
                  label: 'Rejected by You',
                  value: '${metrics.myRejectedDecisionsCount}',
                  color: const Color(0xFFB42318),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatTile(
                  label: 'Awaiting Your Stage',
                  value: '$awaitingMyStage',
                  color: AppTheme.terracotta,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.alabasterCanvas,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Manager / HR team leave breakdown by employee.
class _TeamMemberBreakdownCard extends StatelessWidget {
  final List<LeaveRequest> requests;

  const _TeamMemberBreakdownCard({required this.requests});

  @override
  Widget build(BuildContext context) {
    final byEmployee = <String, _EmployeeSummary>{};
    for (final r in requests) {
      final summary = byEmployee.putIfAbsent(
        r.employeeId,
        () => _EmployeeSummary(name: r.employeeName),
      );
      summary.totalRequests++;
      if (r.status == LeaveStatus.approved) {
        summary.approvedDays += r.totalDays;
        summary.approvedCount++;
      } else if (r.status.isPending) {
        summary.pendingDays += r.totalDays;
        summary.pendingCount++;
      } else if (r.status == LeaveStatus.rejected) {
        summary.rejectedCount++;
      }
    }

    final members = byEmployee.values.toList()
      ..sort(
        (a, b) => (b.approvedDays + b.pendingDays).compareTo(
          a.approvedDays + a.pendingDays,
        ),
      );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.ivoryCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Team Leave Breakdown by Employee',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.inkDark,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Working days approved and awaiting review across employees in your scope',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (members.isEmpty)
            const Text(
              'No team leave requests recorded yet.',
              style: TextStyle(fontSize: 13, color: AppTheme.inkMuted),
            )
          else
            for (final m in members)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.alabasterCanvas,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.terracottaSoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        m.name.isNotEmpty ? m.name[0].toUpperCase() : 'E',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.terracotta,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.inkDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${m.totalRequests} ${m.totalRequests == 1 ? 'request' : 'requests'} · ${m.approvedCount} approved (${m.approvedDays}d) · ${m.pendingCount} pending (${m.pendingDays}d)',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.ivoryCard,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${m.approvedDays + m.pendingDays}d total',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.inkDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _EmployeeSummary {
  final String name;
  int totalRequests = 0;
  int approvedDays = 0;
  int pendingDays = 0;
  int approvedCount = 0;
  int pendingCount = 0;
  int rejectedCount = 0;

  _EmployeeSummary({required this.name});
}

class _StatusFunnelCard extends StatelessWidget {
  final _LeaveAnalyticsMetrics metrics;

  const _StatusFunnelCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final total = metrics.totalRequests;
    final rows = [
      (
        label: 'Fully Approved',
        count: metrics.approvedCount,
        days: metrics.approvedWorkingDays,
        color: AppTheme.sageGreen,
      ),
      (
        label: 'Pending Stage 1 (Manager)',
        count: metrics.pendingManagerCount,
        days: metrics.pendingManagerDays,
        color: AppTheme.terracotta,
      ),
      (
        label: 'Pending Stage 2 (HR)',
        count: metrics.pendingHrCount,
        days: metrics.pendingHrDays,
        color: const Color(0xFFD98A2B),
      ),
      (
        label: 'Rejected',
        count: metrics.rejectedCount,
        days: metrics.rejectedWorkingDays,
        color: const Color(0xFFB42318),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.ivoryCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approval Stage & Status Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.inkDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$total total leave ${total == 1 ? 'request' : 'requests'} (${metrics.totalRequestedWorkingDays} working ${metrics.totalRequestedWorkingDays == 1 ? 'day' : 'days'})',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        r.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.inkDark,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${r.count} req · ${r.days}d (${total > 0 ? ((r.count / total) * 100).round() : 0}%)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: total > 0 ? (r.count / total).clamp(0.0, 1.0) : 0,
                      minHeight: 6,
                      backgroundColor: AppTheme.alabasterCanvas,
                      valueColor: AlwaysStoppedAnimation<Color>(r.color),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthBucket {
  final int year;
  final int month;
  final String label;
  int approvedDays = 0;
  int pendingDays = 0;
  int rejectedDays = 0;
  int requestCount = 0;

  _MonthBucket({
    required this.year,
    required this.month,
    required this.label,
  });

  int get totalDays => approvedDays + pendingDays + rejectedDays;
}

class _LeaveAnalyticsMetrics {
  final int totalRequests;
  final int approvedCount;
  final int rejectedCount;
  final int pendingCount;
  final int pendingManagerCount;
  final int pendingHrCount;
  final int twoStageCount;
  final int withProofCount;
  final int totalAttachmentsCount;
  final int approvedWorkingDays;
  final int pendingWorkingDays;
  final int pendingManagerDays;
  final int pendingHrDays;
  final int rejectedWorkingDays;
  final int totalRequestedWorkingDays;
  final int approvalRatePercent;
  final int proofAttachedPercent;
  final int myApprovedDecisionsCount;
  final int myApprovedDecisionDays;
  final int myRejectedDecisionsCount;
  final Map<LeaveType, int> daysByType;
  final Map<LeaveType, int> countByType;
  final List<_MonthBucket> monthlyBuckets;

  const _LeaveAnalyticsMetrics({
    required this.totalRequests,
    required this.approvedCount,
    required this.rejectedCount,
    required this.pendingCount,
    required this.pendingManagerCount,
    required this.pendingHrCount,
    required this.twoStageCount,
    required this.withProofCount,
    required this.totalAttachmentsCount,
    required this.approvedWorkingDays,
    required this.pendingWorkingDays,
    required this.pendingManagerDays,
    required this.pendingHrDays,
    required this.rejectedWorkingDays,
    required this.totalRequestedWorkingDays,
    required this.approvalRatePercent,
    required this.proofAttachedPercent,
    required this.myApprovedDecisionsCount,
    required this.myApprovedDecisionDays,
    required this.myRejectedDecisionsCount,
    required this.daysByType,
    required this.countByType,
    required this.monthlyBuckets,
  });

  factory _LeaveAnalyticsMetrics.fromRequests({
    required List<LeaveRequest> requests,
    required AppUser user,
  }) {
    var approvedCount = 0;
    var rejectedCount = 0;
    var pendingMgrCount = 0;
    var pendingHrCount = 0;
    var twoStageCount = 0;
    var withProofCount = 0;
    var totalAttachmentsCount = 0;
    var approvedDays = 0;
    var pendingDays = 0;
    var pendingMgrDays = 0;
    var pendingHrDays = 0;
    var rejectedDays = 0;
    var totalRequestedDays = 0;
    var myApprovedDecisionsCount = 0;
    var myApprovedDecisionDays = 0;
    var myRejectedDecisionsCount = 0;

    final daysByType = <LeaveType, int>{
      for (final t in LeaveType.values) t: 0,
    };
    final countByType = <LeaveType, int>{
      for (final t in LeaveType.values) t: 0,
    };

    for (final r in requests) {
      if (r.requiresSecondApproval) twoStageCount++;
      if (r.attachments.isNotEmpty) {
        withProofCount++;
        totalAttachmentsCount += r.attachments.length;
      }

      for (final a in r.approvals) {
        if (a.approverId == user.id) {
          if (a.decision == Decision.approve) {
            myApprovedDecisionsCount++;
            myApprovedDecisionDays += r.totalDays;
          } else {
            myRejectedDecisionsCount++;
          }
        }
      }

      if (r.status != LeaveStatus.cancelled) {
        totalRequestedDays += r.totalDays;
        daysByType[r.leaveType] = (daysByType[r.leaveType] ?? 0) + r.totalDays;
        countByType[r.leaveType] = (countByType[r.leaveType] ?? 0) + 1;
      }

      switch (r.status) {
        case LeaveStatus.approved:
          approvedCount++;
          approvedDays += r.totalDays;
        case LeaveStatus.pendingManager:
          pendingMgrCount++;
          pendingDays += r.totalDays;
          pendingMgrDays += r.totalDays;
        case LeaveStatus.pendingHr:
          pendingHrCount++;
          pendingDays += r.totalDays;
          pendingHrDays += r.totalDays;
        case LeaveStatus.rejected:
          rejectedCount++;
          rejectedDays += r.totalDays;
        case LeaveStatus.cancelled:
          break;
      }
    }

    // Strict, honest approval rate: approved requests out of total requests.
    // Never defaults to 100% when 0 requests are approved!
    final approvalRatePercent = requests.isNotEmpty
        ? ((approvedCount / requests.length) * 100).round()
        : 0;

    final proofAttachedPercent = requests.isNotEmpty
        ? ((withProofCount / requests.length) * 100).round()
        : 0;

    // Group monthly buckets strictly from the actual months present in `requests`
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final bucketMap = <String, _MonthBucket>{};
    final sortedByStart = [...requests]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    for (final r in sortedByStart) {
      if (r.status == LeaveStatus.cancelled) continue;
      final key =
          '${r.startDate.year}-${r.startDate.month.toString().padLeft(2, '0')}';
      final shortYear = (r.startDate.year % 100).toString().padLeft(2, '0');
      final bucket = bucketMap.putIfAbsent(
        key,
        () => _MonthBucket(
          year: r.startDate.year,
          month: r.startDate.month,
          label: "${monthNames[r.startDate.month - 1]} '$shortYear",
        ),
      );
      bucket.requestCount++;
      if (r.status == LeaveStatus.approved) {
        bucket.approvedDays += r.totalDays;
      } else if (r.status.isPending) {
        bucket.pendingDays += r.totalDays;
      } else if (r.status == LeaveStatus.rejected) {
        bucket.rejectedDays += r.totalDays;
      }
    }

    return _LeaveAnalyticsMetrics(
      totalRequests: requests.length,
      approvedCount: approvedCount,
      rejectedCount: rejectedCount,
      pendingCount: pendingMgrCount + pendingHrCount,
      pendingManagerCount: pendingMgrCount,
      pendingHrCount: pendingHrCount,
      twoStageCount: twoStageCount,
      withProofCount: withProofCount,
      totalAttachmentsCount: totalAttachmentsCount,
      approvedWorkingDays: approvedDays,
      pendingWorkingDays: pendingDays,
      pendingManagerDays: pendingMgrDays,
      pendingHrDays: pendingHrDays,
      rejectedWorkingDays: rejectedDays,
      totalRequestedWorkingDays: totalRequestedDays,
      approvalRatePercent: approvalRatePercent,
      proofAttachedPercent: proofAttachedPercent,
      myApprovedDecisionsCount: myApprovedDecisionsCount,
      myApprovedDecisionDays: myApprovedDecisionDays,
      myRejectedDecisionsCount: myRejectedDecisionsCount,
      daysByType: daysByType,
      countByType: countByType,
      monthlyBuckets: bucketMap.values.toList(),
    );
  }
}
