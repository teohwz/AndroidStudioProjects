import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// One icon in a [DashboardTabBar] — see that class for how [isRealTab]
/// changes its selected/highlighted behavior.
class DashboardTabItem {
  const DashboardTabItem({required this.icon, this.isRealTab = true});

  final IconData icon;

  /// True for a tab that actually swaps the screen's body content in place
  /// (e.g. Overview, Manage/Commerce). False for an icon that's really a
  /// shortcut/launcher to an existing standalone screen (e.g. Analytics, QR
  /// Code, Users, Booths) — tapping it pushes that screen instead of
  /// changing [DashboardTabBar.currentIndex], so it never shows as
  /// "selected" itself; the bar keeps highlighting whichever real tab was
  /// last active underneath.
  final bool isRealTab;
}

/// Icon-only bottom navigation bar for the Exhibitor/Super Admin
/// dashboards' "quiet style" tabs — a plain surface background, a colored
/// top-border indicator on the active item, and muted icons otherwise.
/// Deliberately not the built-in [BottomNavigationBar]: this bar mixes true
/// tabs (swap content in place) with shortcut icons (push an existing
/// screen) in the same row — see [DashboardTabItem.isRealTab] — which the
/// built-in widget's single "selected index" model doesn't represent.
class DashboardTabBar extends StatelessWidget {
  const DashboardTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<DashboardTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Container(
                    padding: const EdgeInsets.only(top: 6, bottom: 7),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          width: 2,
                          color: i == currentIndex
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Icon(
                      items[i].icon,
                      size: 20,
                      color: i == currentIndex
                          ? theme.colorScheme.primary
                          : palette.textMedium.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
