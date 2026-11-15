import 'package:flutter/material.dart';

import '../../../../core/network/mountain_hut_api.dart';
import '../../../booking/presentation/widgets/dietary_requirements_section.dart';
import '../../../booking/presentation/widgets/meal_service_slot_card.dart';
import '../../domain/entities/service_slot.dart';
import 'add_hiker_form.dart';

class WalkInBookingSection extends StatefulWidget {
  const WalkInBookingSection({required this.api, super.key});

  final MountainHutApi api;

  @override
  State<WalkInBookingSection> createState() =>
      _WalkInBookingSectionState();
}

class _WalkInBookingSectionState extends State<WalkInBookingSection> {
  HikerChoice? _hiker;
  DateTime _date = DateTime.now();
  List<ServiceSlot> _slots = [];
  int? _selectedSlotId;
  int _people = 1;

  final _requirements = <DietaryRequirementDraft>[];

  bool _loadingSlots = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = DateTime(_date.year, _date.month, _date.day);
  }

  @override
  void dispose() {
    for (final requirement in _requirements) {
      requirement.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _error = null;
      _selectedSlotId = null;
    });

    try {
      final raw = await widget.api.listSlots(formatYmd(_date));
      final slots = raw.map(ServiceSlot.fromJson).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      if (!mounted) return;

      setState(() {
        _slots = slots;
        _loadingSlots = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _slots = [];
        _loadingSlots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the server.';
        _slots = [];
        _loadingSlots = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );

    if (picked == null) return;

    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
    });

    await _loadSlots();
  }

  void _removeRequirement(int index) {
    final requirement = _requirements.removeAt(index);
    requirement.dispose();
    setState(() {});
  }

  IconData _slotIcon(ServiceSlot slot) {
    if (slot.freeSeats < 1) return Icons.block;
    return slot.startLabel.startsWith('12:') ||
            slot.startLabel.startsWith('13:')
        ? Icons.lunch_dining
        : Icons.room_service;
  }

  Future<void> _submit() async {
    final slotId = _selectedSlotId;
    final hiker = _hiker;

    if (hiker == null || slotId == null || _submitting) return;

    final requirements = <Map<String, dynamic>>[];

    for (final requirement in _requirements) {
      final description = requirement.controller.text.trim();

      if (description.isEmpty) {
        setState(() {
          _error = 'Complete or remove empty requirements.';
        });
        return;
      }

      requirements.add({
        'description': description,
        'allergy': requirement.isAllergy,
      });
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await widget.api.createStaffBooking(
        hiker: hiker.toJson(),
        slotId: slotId,
        people: _people,
        requirements: requirements,
      );

      if (!mounted) return;

      final booking = result['booking'];
      final reference = booking is Map
          ? booking['reference']?.toString()
          : null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Booking ${reference ?? ''} created',
          ),
        ),
      );

      _resetForm();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not reach the server.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    for (final requirement in _requirements) {
      requirement.dispose();
    }

    setState(() {
      _hiker = null;
      _slots = [];
      _selectedSlotId = null;
      _people = 1;
      _requirements.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text(
          '1. SELECT HIKER',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        AddHikerForm(
          api: widget.api,
          onConfirmed: (choice) {
            setState(() {
              _hiker = choice;
              _slots = [];
              _selectedSlotId = null;
              _error = null;
            });
            _loadSlots();
          },
        ),

        if (_hiker != null) ...[
          const SizedBox(height: 24),
          const Divider(),
          const Text(
            '2. BOOKING DETAILS',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.calendar_month),
              const SizedBox(width: 8),
              Expanded(child: Text(formatLongDate(_date))),
              TextButton(
                onPressed: _submitting || _loadingSlots
                    ? null
                    : _pickDate,
                child: const Text('Change date'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (_loadingSlots)
            const Center(child: CircularProgressIndicator())
          else if (_slots.isEmpty)
            const Text('No slots available for this date.')
          else
            for (final slot in _slots)
              MealServiceSlotCard(
                key: ValueKey('walk-in-slot-${slot.id}'),
                label: '${slot.startLabel} – ${slot.endLabel}',
                leadingIcon: _slotIcon(slot),
                selected: _selectedSlotId == slot.id,
                menuHtml: slot.menu,
                detailLabel: slot.freeSeats < 1
                    ? 'No free seats'
                    : '${slot.freeSeats} free seats',
                onTap: slot.freeSeats < 1 || _submitting
                    ? null
                    : () => setState(() => _selectedSlotId = slot.id),
              ),

          const SizedBox(height: 20),

          const Text(
            'NUMBER OF PEOPLE',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          Row(
            children: [
              IconButton(
                onPressed: _people > 1 && !_submitting
                    ? () => setState(() => _people--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_people',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: _people < 20 && !_submitting
                    ? () => setState(() => _people++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),

          const SizedBox(height: 20),

          DietaryRequirementsSection(
            requirements: _requirements,
            onDelete: _removeRequirement,
            onAdd: () {
              setState(() {
                _requirements.add(DietaryRequirementDraft());
              });
            },
          ),

          const SizedBox(height: 24),

          const Divider(),

          const Text(
            '3. CONFIRM BOOKING',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],

          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: _selectedSlotId != null &&
                    !_submitting &&
                    !_loadingSlots
                ? _submit
                : null,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Confirm Booking'),
          ),
        ],
      ],
    );
  }
}