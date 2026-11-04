import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

// Keeps the confirmation state separate from the reservation summary.
// The card is shown only when the backend reports that the notification was
// dispatched, so the success page does not imply an email was sent otherwise.
class EmailNotificationCard extends StatelessWidget {
  const EmailNotificationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.zero,
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mark_email_read_outlined, color: AppColors.primary),
          SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              'Notification dispatched\nA confirmation email has been sent to your inbox.',
            ),
          ),
        ],
      ),
    );
  }
}
