import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/editorial_summary_header.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/leave_request.dart';
import '../../domain/leave_status.dart';
import '../leave_providers.dart';
import '../widgets/leave_card.dart';
import 'request_detail_screen.dart';

/// Employee's "My Requests" screen featuring the two-tone obsidian summary
/// header + warm stone sheet (`#EAE6DD`) + borderless ivory cards (`#F7F5F0`).
class MyRequestsScreen extends ConsumerStatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  ConsumerState<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen> {
  String? _selectedRequestId;

  List<LeaveRequest> _applyFilter(
    List<LeaveRequest> requests,
    LeaveListFilter filter,
  ) {
    switch (filter) {
      case LeaveListFilter.all:
        return requests;
      case LeaveListFilter.pending:
        return requests.where((r) => r.status.isPending).toList();
      case LeaveListFilter.approved:
        return requests
            .where((r) => r.status == LeaveStatus.approved)
            .toList();
      case LeaveListFilter.rejected:
        return requests
            .where((r) => r.status == LeaveStatus.rejected)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider) ?? DemoUsers.employee;
    final asyncRequests = ref.watch(myRequestsProvider);
    final activeFilter = ref.watch(myRequestsFilterProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isMasterDetail = width > 1024;
    final isTwoColumn = width >= 600 && width <= 1024;

    final allItems = asyncRequests.value ?? const <LeaveRequest>[];
    final pendingCount = allItems.where((r) => r.status.isPending).length;
    final approvedDays = allItems
        .where((r) => r.status == LeaveStatus.approved)
        .fold<int>(0, (sum, r) => sum + r.totalDays);
    final proofCount = allItems.fold<int>(
      0,
      (sum, r) => sum + r.attachments.length,
    );
    final firstName = user.fullName.split(' ').first;

    return ColoredBox(
      color: AppTheme.obsidian,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialSummaryHeader(
            greetingName: firstName,
            summarySpans: [
              const TextSpan(text: 'Here is your leave summary. You have '),
              EditorialSummaryHeader.highlightSpan(
                '$pendingCount pending ${pendingCount == 1 ? 'request' : 'requests'}',
              ),
              const TextSpan(text: ', received '),
              EditorialSummaryHeader.highlightSpan(
                '$approvedDays approved ${approvedDays == 1 ? 'day' : 'days'}',
              ),
              const TextSpan(text: ' and leaves over '),
              EditorialSummaryHeader.highlightSpan('3 working days'),
              const TextSpan(text: ' route to HR.'),
            ],
            metrics: [
              EditorialMetric(
                icon: LucideIcons.folder,
                label: '${allItems.length} requests',
              ),
              EditorialMetric(
                icon: LucideIcons.clock,
                label: '$pendingCount pending',
              ),
              EditorialMetric(
                icon: LucideIcons.trendingUp,
                label: '+$proofCount proof ${proofCount == 1 ? 'file' : 'files'}',
                accentColor: AppTheme.sageGreen,
              ),
            ],
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.alabasterCanvas,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8C3B7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent requests',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.inkDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterPill(
                                label: 'All',
                                selected: activeFilter == LeaveListFilter.all,
                                onTap: () => ref
                                    .read(myRequestsFilterProvider.notifier)
                                    .select(LeaveListFilter.all),
                              ),
                              const SizedBox(width: 8),
                              _FilterPill(
                                label: 'Pending',
                                selected:
                                    activeFilter == LeaveListFilter.pending,
                                onTap: () => ref
                                    .read(myRequestsFilterProvider.notifier)
                                    .select(LeaveListFilter.pending),
                              ),
                              const SizedBox(width: 8),
                              _FilterPill(
                                label: 'Approved',
                                selected:
                                    activeFilter == LeaveListFilter.approved,
                                onTap: () => ref
                                    .read(myRequestsFilterProvider.notifier)
                                    .select(LeaveListFilter.approved),
                              ),
                              const SizedBox(width: 8),
                              _FilterPill(
                                label: 'Rejected',
                                selected:
                                    activeFilter == LeaveListFilter.rejected,
                                onTap: () => ref
                                    .read(myRequestsFilterProvider.notifier)
                                    .select(LeaveListFilter.rejected),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: asyncRequests.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => ErrorView(
                        error: err,
                        onRetry: () => ref.invalidate(myRequestsProvider),
                      ),
                      data: (allRequests) {
                        final filtered = _applyFilter(
                          allRequests,
                          activeFilter,
                        );
                        if (filtered.isEmpty) {
                          return EmptyState(
                            icon: LucideIcons.calendarDays,
                            title: 'No leave requests found',
                            subtitle: activeFilter == LeaveListFilter.all
                                ? 'You have not submitted any leave requests yet.'
                                : 'No requests match the "${activeFilter.name}" filter.',
                            actionLabel: 'Apply for Leave',
                            onAction: () => context.go('/employee/apply'),
                          );
                        }

                        final effectiveSelectedId =
                            _selectedRequestId != null &&
                                filtered.any((r) => r.id == _selectedRequestId)
                            ? _selectedRequestId!
                            : filtered.first.id;

                        if (isMasterDetail) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 430,
                                child: RefreshIndicator(
                                  onRefresh: () =>
                                      ref.refresh(myRequestsProvider.future),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      10,
                                      22,
                                      32,
                                    ),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final item = filtered[index];
                                      return LeaveCard(
                                        request: item,
                                        selected:
                                            item.id == effectiveSelectedId,
                                        onTap: () {
                                          setState(
                                            () => _selectedRequestId = item.id,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: RequestDetailScreen(
                                  key: ValueKey(effectiveSelectedId),
                                  requestId: effectiveSelectedId,
                                  embedded: true,
                                ),
                              ),
                            ],
                          );
                        }

                        if (isTwoColumn) {
                          return RefreshIndicator(
                            onRefresh: () =>
                                ref.refresh(myRequestsProvider.future),
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                10,
                                22,
                                110,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    mainAxisExtent: 186,
                                  ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return LeaveCard(
                                  request: item,
                                  onTap: () => context.push(
                                    '/employee/requests/${item.id}',
                                  ),
                                );
                              },
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () =>
                              ref.refresh(myRequestsProvider.future),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              22,
                              10,
                              22,
                              110,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return LeaveCard(
                                request: item,
                                onTap: () => context.push(
                                  '/employee/requests/${item.id}',
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.terracotta : AppTheme.ivoryCard,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.inkDark,
          ),
        ),
      ),
    );
  }
}
