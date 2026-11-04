import 'package:flutter/material.dart';

import 'core/layout/responsive_app_shell.dart';
import 'core/network/mountain_hut_api.dart';
import 'core/navigation/app_navigation.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';

void main() {
  final api = MountainHutApi();
  runApp(MountainHutApp(api: api, authRepository: AuthRepositoryImpl(api)));
}

class MountainHutApp extends StatelessWidget {
  const MountainHutApp({
    required this.api,
    required this.authRepository,
    super.key,
  });

  final MountainHutApi api;
  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mountain Hut',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) =>
          ResponsiveAppShell(child: child ?? const SizedBox.shrink()),
      home: Navigator(
        key: AppNavigation.navigatorKey,
        onGenerateRoute: (_) =>
            AppNavigation.explore(authRepository: authRepository, api: api),
      ),
    );
  }
}
