import 'package:flutter/material.dart';

import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../widgets/staff_portal_body.dart';

class StaffDashboardPage extends StatelessWidget {
  const StaffDashboardPage({
    required this.authRepository,
    required this.api,
    super.key,
  });

  final AuthRepository authRepository;
  final MountainHutApi api;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('STAFF PORTAL')),
      body: StaffPortalBody(api: api),
      bottomNavigationBar: AppBottomNavigation(
        role: AppNavigationRole.employee,
        selectedTab: AppNavigationTab.staffPortal,
        onAccount: () {
          final navigator = AppNavigation.navigatorKey.currentState;
          if (navigator == null) return;
          navigator.pushReplacement(
            AppNavigation.account(
              authRepository: authRepository,
              api: api,
              onStaffPortal: () {
                final currentNavigator =
                    AppNavigation.navigatorKey.currentState;
                if (currentNavigator == null) return;
                currentNavigator.pushReplacement(
                  AppNavigation.staffPortal(
                    authRepository: authRepository,
                    api: api,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
