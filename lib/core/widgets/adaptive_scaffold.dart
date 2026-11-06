import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/auth_controller.dart';
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

/// Responsive shell implementing the three layout breakpoints defined in
/// `architecture.md`:
/// - `< 600px`: Bottom `NavigationBar`
/// - `600px – 1024px`: Compact `NavigationRail`
/// - `> 1024px`: Extended `NavigationRail` + centered content container
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
    final scheme = Theme.of(context).colorScheme;

    final appBar = AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Holiday',
            style: AppTheme.brandTitleStyle(
              fontSize: 24,
              color: const Color(0xFFF4F1EA),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppTheme.terracotta,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFFC5C0B7),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (user != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: PopupMenuButton<Role>(
              tooltip: 'Switch demo persona',
              onSelected: (role) {
                ref.read(authControllerProvider.notifier).signInAsDemo(role);
              },
              itemBuilder: (context) => [
                const PopupMenuItem<Role>(
                  enabled: false,
                  child: Text('Quick Switch Role (Demo)'),
                ),
                const PopupMenuDivider(),
                for (final role in Role.values)
                  PopupMenuItem<Role>(
                    value: role,
                    child: Row(
                      children: [
                        Icon(
                          user.role == role
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(role.label),
                      ],
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 16,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${user.fullName.split(' ').first} • ${user.role.label}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: scheme.onSecondaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Debug Logs',
          icon: const Icon(Icons.terminal_rounded),
          onPressed: () => _showLogsDialog(context),
        ),
        if (user != null)
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        const SizedBox(width: 8),
      ],
    );

    if (width < 600) {
      return Scaffold(
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final extendedRail = width > 1024;
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          NavigationRail(
            extended: extendedRail,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: extendedRail
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
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
        title: const Row(
          children: [
            Icon(Icons.terminal_rounded),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: lines.length,
                    itemBuilder: (_, i) => SelectableText(
                      lines[i],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.greenAccent,
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
            icon: const Icon(Icons.copy_rounded, size: 18),
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
