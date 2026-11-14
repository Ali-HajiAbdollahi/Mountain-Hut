import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/rich_text_controller.dart';

class MealServiceSlotCard extends StatefulWidget {
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
  State<MealServiceSlotCard> createState() => _MealServiceSlotCardState();
}

class _MealServiceSlotCardState extends State<MealServiceSlotCard> {
  late final RichTextController _menuController;

  @override
  void initState() {
    super.initState();
    _menuController = RichTextController(html: widget.menuHtml ?? '');
  }

  @override
  void didUpdateWidget(covariant MealServiceSlotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuHtml != widget.menuHtml) {
      _menuController.loadHtml(widget.menuHtml ?? '');
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
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
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMd,
                    vertical: AppConstants.spacingSm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.leadingIcon,
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
                              widget.label,
                              style: textTheme.labelMedium?.copyWith(
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.detailLabel != null)
                              Text(
                                widget.detailLabel!,
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
              _buildMenuPanel(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuPanel(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasMenu = widget.menuHtml?.trim().isNotEmpty == true;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant, size: 15, color: AppColors.primary),
              const SizedBox(width: AppConstants.spacingXs),
              Text(
                'SLOT MENU • INCLUDED OPTIONS',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
            child: Divider(height: 1, color: AppColors.lightBorder),
          ),
          if (hasMenu)
            RichText(
              key: const ValueKey('slot-menu-content'),
              text: _menuController.buildTextSpan(
                context: context,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.text,
                  height: 1.4,
                ),
                withComposing: false,
              ),
            )
          else
            Text(
              'No menu has been published for this slot.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}
