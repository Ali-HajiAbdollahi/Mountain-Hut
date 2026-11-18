import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import 'slot_menu_card.dart';

class MealServiceSlotCard extends StatelessWidget {
  const MealServiceSlotCard({
    required this.label,
    required this.leadingIcon,
    required this.selected,
    required this.menuHtml,
    required this.onTap,
    this.detailLabel,
    super.key,
  });

  final String label;
  final IconData leadingIcon;
  final bool selected;
  final String? menuHtml;
  final String? detailLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected ? AppColors.surface : AppColors.lightSlot;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.lightBorder,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: AppConstants.spacingSm,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: backgroundColor,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMd,
                    vertical: AppConstants.spacingSm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        leadingIcon,
                        size: 18,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              label,
                              style: textTheme.labelMedium?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (detailLabel != null)
                              Text(
                                detailLabel!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (selected) ...[
              const Divider(height: 1, color: AppColors.lightBorder),
              SlotMenuCard(menuHtml: menuHtml),
            ],
          ],
        ),
      ),
    );
  }
}
