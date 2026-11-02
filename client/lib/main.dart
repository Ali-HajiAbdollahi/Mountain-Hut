import 'package:flutter/material.dart';

import 'core/network/mountain_hut_api.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/entities/auth_context.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/pages/auth_screen.dart';

void main() {
  runApp(MountainHutApp(authRepository: AuthRepositoryImpl(MountainHutApi())));
}

class MountainHutApp extends StatelessWidget {
  const MountainHutApp({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mountain Hut',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AuthScreen(
        authContext: AuthContext.directAccess,
        authRepository: authRepository,
      ),
    );
  }
}
