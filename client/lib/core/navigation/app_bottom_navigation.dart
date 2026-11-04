import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppNavigationRole { anonymous, hiker, employee }

enum AppNavigationTab { explore, bookings, account, staffPortal }

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.role,
    required this.selectedTab,
    this.onExplore,
    this.onBookings,
    this.onAccount,
    this.onStaffPortal,
    super.key,
  });

  final AppNavigationRole role;
  final AppNavigationTab selectedTab;
  final VoidCallback? onExplore;
  final VoidCallback? onBookings;
  final VoidCallback? onAccount;
  final VoidCallback? onStaffPortal;

  @override
  Widget build(BuildContext context) {
    final items = switch (role) {
      AppNavigationRole.anonymous => [
        _Item(Icons.search, 'Search', AppNavigationTab.explore, onExplore),
        _Item(Icons.login, 'Log In', AppNavigationTab.account, onAccount),
      ],
      AppNavigationRole.hiker => [
        _Item(Icons.search, 'Search', AppNavigationTab.explore, onExplore),
        _Item(
          Icons.calendar_month_outlined,
          'My Bookings',
          AppNavigationTab.bookings,
          onBookings,
        ),
        _Item(
          Icons.person_outline,
          'Account',
          AppNavigationTab.account,
          onAccount,
        ),
      ],
      AppNavigationRole.employee => [
        _Item(
          Icons.shield_outlined,
          'Staff Portal',
          AppNavigationTab.staffPortal,
          onStaffPortal,
        ),
        _Item(
          Icons.person_outline,
          'Account',
          AppNavigationTab.account,
          onAccount,
        ),
      ],
    };

    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            children: [
              for (final item in items)
                Expanded(
                  child: InkWell(
                    onTap: item.onPressed,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: item.tab == selectedTab
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: item.tab == selectedTab
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: item.tab == selectedTab
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
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

class _Item {
  const _Item(this.icon, this.label, this.tab, this.onPressed);

  final IconData icon;
  final String label;
  final AppNavigationTab tab;
  final VoidCallback? onPressed;
}
