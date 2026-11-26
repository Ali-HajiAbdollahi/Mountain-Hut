import 'package:flutter/material.dart';

import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../widgets/active_hikes_section.dart';

/// The hikes area of the employees (MH-21), reached from its own button in the
/// bottom navigation, apart from the Dining area.
class ActiveHikesPage extends StatelessWidget {
  const ActiveHikesPage({
    required this.authRepository,
    required this.api,
    super.key,
  });

  final AuthRepository authRepository;
  final MountainHutApi api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ACTIVE HIKES')),
      body: ActiveHikesSection(api: api),
      bottomNavigationBar: AppBottomNavigation(
        role: AppNavigationRole.employee,
        selectedTab: AppNavigationTab.activeHikes,
        onStaffPortal: () =>
            AppNavigation.navigatorKey.currentState?.pushReplacement(
              AppNavigation.staffPortal(
                authRepository: authRepository,
                api: api,
              ),
            ),
        onAccount: () =>
            AppNavigation.navigatorKey.currentState?.pushReplacement(
              AppNavigation.staffAccount(
                authRepository: authRepository,
                api: api,
              ),
            ),
      ),
    );
  }
}
