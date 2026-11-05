import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';

Future<bool> showModifyReservationModal(
  BuildContext context, {
  required Map<String, dynamic> booking,
  required MountainHutApi api,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ModifyReservationSheet(booking: booking, api: api),
  );
  return changed == true;
}

class _ModifyReservationSheet extends StatefulWidget {
  const _ModifyReservationSheet({required this.booking, required this.api});

  final Map<String, dynamic> booking;
  final MountainHutApi api;

  @override
  State<_ModifyReservationSheet> createState() =>
      _ModifyReservationSheetState();
}

class _ModifyReservationSheetState extends State<_ModifyReservationSheet> {
  late int _people;
  late DateTime _selectedDate;
  late List<Map<String, dynamic>> _requirements;
  final _newRequirementController = TextEditingController();
  List<Map<String, dynamic>> _slots = const [];
  int? _slotId;
  bool _loading = true;
  bool _saving = false;
  bool _newRequirementAllergy = false;
  String? _error;

  @override
  void dispose() {
    _newRequirementController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _people = int.tryParse('${widget.booking['n_people']}') ?? 1;
    _slotId = int.tryParse('${widget.booking['tsID']}');
    _selectedDate =
        DateTime.tryParse(
          (widget.booking['start_time']?.toString() ?? '').replaceFirst(
            ' ',
            'T',
          ),
        ) ??
        DateTime.now();
    _requirements = _readRequirements();
    _loadSlots();
  }

  List<Map<String, dynamic>> _readRequirements() {
    final values = widget.booking['requirements'];
    if (values is! List) return [];
    return values.whereType<Map>().map<Map<String, dynamic>>((item) {
      return {
        'description': item['description']?.toString() ?? '',
        'allergy': item['allergy'] == true,
      };
    }).toList();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _loadSlots() async {
    try {
      final slots = await widget.api.listSlots(_dateKey(_selectedDate));
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(_today) ? _today : _selectedDate,
      firstDate: _today,
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    setState(() {
      _selectedDate = date;
      _slotId = null;
      _loading = true;
    });
    await _loadSlots();
  }

  void _addRequirement() {
    final description = _newRequirementController.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Enter a dietary or allergy requirement first.');
      return;
    }
    setState(() {
      _requirements.add(<String, dynamic>{
        'description': description,
        'allergy': _newRequirementAllergy,
      });
      _newRequirementController.clear();
      _newRequirementAllergy = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    final requirements = <Map<String, dynamic>>[];
    for (final item in _requirements) {
      final description = item['description']?.toString().trim() ?? '';
      if (description.isEmpty) {
        setState(() => _error = 'Complete or remove empty requirements.');
        return;
      }
      requirements.add({
        'description': description,
        'allergy': item['allergy'] == true,
      });
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.updateBooking(
        int.tryParse('${widget.booking['bID']}') ?? 0,
        slotId: _slotId,
        people: _people,
        requirements: requirements,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _slotLabel(Map<String, dynamic> slot) {
    final start = slot['start_time']?.toString() ?? '';
    final end = slot['end_time']?.toString() ?? '';
    return '${start.length >= 16 ? start.substring(11, 16) : start} - '
        '${end.length >= 16 ? end.substring(11, 16) : end}';
  }

  @override
  Widget build(BuildContext context) {
    final reference =
        widget.booking['reference'] ?? 'MH-${widget.booking['bID']}';
    return SafeArea(
      top: false,
      // Material (not a coloured Container) so that the ListTiles inside can paint
      // their background and ink splashes on a visible Material ancestor.
      child: Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusMd),
        ),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'MODIFY RESERVATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Booking $reference',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('DATE SELECTION'),
                            subtitle: Text(_dateKey(_selectedDate)),
                            trailing: const Icon(Icons.calendar_today_outlined),
                            onTap: _saving ? null : _selectDate,
                          ),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Eligible mountain dining calendar range',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppConstants.spacingSm),
                          DropdownButtonFormField<int>(
                            initialValue:
                                _slots.any((slot) => slot['tsID'] == _slotId)
                                ? _slotId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'TIME SLOT',
                            ),
                            items: _slots
                                .map((slot) {
                                  final id = int.tryParse('${slot['tsID']}');
                                  return DropdownMenuItem(
                                    value: id,
                                    child: Text(_slotLabel(slot)),
                                  );
                                })
                                .where((item) => item.value != null)
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _slotId = value),
                          ),
                        ],
                        const SizedBox(height: AppConstants.spacingMd),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('PARTY SIZE'),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _people > 1
                                      ? () => setState(() => _people--)
                                      : null,
                                  icon: const Icon(Icons.remove),
                                ),
                                Text('$_people'),
                                IconButton(
                                  onPressed: () => setState(() => _people++),
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Text(
                          'Live Capacity verified for current group size',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.tertiary,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingSm),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('DIETARY / ALLERGIES'),
                            Text(
                              'Dynamic list',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        for (
                          var index = 0;
                          index < _requirements.length;
                          index++
                        )
                          Container(
                            color: AppColors.infoSurface,
                            margin: const EdgeInsets.only(
                              top: AppConstants.spacingSm,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.spacingSm,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _requirements[index]['allergy'] == true
                                      ? Icons.auto_awesome
                                      : Icons.eco_outlined,
                                  color: _requirements[index]['allergy'] == true
                                      ? AppColors.danger
                                      : AppColors.tertiary,
                                  size: 18,
                                ),
                                const SizedBox(width: AppConstants.spacingSm),
                                Expanded(
                                  child: Text(
                                    _requirements[index]['description']
                                            ?.toString() ??
                                        '',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(
                                          () => _requirements.removeAt(index),
                                        ),
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Remove requirement',
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppConstants.spacingSm),
                        TextField(
                          controller: _newRequirementController,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 1 Vegan, Nut allergy, Gluten-Free',
                            filled: true,
                            fillColor: AppColors.lightControl,
                            border: InputBorder.none,
                          ),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _newRequirementAllergy,
                          onChanged: _saving
                              ? null
                              : (value) => setState(
                                  () => _newRequirementAllergy = value == true,
                                ),
                          title: const Text(
                            'Kitchen Allergy Alert (High Priority)',
                            style: TextStyle(fontSize: 12),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _addRequirement,
                            icon: const Icon(Icons.add),
                            label: const Text(
                              'ADD DIETARY / ALLERGY REQUIREMENT',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF393939),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingSm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving || _slotId == null ? null : _save,
                    child: Text(_saving ? 'SAVING...' : 'SAVE CHANGES'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
