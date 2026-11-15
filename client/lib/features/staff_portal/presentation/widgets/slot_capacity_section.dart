import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/iso_week.dart';
import '../../domain/entities/service_slot.dart';
import 'slot_form_dialog.dart';
import 'slot_menu_configuration_card.dart';
import 'table_allocation_modal.dart';

class SlotCapacitySection extends StatefulWidget {
  const SlotCapacitySection({required this.api, super.key});

  final MountainHutApi api;

  @override
  State<SlotCapacitySection> createState() => _SlotCapacitySectionState();
}

class _SlotCapacitySectionState extends State<SlotCapacitySection> {
  late DateTime _date;
  late DateTime _sourceWeek;
  late DateTime _targetWeek;
  List<ServiceSlot> _slots = const [];
  int? _activeId;
  bool _loading = true;
  bool _busy = false;
  bool _replicating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _sourceWeek = isoWeekStart(_date);
    _targetWeek = _sourceWeek.add(const Duration(days: 7));
    _load();
  }

  ServiceSlot? get _active {
    for (final s in _slots) {
      if (s.id == _activeId) return s;
    }
    return null;
  }

  bool get _isPastDay {
    final now = DateTime.now();
    return _date.isBefore(DateTime(now.year, now.month, now.day));
  }

  Future<void> _load({int? selectId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await widget.api.listSlots(formatYmd(_date));
      final slots = raw.map(ServiceSlot.fromJson).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      if (!mounted) return;
      final keep = selectId ?? _activeId;
      setState(() {
        _slots = slots;
        _activeId = slots.any((s) => s.id == keep)
            ? keep
            : (slots.isEmpty ? null : slots.first.id);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the server.';
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (success != null) {
        messenger.showSnackBar(SnackBar(content: Text(success)));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not reach the server.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
      _activeId = null;
    });
    await _load();
  }

  Future<void> _pickWeek({required bool source}) async {
    final selectedWeek = source ? _sourceWeek : _targetWeek;
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedWeek,
      firstDate: DateTime(1),
      lastDate: DateTime(9999),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (source) {
        _sourceWeek = isoWeekStart(picked);
      } else {
        _targetWeek = isoWeekStart(picked);
      }
    });
  }

  void _shiftWeek({required bool source, required int weeks}) {
    setState(() {
      if (source) {
        _sourceWeek = _sourceWeek.add(Duration(days: 7 * weeks));
      } else {
        _targetWeek = _targetWeek.add(Duration(days: 7 * weeks));
      }
    });
  }

  bool get _sameWeek => _sourceWeek == _targetWeek;

  String _weekLabel(DateTime monday) {
    final endExclusive = isoWeekEndExclusive(monday);
    final localizations = MaterialLocalizations.of(context);
    final startLabel = localizations.formatShortMonthDay(monday);
    final endLabel = localizations.formatShortMonthDay(endExclusive);
    return '$startLabel – $endLabel';
  }

  Future<void> _replicateWeek() async {
    if (_busy || _sameWeek) return;
    setState(() {
      _busy = true;
      _replicating = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final copiedSlots = await widget.api.repeatWeek(
        sourceWeek: formatYmd(_sourceWeek),
        targetWeek: formatYmd(_targetWeek),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Replicated $copiedSlots service '
            'slot${copiedSlots == 1 ? '' : 's'} to the target week.',
          ),
        ),
      );
      final targetEnd = isoWeekEndExclusive(_targetWeek);
      if (!_date.isBefore(_targetWeek) && _date.isBefore(targetEnd)) {
        await _load();
      }
    } on ApiException catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Exception catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not replicate schedule: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _replicating = false;
        });
      }
    }
  }

  Future<void> _addSlot() async {
    final result = await showSlotFormDialog(
      context,
      date: _date,
      copySources: _slots.where((s) => s.hasLayout).toList(),
    );
    if (result == null) return;

    await _run(() async {
      final created = await widget.api.createSlot(
        startTime: result.startTime,
        endTime: result.endTime,
        tables: result.copyFromTsId == null ? const [] : null,
        copyFromTsId: result.copyFromTsId,
      );
      await _load(selectId: (created['tsID'] as num).toInt());
    }, success: 'Slot created.');
  }

  Future<void> _configureTables() async {
    final slot = _active;
    if (slot == null) return;

    final result = await showTableAllocationDialog(
      context,
      title:
          'Configure Slot Tables & Capacity – '
          '${slot.startLabel}–${slot.endLabel}',
      initialTables: slot.tables,
      readOnly: slot.hasLayout,
    );
    if (result == null || slot.hasLayout) return;

    await _run(() async {
      await widget.api.defineTables(
        slot.id,
        tables: result.map((t) => t.toJson()).toList(),
      );
      await _load(selectId: slot.id);
    }, success: 'Table allocations saved.');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _replicationCard(),
        const SizedBox(height: AppConstants.spacingMd),
        _dayCard(),
        const SizedBox(height: 16),
        _slotsCard(),
        const SizedBox(height: 16),
        _allocationCard(),
        const SizedBox(height: 16),
        SlotMenuConfigurationCard(
          api: widget.api,
          slot: _active,
          reusableSlots: _slots,
          onMenuPublished: (slotId, menu) {
            setState(() {
              _slots = _slots
                  .map(
                    (slot) =>
                        slot.id == slotId ? slot.copyWith(menu: menu) : slot,
                  )
                  .toList();
            });
          },
        ),
      ],
    );
  }

  Widget _replicationCard() {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A161616),
            blurRadius: AppConstants.spacingSm,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingSm),
                color: AppColors.infoBadge,
                child: const Icon(Icons.grid_view, color: AppColors.primary),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEKLY SCHEDULE REPLICATION',
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXs),
                    Text(
                      'Copy all service slots and table layouts from one week to another.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingSm),
            decoration: BoxDecoration(
              color: AppColors.lightControl,
              border: Border.all(color: AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.swap_horiz,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: AppConstants.spacingXs),
                    Text(
                      'REPLICATION ROUTE',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingSm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final source = _weekSelector(
                      label: 'SOURCE WEEK',
                      week: _sourceWeek,
                      source: true,
                    );
                    final target = _weekSelector(
                      label: 'TARGET WEEK',
                      week: _targetWeek,
                      source: false,
                    );
                    if (constraints.maxWidth <
                        AppConstants.weekRouteCompactBreakpoint) {
                      return Column(
                        children: [
                          source,
                          const Padding(
                            padding: EdgeInsets.all(AppConstants.spacingXs),
                            child: Icon(
                              Icons.arrow_downward,
                              color: AppColors.primary,
                            ),
                          ),
                          target,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: source),
                        const Padding(
                          padding: EdgeInsets.all(AppConstants.spacingXs),
                          child: Icon(
                            Icons.arrow_forward,
                            color: AppColors.primary,
                            size: AppConstants.spacingLg,
                          ),
                        ),
                        Expanded(child: target),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (_sameWeek) ...[
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Choose two different weeks.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppConstants.spacingMd),
          FilledButton.icon(
            onPressed: (_busy || _sameWeek) ? null : _replicateWeek,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
            ),
            icon: _replicating
                ? const SizedBox(
                    width: AppConstants.spacingMd,
                    height: AppConstants.spacingMd,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(
              _replicating
                  ? 'REPLICATING SCHEDULE...'
                  : 'REPLICATE SCHEDULE TO TARGET',
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekSelector({
    required String label,
    required DateTime week,
    required bool source,
  }) {
    final isTarget = !source;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: isTarget ? AppColors.primary : AppColors.lightBorder,
          width: isTarget ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A161616),
            blurRadius: AppConstants.spacingXs,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.lightBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _weekControl(
                  icon: Icons.chevron_left,
                  tooltip: 'Previous week',
                  onPressed: _busy
                      ? null
                      : () => _shiftWeek(source: source, weeks: -1),
                ),
                Container(
                  width: 1,
                  height: AppConstants.spacingXl,
                  color: AppColors.lightBorder,
                ),
                _weekControl(
                  icon: Icons.calendar_month,
                  tooltip: 'Choose $label',
                  onPressed: _busy ? null : () => _pickWeek(source: source),
                  color: AppColors.primary,
                ),
                Container(
                  width: 1,
                  height: AppConstants.spacingXl,
                  color: AppColors.lightBorder,
                ),
                _weekControl(
                  icon: Icons.chevron_right,
                  tooltip: 'Next week',
                  onPressed: _busy
                      ? null
                      : () => _shiftWeek(source: source, weeks: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            _weekLabel(week),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            isTarget
                ? 'Target must not already contain slots'
                : 'Configured schedule',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }

  Widget _weekControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(
        width: AppConstants.spacingXl,
        height: AppConstants.spacingXl,
      ),
      padding: EdgeInsets.zero,
      color: color ?? AppColors.text,
      icon: Icon(icon, size: AppConstants.spacingMd),
    );
  }

  Widget _dayCard() {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.surface,
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TARGET OPERATIONAL DAY',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(formatLongDate(_date), style: textTheme.labelLarge),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _pickDate,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _slotsCard() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              'SERVICE SLOTS',
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.secondary,
              ),
            ),
            const Spacer(),
            Text(
              '${_slots.length} slot${_slots.length == 1 ? '' : 's'} '
              'configured',
              style: textTheme.bodySmall?.copyWith(color: AppColors.secondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _errorBox(_error!)
        else if (_slots.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Text(
              'No service slots for this day.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          ..._slots.map(_slotTile),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: (_busy || _isPastDay || _loading) ? null : _addSlot,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add Custom Service Slot'),
        ),
        if (_isPastDay)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Slots can only be added for today or future days.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.secondary),
            ),
          ),
      ],
    );
  }

  Widget _slotTile(ServiceSlot slot) {
    final active = slot.id == _activeId;
    final textTheme = Theme.of(context).textTheme;
    final detail = slot.hasLayout ? '${slot.capacity} seats' : 'no layout yet';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _activeId = slot.id),
        child: Container(
          padding: const EdgeInsets.all(12),
          color: active ? AppColors.surface : AppColors.lightControl,
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AppColors.primary : AppColors.lightSlot,
                ),
                child: active
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${slot.startLabel} – ${slot.endLabel}',
                            style: textTheme.labelLarge,
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 8),
                          _badge('ACTIVE SLOT'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${slot.durationMinutes} min · $detail',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _allocationCard() {
    final slot = _active;
    final textTheme = Theme.of(context).textTheme;

    final tableCount = slot?.tables.length ?? 0;
    final summary = (slot == null || !slot.hasLayout)
        ? 'No tables allocated yet.'
        : 'Tables: ${slot.tables.map((t) {
            final no = t.tableNo.toString().padLeft(2, '0');
            return '$no (${t.seats})';
          }).join(', ')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.table_restaurant,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SLOT TABLE ALLOCATION',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ),
              if (slot != null)
                _badge(
                  '${slot.startLabel} • $tableCount '
                  'Table${tableCount == 1 ? '' : 's'}',
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.background,
            child: slot == null
                ? Text(
                    'Select or create a slot to configure its tables.',
                    style: textTheme.bodyMedium,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Configured Seating:',
                            style: textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          Text(
                            '${slot.capacity} Seats',
                            style: textTheme.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          ElevatedButton.icon(
            onPressed: (slot == null || _busy) ? null : _configureTables,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Configure Slot Tables & Capacity'),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.errorSurface,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      color: AppColors.infoBadge,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
