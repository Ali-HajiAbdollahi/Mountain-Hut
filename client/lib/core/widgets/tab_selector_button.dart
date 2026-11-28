import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// A tab of a segmented selector: icon and label, filled with the primary
/// colour when selected.
class TabSelectorButton extends StatelessWidget {
  const TabSelectorButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.verticalPadding = 12,
    this.ellipsis = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double verticalPadding;

  /// Truncates the label on one line instead of wrapping it.
  final bool ellipsis;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: verticalPadding,
            horizontal: AppConstants.spacingSm,
          ),
          color: selected ? AppColors.primary : Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: ellipsis ? null : TextAlign.center,
                  overflow: ellipsis ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
