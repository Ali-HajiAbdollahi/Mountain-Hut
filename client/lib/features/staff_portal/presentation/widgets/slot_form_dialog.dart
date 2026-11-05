import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/service_slot.dart';

class SlotFormResult {
  const SlotFormResult({
    required this.startTime,
    required this.endTime,
    this.copyFromTsId,
  });

  final String startTime;
  final String endTime;
  final int? copyFromTsId;
}

Future<SlotFormResult?> showSlotFormDialog(
  BuildContext context, {
  required DateTime date,
  required List<ServiceSlot> copySources,
}) {
  return showDialog<SlotFormResult>(
    context: context,
    builder: (_) => SlotFormDialog(date: date, copySources: copySources),
  );
}

class SlotFormDialog extends StatefulWidget {
  const SlotFormDialog({
    required this.date,
    required this.copySources,
    super.key,
  });

  final DateTime date;

  /// Slots of the same day that already have a table layout.
  final List<ServiceSlot> copySources;

  @override
  State<SlotFormDialog> createState() => _SlotFormDialogState();
}

class _SlotFormDialogState extends State<SlotFormDialog> {
  TimeOfDay? _start;
  TimeOfDay? _end;
  int? _copyFrom;
  String? _error;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick({required bool isStart}) async {
    final initial =
        (isStart ? _start : _end) ?? const TimeOfDay(hour: 12, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
      _error = null;
    });
  }

  void _submit() {
    final start = _start;
    final end = _end;
    if (start == null || end == null) {
      setState(() => _error = 'Select a start and an end time.');
      return;
    }

    final d = widget.date;
    final startDt = DateTime(d.year, d.month, d.day, start.hour, start.minute);
    final endDt = DateTime(d.year, d.month, d.day, end.hour, end.minute);

    if (!endDt.isAfter(startDt)) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }
    if (!startDt.isAfter(DateTime.now())) {
      setState(() => _error = 'A slot must start in the future.');
      return;
    }

    final day = formatYmd(d);
    Navigator.of(context).pop(
      SlotFormResult(
        startTime: '$day ${_fmt(start)}',
        endTime: '$day ${_fmt(end)}',
        copyFromTsId: _copyFrom,
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? value, {required bool isStart}) {
    return InkWell(
      onTap: () => _pick(isStart: isStart),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.schedule, size: 18),
        ),
        child: Text(value == null ? '--:--' : _fmt(value)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: const RoundedRectangleBorder(),
      backgroundColor: AppColors.surface,
      title: Text('ADD SERVICE SLOT', style: textTheme.labelMedium),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              formatLongDate(widget.date),
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Row(
              children: [
                Expanded(
                  child: _timeField('Start time', _start, isStart: true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _timeField('End time', _end, isStart: false),
                ),
              ],
            ),
            if (widget.copySources.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingMd),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Table layout'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    value: _copyFrom,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Define later'),
                      ),
                      ...widget.copySources.map(
                        (s) => DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(
                            'Copy ${s.startLabel}–${s.endLabel} '
                            '(${s.capacity} seats)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _copyFrom = v),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppConstants.spacingSm),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Create slot'),
        ),
      ],
    );
  }
}