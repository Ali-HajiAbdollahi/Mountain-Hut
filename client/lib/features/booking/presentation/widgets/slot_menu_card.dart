import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/rich_text_controller.dart';

class SlotMenuCard extends StatefulWidget {
  const SlotMenuCard({required this.menuHtml, super.key});

  final String? menuHtml;

  @override
  State<SlotMenuCard> createState() => _SlotMenuCardState();
}

class _SlotMenuCardState extends State<SlotMenuCard> {
  late final RichTextController _menuController;

  bool get _hasMenu => widget.menuHtml?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _menuController = RichTextController(html: widget.menuHtml ?? '');
  }

  @override
  void didUpdateWidget(covariant SlotMenuCard oldWidget) {
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
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant, size: 18, color: AppColors.primary),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Text(
                  'SLOT MENU • INCLUDED OPTIONS',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
            child: Divider(height: 1, color: AppColors.lightBorder),
          ),
          if (_hasMenu)
            RichText(
              key: const ValueKey('slot-menu-content'),
              text: _menuController.buildTextSpan(
                context: context,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.text,
                  height: 1.5,
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
