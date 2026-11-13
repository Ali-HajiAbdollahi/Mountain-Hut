import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Editable list of intermediate passage points.
class PassagePointsField extends StatefulWidget {
  const PassagePointsField({
    required this.points,
    required this.onChanged,
    super.key,
  });

  final List<String> points;
  final ValueChanged<List<String>> onChanged;

  @override
  State<PassagePointsField> createState() => _PassagePointsFieldState();
}

class _PassagePointsFieldState extends State<PassagePointsField> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.points
        .map((p) => TextEditingController(text: p))
        .toList();
    if (_controllers.isEmpty) _addController('');
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addController(String value) {
    _controllers.add(TextEditingController(text: value));
    _notify();
  }

  void _remove(int index) {
    _controllers[index].dispose();
    _controllers.removeAt(index);
    if (_controllers.isEmpty) {
      _controllers.add(TextEditingController());
    }
    _notify();
  }

  void _notify() {
    widget.onChanged(
      _controllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          ..._controllers.indexed.map((entry) {
            final i = entry.$1;
            final ctrl = entry.$2;
            return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    onChanged: (_) => _notify(),
                    decoration: InputDecoration(
                      hintText: 'e.g. Colle del Pas',
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                if (_controllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.danger, size: 20),
                    onPressed: () => setState(() => _remove(i)),
                    tooltip: 'Remove point',
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(() => _addController('')),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Passage Point'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
        ),
      ],
    );
  }
}