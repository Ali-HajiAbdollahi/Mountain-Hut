import 'package:flutter/material.dart';

import 'core/network/mountain_hut_api.dart';
import 'core/theme/app_theme.dart';
import 'features/staff_portal/presentation/widgets/add_hiker_form.dart';

final _api = MountainHutApi();

Future<Object?> _login() => _api.login(
      const String.fromEnvironment('EMP_EMAIL'),
      const String.fromEnvironment('EMP_PASSWORD'),
    );

void main() => runApp(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          appBar: AppBar(title: const Text('PREVIEW – Add New Hiker')),
          body: FutureBuilder<Object?>(
            future: _login(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Login failed: ${snap.error}'));
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AddHikerForm(
                  api: _api,
                  onConfirmed: (choice) => debugPrint('Choice: $choice'),
                ),
              );
            },
          ),
        ),
      ),
    );