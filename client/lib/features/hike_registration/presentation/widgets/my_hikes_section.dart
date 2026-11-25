import 'package:flutter/material.dart';

import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';

class MyHikesSection extends StatelessWidget {
  const MyHikesSection({required this.api, super.key});

  final MountainHutApi api;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Hikes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Your registered hikes will be displayed here '
              'when personal hike retrieval is available.',
            ),
          ],
        ),
      ),
    );
  }
}
