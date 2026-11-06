import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/editorial_summary_header.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/leave_request.dart';
import '../leave_providers.dart';
import '../widgets/leave_card.dart';
import 'review_sheet.dart';

/// Manager and HR/Admin queue screen in the two-tone editorial layout for
/// reviewing pending requests (or browsing historical decisions when
/// [isHistory] is `true`).
class PendingRequestsScreen extends ConsumerStatefulWidget {
  final bool isHistory;

  const PendingRequestsScreen({
    super.key,
    this.isHistory = false,
  });

  @override
  ConsumerState<PendingRequestsScreen> createState() =>
      _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends ConsumerState<PendingRequestsScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider) ?? DemoUsers.manager;
    final provider = widget.isHistory
        ? historyRequestsProvider
        : pendingRequestsProvider;
    final asyncList = ref.watch(provider);

    final width = MediaQuery.sizeOf(context).width;
    final isMasterDetail = width > 1024;
    final isTwoColumn = width >= 600 && width <= 1024;

    final listItems = asyncList.value ?? const <LeaveRequest>[];
    final twoStageCount = listItems
        .where((r) => r.requiresSecondApproval)
        .length;
    final withAttachments = listItems
        .where((r) => r.attachments.isNotEmpty)
        .length;
    final firstName = user.fullName.split(' ').first;
    final stageLabel =
        user.role == Role.hr ? 'Stage 2 (HR)' : 'Stage 1 (Manager)';

    return ColoredBox(
      color: AppTheme.obsidian,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialSummaryHeader(
            greetingName: firstName,
            summarySpans: widget.isHistory
                ? [
                    const TextSpan(text: 'Viewing '),
                    EditorialSummaryHeader.highlightSpan(
                      '${listItems.length} historical ${listItems.length == 1 ? 'record' : 'records'}',
                    ),
                    const TextSpan(
                      text: ' across your organization, including ',
                    ),
                    EditorialSummaryHeader.highlightSpan(
                      '$twoStageCount multi-stage leaves',
                    ),
                    const TextSpan(text: '.'),
                  ]
                : [
                    const TextSpan(text: 'You have '),
                    EditorialSummaryHeader.highlightSpan(
                      '${listItems.length} pending ${listItems.length == 1 ? 'request' : 'requests'}',
                    ),
                    TextSpan(text: ' awaiting $stageLabel review, with '),
                    EditorialSummaryHeader.highlightSpan(
                      '$twoStageCount >3-day ${twoStageCount == 1 ? 'request' : 'requests'}',
                    ),
                    const TextSpan(text: ' and '),
                    EditorialSummaryHeader.highlightSpan(
                      '$withAttachments with proof attached',
                    ),
                    const TextSpan(text: '.'),
                  ],
            metrics: [
              EditorialMetric(
                icon: LucideIcons.inbox,
                label: '${listItems.length} in view',
              ),
              EditorialMetric(
                icon: LucideIcons.shieldCheck,
                label: user.role == Role.hr ? 'Stage 2 • HR' : 'Stage 1 • Mgr',
              ),
              EditorialMetric(
                icon: LucideIcons.trendingUp,
                label: '+$withAttachments with proof',
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
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
                    child: Text(
                      widget.isHistory
                          ? 'Decision history'
                          : 'Awaiting your review',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.inkDark,
                      ),
                    ),
                  ),
                  Expanded(
                    child: asyncList.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => ErrorView(
                        error: err,
                        onRetry: () => ref.invalidate(provider),
                      ),
                      data: (requests) {
                        if (requests.isEmpty) {
                          return EmptyState(
                            icon: widget.isHistory
                                ? LucideIcons.history
                                : LucideIcons.circleCheck,
                            title: widget.isHistory
                                ? 'No request history yet'
                                : 'All caught up!',
                            subtitle: widget.isHistory
                                ? 'Requests will appear here once submitted and reviewed.'
                                : 'There are no pending leave requests waiting at your approval stage.',
                          );
                        }

                        final effectiveSelected =
                            _selectedId != null &&
                                requests.any((r) => r.id == _selectedId)
                            ? requests.firstWhere((r) => r.id == _selectedId)
                            : requests.first;

                        if (isMasterDetail) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 430,
                                child: RefreshIndicator(
                                  onRefresh: () => ref.refresh(provider.future),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      12,
                                      22,
                                      32,
                                    ),
                                    itemCount: requests.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final req = requests[index];
                                      return LeaveCard(
                                        request: req,
                                        showEmployeeName: true,
                                        showStageBadge: !widget.isHistory,
                                        selected:
                                            req.id == effectiveSelected.id,
                                        onTap: () {
                                          setState(() => _selectedId = req.id);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Card(
                                  margin: const EdgeInsets.all(20),
                                  child: ReviewSheet(
                                    key: ValueKey(effectiveSelected.id),
                                    request: effectiveSelected,
                                    embedded: true,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        if (isTwoColumn) {
                          return RefreshIndicator(
                            onRefresh: () => ref.refresh(provider.future),
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                12,
                                22,
                                110,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    mainAxisExtent: 196,
                                  ),
                              itemCount: requests.length,
                              itemBuilder: (context, index) {
                                final req = requests[index];
                                return LeaveCard(
                                  request: req,
                                  showEmployeeName: true,
                                  showStageBadge: !widget.isHistory,
                                  onTap: () =>
                                      ReviewSheet.showAdaptive(context, req),
                                );
                              },
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () => ref.refresh(provider.future),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              22,
                              12,
                              22,
                              110,
                            ),
                            itemCount: requests.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final req = requests[index];
                              return LeaveCard(
                                request: req,
                                showEmployeeName: true,
                                showStageBadge: !widget.isHistory,
                                onTap: () =>
                                    ReviewSheet.showAdaptive(context, req),
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
