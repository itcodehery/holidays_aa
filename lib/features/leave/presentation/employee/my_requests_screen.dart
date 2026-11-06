import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Employee's "My Requests" screen featuring the dark editorial summary banner,
/// status filter chips (`All` / `Pending` / `Approved` / `Rejected`),
/// pull-to-refresh, and responsive layout.
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
              const TextSpan(text: 'You currently have '),
              EditorialSummaryHeader.highlightSpan(
                '$pendingCount pending ${pendingCount == 1 ? 'request' : 'requests'}',
              ),
              const TextSpan(text: ', '),
              EditorialSummaryHeader.highlightSpan(
                '$approvedDays working ${approvedDays == 1 ? 'day' : 'days'} approved',
              ),
              const TextSpan(text: ', and leaves over '),
              EditorialSummaryHeader.highlightSpan('3 working days'),
              const TextSpan(text: ' route through Manager + HR.'),
            ],
            metrics: [
              EditorialMetric(
                icon: Icons.folder_open_rounded,
                label: '${allItems.length} total requests',
              ),
              EditorialMetric(
                icon: Icons.schedule_rounded,
                label: '$pendingCount awaiting review',
              ),
              EditorialMetric(
                icon: Icons.trending_up_rounded,
                label: '$proofCount proof files uploaded',
                accentColor: AppTheme.sageGreen,
              ),
            ],
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Row(
                      children: [
                        _FilterChipItem(
                          label: 'All',
                          selected: activeFilter == LeaveListFilter.all,
                          onSelected: () => ref
                              .read(myRequestsFilterProvider.notifier)
                              .select(LeaveListFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipItem(
                          label: 'Pending',
                          selected: activeFilter == LeaveListFilter.pending,
                          onSelected: () => ref
                              .read(myRequestsFilterProvider.notifier)
                              .select(LeaveListFilter.pending),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipItem(
                          label: 'Approved',
                          selected: activeFilter == LeaveListFilter.approved,
                          onSelected: () => ref
                              .read(myRequestsFilterProvider.notifier)
                              .select(LeaveListFilter.approved),
                        ),
                        const SizedBox(width: 8),
                        _FilterChipItem(
                          label: 'Rejected',
                          selected: activeFilter == LeaveListFilter.rejected,
                          onSelected: () => ref
                              .read(myRequestsFilterProvider.notifier)
                              .select(LeaveListFilter.rejected),
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
                            icon: Icons.event_note_outlined,
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
                                width: 420,
                                child: RefreshIndicator(
                                  onRefresh: () =>
                                      ref.refresh(myRequestsProvider.future),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(20),
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
                              const VerticalDivider(width: 1),
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
                              padding: const EdgeInsets.all(20),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    mainAxisExtent: 190,
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
                            padding: const EdgeInsets.all(20),
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

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
