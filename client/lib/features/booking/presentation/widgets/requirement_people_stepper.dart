import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// "How many people of the party have this requirement": `null` means not specified.
/// The backend accepts a whole number from 1 up to the party size, or no number at all.
class RequirementPeopleStepper extends StatelessWidget {
  const RequirementPeopleStepper({
    required this.value,
    required this.maxPeople,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final int? value;
  final int maxPeople;
  final ValueChanged<int?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final current = value;
    return Row(
      children: [
        const Expanded(
          child: Text('People affected', style: TextStyle(fontSize: 12)),
        ),
        IconButton(
          tooltip: 'Fewer people affected',
          visualDensity: VisualDensity.compact,
          onPressed: enabled && current != null
              ? () => onChanged(current <= 1 ? null : current - 1)
              : null,
          icon: const Icon(Icons.exposure_neg_1, size: 20),
        ),
        SizedBox(
          width: 84,
          child: Text(
            current == null ? 'Not specified' : '$current of $maxPeople',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: current == null ? AppColors.textSecondary : AppColors.text,
            ),
          ),
        ),
        IconButton(
          tooltip: 'More people affected',
          visualDensity: VisualDensity.compact,
          onPressed: enabled && (current == null || current < maxPeople)
              ? () => onChanged((current ?? 0) + 1)
              : null,
          icon: const Icon(Icons.exposure_plus_1, size: 20),
        ),
      ],
    );
  }
}
