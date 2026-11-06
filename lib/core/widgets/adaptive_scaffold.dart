import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/auth/presentation/account_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/leave/presentation/leave_providers.dart';
import '../logging/log_buffer.dart';
import '../theme/app_theme.dart';

/// Navigation item metadata for [AdaptiveScaffold].
class AdaptiveDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  const AdaptiveDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
}

/// Responsive two-tone shell featuring:
/// - Deep obsidian header bar with the **INTERLUDE** wordmark and terracotta dot.
/// - Intentional floating dark pill bottom navigation bar with:
///   - Employee: "Home", "Add Leave", and "Account"
///   - Manager / Admin: "Home", "History", and "Account"
/// - Extended dark obsidian rail on desktop (`> 1024px`).
class AdaptiveScaffold extends ConsumerWidget {
  final String title;
  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final Widget? floatingActionButton;

  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.floatingActionButton,
  });

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isMedium(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 && w <= 1024;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width > 1024;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final user = ref.watch(currentUserProvider);
    final pendingCount = (user != null && user.canApprove)
        ? (ref.watch(pendingRequestsProvider).value?.length ?? 0)
        : 0;

    final appBar = AppBar(
      backgroundColor: AppTheme.obsidian,
      toolbarHeight: 64,
      titleSpacing: 24,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.treePalm,
            color: Color(0xFFF5F2EB),
            size: 22,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'INTERLUDE',
              overflow: TextOverflow.ellipsis,
              style: AppTheme.brandTitleStyle(
                fontSize: 24,
                color: const Color(0xFFF5F2EB),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.terracotta,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Debug Logs',
          icon: const Icon(
            LucideIcons.terminal,
            size: 19,
            color: Color(0xFFC5C0B7),
          ),
          onPressed: () => _showLogsDialog(context),
        ),
        if (user != null)
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(
              LucideIcons.logOut,
              size: 19,
              color: Color(0xFFC5C0B7),
            ),
            onPressed: () => showLogoutConfirmationDialog(context, ref),
          ),
        const SizedBox(width: 12),
      ],
    );

    if (width <= 1024) {
      return Scaffold(
        backgroundColor: AppTheme.obsidian,
        appBar: appBar,
        extendBody: true,
        body: body,
        bottomNavigationBar: _FloatingPillBottomBar(
          destinations: destinations,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          pendingBadgeCount: pendingCount,
        ),
      );
    }

    // Desktop (> 1024px) with dark obsidian sidebar
    return Scaffold(
      backgroundColor: AppTheme.obsidian,
      appBar: appBar,
      body: Row(
        children: [
          Container(
            width: 240,
            color: AppTheme.obsidian,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < destinations.length; i++) ...[
                  _DesktopNavPill(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    badgeCount:
                        destinations[i].route == '/approver/pending'
                            ? pendingCount
                            : 0,
                    onTap: () => onDestinationSelected(i),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogsDialog(BuildContext context) {
    final lines = LogBuffer.instance.lines;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.ivoryCard,
        title: const Row(
          children: [
            Icon(LucideIcons.terminal, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Application Debug Logs')),
          ],
        ),
        content: SizedBox(
          width: 640,
          height: 380,
          child: lines.isEmpty
              ? const Center(child: Text('No log records yet.'))
              : Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.obsidian,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView.builder(
                    itemCount: lines.length,
                    itemBuilder: (_, i) => SelectableText(
                      lines[i],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF6EE7B7),
                      ),
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: lines.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard.')),
              );
            },
            icon: const Icon(LucideIcons.copy, size: 16),
            label: const Text('Copy All'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Intentional floating dark pill navigation bar housing the 3 options for the
/// active role:
/// - Employee: "Home", "Add Leave", and "Account"
/// - Manager / Admin: "Home", "History", and "Account"
class _FloatingPillBottomBar extends StatelessWidget {
  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int pendingBadgeCount;

  const _FloatingPillBottomBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.pendingBadgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              height: 64,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.obsidianPill,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppTheme.obsidianPillRim,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: Semantics(
                        label: destinations[i].label,
                        button: true,
                        selected: i == selectedIndex,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onDestinationSelected(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            height: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: i == selectedIndex
                                  ? AppTheme.obsidianPillActive
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  i == selectedIndex
                                      ? destinations[i].selectedIcon
                                      : destinations[i].icon,
                                  size: 17,
                                  color: i == selectedIndex
                                      ? Colors.white
                                      : const Color(0xFFB8B4AC),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    destinations[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: i == selectedIndex
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: i == selectedIndex
                                          ? Colors.white
                                          : const Color(0xFFB8B4AC),
                                    ),
                                  ),
                                ),
                                if (destinations[i].route ==
                                        '/approver/pending' &&
                                    pendingBadgeCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.terracotta,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$pendingBadgeCount',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopNavPill extends StatelessWidget {
  final AdaptiveDestination destination;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _DesktopNavPill({
    required this.destination,
    required this.selected,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.obsidianPillActive : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 19,
                color: selected ? Colors.white : const Color(0xFFB8B4AC),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFFB8B4AC),
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.terracotta,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
