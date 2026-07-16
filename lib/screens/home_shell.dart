import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';
import '../utils/ui_labels.dart';
import 'dashboard_screen.dart';
import 'presets_screen.dart';
import 'recipes_screen.dart';
import 'settings_screen.dart';

/// Top-level shell holding the bottom navigation bar. Each destination is
/// its own nested [Scaffold] (with its own app bar / FAB), kept alive in
/// an [IndexedStack] so switching tabs doesn't lose scroll position or
/// in-progress state.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    DashboardScreen(),
    RecipesScreen(),
    PresetsScreen(),
    SettingsScreen(),
  ];

  static const _destinations = [
    _NavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: HomeShellLabels.dashboardTab,
    ),
    _NavItem(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      label: HomeShellLabels.recipesTab,
    ),
    _NavItem(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: HomeShellLabels.ingredientsTab,
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: HomeShellLabels.settingsTab,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // A pending cross-tab request (e.g. "jump to Recipes filtered by
    // Chemical") switches the selected tab here; RecipesScreen picks up
    // the matching pending domain filter on its own. Deferred to a
    // post-frame callback since build() can't call setState directly.
    final navigationProvider = context.watch<NavigationProvider>();
    final pendingTabIndex = navigationProvider.pendingTabIndex;
    if (pendingTabIndex != null && pendingTabIndex != _index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _index = pendingTabIndex);
        navigationProvider.consumeTabIndexRequest();
      });
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: _BottomNavBar(
        destinations: _destinations,
        selectedIndex: _index,
        onSelected: (index) => setState(() => _index = index),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Hand-built bottom nav bar (rather than [NavigationBar]) so each item's
/// icon+label can be top-aligned with center-aligned, wrap-safe text —
/// [NavigationBar] centers the whole icon/label block vertically and
/// left-aligns wrapped label text, which looked inconsistent once one
/// label ("Recipes/Formulas") got long enough to wrap while the others
/// stayed on one line.
class _BottomNavBar extends StatelessWidget {
  final List<_NavItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _BottomNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        // No fixed height here: it needs to fit whichever label wraps to
        // two lines, so the bar sizes to its (intrinsic-height) content
        // instead of a guessed constant.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _BottomNavItem(
                  item: destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.secondaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
