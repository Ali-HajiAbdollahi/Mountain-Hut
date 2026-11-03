import 'package:flutter/material.dart';

import '../network/mountain_hut_api.dart';
import '../../features/auth/domain/entities/auth_context.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/pages/auth_screen.dart';
import '../../features/explore/presentation/pages/explore_page.dart';

class AppNavigation {
  const AppNavigation._();

  static Route<void> explore({
    required AuthRepository authRepository,
    required MountainHutApi api,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => ExplorePage(authRepository: authRepository, api: api),
    );
  }

  static Route<void> auth({
    required AuthRepository authRepository,
    required AuthContext authContext,
    ValueChanged<Map<String, dynamic>>? onSignIn,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => AuthScreen(
        authContext: authContext,
        authRepository: authRepository,
        onSignIn: onSignIn,
      ),
    );
  }
}
