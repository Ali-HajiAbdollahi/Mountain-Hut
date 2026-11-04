import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

class DietaryRequirementDraft {
  DietaryRequirementDraft();

  final controller = TextEditingController();
  bool isAllergy = false;

  void dispose() => controller.dispose();
}

class DietaryRequirementsSection extends StatefulWidget {
  const DietaryRequirementsSection({
    required this.requirements,
    required this.onDelete,
    required this.onAdd,
    super.key,
  });

  final List<DietaryRequirementDraft> requirements;
  final ValueChanged<int> onDelete;
  final VoidCallback onAdd;

  @override
  State<DietaryRequirementsSection> createState() =>
      _DietaryRequirementsSectionState();
}

class _DietaryRequirementsSectionState
    extends State<DietaryRequirementsSection> {
  String? _validationMessage;

  void _addRequirement() {
    final hasEmptyRequirement = widget.requirements.any(
      (requirement) => requirement.controller.text.trim().isEmpty,
    );
    if (hasEmptyRequirement) {
      setState(
        () => _validationMessage =
            'Complete the current requirement before adding another.',
      );
      return;
    }

    setState(() => _validationMessage = null);
    widget.onAdd();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dietary & Allergy Requirements',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          'Specify party member constraints for high-altitude prep.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        ...widget.requirements.indexed.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
            child: _RequirementCard(
              index: entry.$1,
              draft: entry.$2,
              onDelete: () => widget.onDelete(entry.$1),
              onChanged: () {
                if (_validationMessage != null &&
                    entry.$2.controller.text.trim().isNotEmpty) {
                  setState(() => _validationMessage = null);
                }
              },
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _addRequirement,
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.lightSlot,
            side: BorderSide.none,
            foregroundColor: AppColors.text,
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add Dietary / Allergy Requirement'),
        ),
        if (_validationMessage != null) ...[
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            _validationMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _RequirementCard extends StatefulWidget {
  const _RequirementCard({
    required this.index,
    required this.draft,
    required this.onDelete,
    required this.onChanged,
  });

  final int index;
  final DietaryRequirementDraft draft;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  State<_RequirementCard> createState() => _RequirementCardState();
}

class _RequirementCardState extends State<_RequirementCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      color: AppColors.infoSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppConstants.spacingXs),
              Expanded(
                child: Text(
                  'REQUIREMENT ${(widget.index + 1).toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove requirement',
              ),
            ],
          ),
          TextField(
            controller: widget.draft.controller,
            onChanged: (_) => widget.onChanged(),
            decoration: const InputDecoration(
              hintText: 'Describe a dietary requirement or allergy',
              fillColor: AppColors.surface,
            ),
          ),
          Row(
            children: [
              Checkbox(
                value: widget.draft.isAllergy,
                onChanged: (value) => setState(() {
                  widget.draft.isAllergy = value ?? false;
                }),
                visualDensity: VisualDensity.compact,
              ),
              const Expanded(child: Text('Kitchen Allergy Alert')),
              if (widget.draft.isAllergy) ...[
                const Icon(
                  Icons.warning_amber_outlined,
                  size: 16,
                  color: AppColors.danger,
                ),
                const SizedBox(width: AppConstants.spacingXs),
                Text(
                  'FLAGGED FOR CHEF',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
