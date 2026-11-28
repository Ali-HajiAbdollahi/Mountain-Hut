import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/iso_week.dart';
import '../../../../core/widgets/tab_selector_button.dart';
import '../../domain/entities/service_slot.dart';
import 'slot_form_dialog.dart';
import 'slot_menu_configuration_card.dart';
import 'table_allocation_modal.dart';

/// Opens the dialog that copies one week into one or more weeks.
const copyWeeksButtonKey = ValueKey('copy-weeks-button');

/// Sub-tabs of the selected slot.
const slotTablesTabKey = ValueKey('slot-tab-tables');
const slotMenuTabKey = ValueKey('slot-tab-menu');

/// From this width the slot list and the selected slot are side by side.
const double _masterDetailBreakpoint = 840;

enum _SlotDetail { tables, menu }

/// The "Planning" tab of the Dining area: the slots of a day on one side and
/// the tables and menu of the selected slot on the other. Copying a whole
/// week is a secondary action, in its own dialog.
class SlotCapacitySection extends StatefulWidget {
  const SlotCapacitySection({required this.api, super.key});

  final MountainHutApi api;

  @override
  State<SlotCapacitySection> createState() => _SlotCapacitySectionState();
}

class _SlotCapacitySectionState extends State<SlotCapacitySection> {
  late DateTime _date;
  late DateTime _sourceWeek;
  Set<DateTime> _copyTargets = {};
  List<ServiceSlot> _slots = const [];
  int? _activeId;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  _SlotDetail _detail = _SlotDetail.tables;

  /// Whether the menu editor has changes that are not published yet.
  bool _menuDirty = false;

  /// Keeps the menu editor (and its unsaved text) when the layout switches
  /// between side by side and stacked.
  final _menuCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _sourceWeek = isoWeekStart(_date);
    // By default the current week is copied into the next one.
    _copyTargets = {
      DateTime(_sourceWeek.year, _sourceWeek.month, _sourceWeek.day + 7),
    };
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

  /// Asks before leaving a menu with unpublished changes. Returns whether the
  /// caller can go on (nothing to lose, or the employee chose to discard).
  Future<bool> _confirmDiscardMenu() async {
    if (!_menuDirty) return true;
    final slot = _active;
    final name = slot == null
        ? 'this slot'
        : 'the ${slot.startLabel}–${slot.endLabel} slot';
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard unsaved menu changes?'),
        content: Text(
          'The menu of $name has changes that have not been published. '
          'If you continue, they will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    if (discard == true) _menuDirty = false;
    return discard == true;
  }

  Future<void> _selectSlot(ServiceSlot slot) async {
    if (slot.id == _activeId) return;
    if (!await _confirmDiscardMenu() || !mounted) return;
    setState(() => _activeId = slot.id);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );
    if (picked == null || !mounted) return;
    final day = DateTime(picked.year, picked.month, picked.day);
    if (day == _date) return;
    if (!await _confirmDiscardMenu() || !mounted) return;
    setState(() {
      _date = day;
      _activeId = null;
    });
    await _load();
  }

  /// Copies the [source] week into every week of [targets], one week at a
  /// time (the server replaces each week atomically). Returns the weeks that
  /// could not be copied, with the reason, or null when nothing was done
  /// (cancelled, or the existing slots could not be checked).
  Future<Map<DateTime, String>?> _copyWeeks(
    DateTime source,
    List<DateTime> targets,
  ) async {
    if (_busy || targets.isEmpty) return null;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final existing = <DateTime, int>{};
      for (final target in targets) {
        final days = await Future.wait(
          List.generate(7, (offset) {
            final day = DateTime(
              target.year,
              target.month,
              target.day + offset,
            );
            return widget.api.listSlots(formatYmd(day));
          }),
        );
        final count = days.fold<int>(0, (sum, slots) => sum + slots.length);
        if (count > 0) existing[target] = count;
      }
      if (!mounted) return null;
      if (existing.isNotEmpty && !await _confirmReplace(existing)) return null;
      if (!mounted) return null;

      final failed = <DateTime, String>{};
      final copied = <DateTime>[];
      var copiedSlots = 0;
      for (final target in targets) {
        try {
          copiedSlots += await widget.api.repeatWeek(
            sourceWeek: formatYmd(source),
            targetWeek: formatYmd(target),
          );
          copied.add(target);
        } on ApiException catch (error) {
          failed[target] = error.message;
        } on Exception catch (error) {
          failed[target] = 'Could not copy the week: $error';
        }
      }
      if (!mounted) return failed;
      if (copied.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Copied $copiedSlots service slot${copiedSlots == 1 ? '' : 's'} '
              'into ${copied.length} week${copied.length == 1 ? '' : 's'}.',
            ),
          ),
        );
        final dayOnScreenCopied = copied.any(
          (week) =>
              !_date.isBefore(week) &&
              _date.isBefore(isoWeekEndExclusive(week)),
        );
        if (dayOnScreenCopied) await _load();
      }
      return failed;
    } on ApiException catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Exception catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not copy the weeks: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return null;
  }

  /// One confirmation for all the chosen weeks that already have slots.
  Future<bool> _confirmReplace(Map<DateTime, int> existing) async {
    final weeks = existing.keys.toList()..sort();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace existing slots?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              weeks.length == 1
                  ? 'This week already has slots:'
                  : 'These weeks already have slots:',
            ),
            const SizedBox(height: AppConstants.spacingSm),
            for (final week in weeks)
              Text(
                '• Week starting ${formatYmd(week)}: ${existing[week]} '
                'slot${existing[week] == 1 ? '' : 's'}',
              ),
            const SizedBox(height: AppConstants.spacingSm),
            const Text('Copying replaces them, together with their menus.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openCopyWeeks() => showDialog<void>(
    context: context,
    builder: (_) => _CopyWeeksDialog(
      sourceWeek: _sourceWeek,
      targetWeeks: _copyTargets,
      onSelectionChanged: (source, targets) {
        _sourceWeek = source;
        _copyTargets = targets;
      },
      onCopy: _copyWeeks,
    ),
  );

  Future<void> _addSlot() async {
    final created = await showSlotFormDialog(
      context,
      date: _date,
      copySources: _slots.where((s) => s.hasLayout).toList(),
      create: (form) => widget.api.createSlot(
        startTime: form.startTime,
        endTime: form.endTime,
        tables: form.copyFromTsId == null ? const [] : null,
        copyFromTsId: form.copyFromTsId,
      ),
    );
    if (created == null || !mounted) return;

    // The new slot becomes the selected one, unless the employee prefers to
    // keep editing an unpublished menu.
    final newId = (created['tsID'] as num).toInt();
    final select = await _confirmDiscardMenu();
    if (!mounted) return;
    await _run(
      () => _load(selectId: select ? newId : _activeId),
      success: 'Slot created.',
    );
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= _masterDetailBreakpoint;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            _dayBar(),
            const SizedBox(height: AppConstants.spacingMd),
            if (sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: _slotsPanel()),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(child: _detailsPanel()),
                ],
              )
            else ...[
              _slotsPanel(),
              const SizedBox(height: AppConstants.spacingMd),
              _detailsPanel(),
            ],
          ],
        );
      },
    );
  }

  Widget _dayBar() {
    final textTheme = Theme.of(context).textTheme;
    final day = Row(
      children: [
        const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAY',
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
    );
    final copyWeek = OutlinedButton.icon(
      key: copyWeeksButtonKey,
      onPressed: _busy ? null : _openCopyWeeks,
      icon: const Icon(Icons.copy_all, size: 18),
      label: const Text('Copy weeks'),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 520
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  day,
                  const SizedBox(height: AppConstants.spacingSm),
                  Align(alignment: Alignment.centerRight, child: copyWeek),
                ],
              )
            : Row(
                children: [
                  Expanded(child: day),
                  const SizedBox(width: AppConstants.spacingMd),
                  copyWeek,
                ],
              ),
      ),
    );
  }

  Widget _slotsPanel() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // In a narrow column the count moves under the title.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppConstants.spacingSm,
          runSpacing: AppConstants.spacingXs,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'SERVICE SLOTS',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
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
        onTap: () => _selectSlot(slot),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? AppColors.surface : AppColors.lightControl,
            border: Border(
              left: BorderSide(
                color: active ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
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

  /// The tables and the menu of the selected slot, or a single hint when no
  /// slot is selected.
  Widget _detailsPanel() {
    final slot = _active;
    final textTheme = Theme.of(context).textTheme;
    final decoration = BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.lightBorder),
    );

    if (slot == null) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: decoration,
        child: Row(
          children: [
            const Icon(
              Icons.touch_app_outlined,
              color: AppColors.secondary,
              size: 18,
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: Text(
                'Select or create a slot to configure its tables and menu.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_calendar_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECTED SLOT',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${slot.startLabel}–${slot.endLabel} · '
                      '${formatLongDate(_date)}',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingXs),
            color: AppColors.background,
            child: Row(
              children: [
                Expanded(
                  child: TabSelectorButton(
                    key: slotTablesTabKey,
                    icon: Icons.table_restaurant,
                    label: 'Tables',
                    selected: _detail == _SlotDetail.tables,
                    onTap: () => setState(() => _detail = _SlotDetail.tables),
                    verticalPadding: 10,
                    ellipsis: true,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingXs),
                Expanded(
                  child: TabSelectorButton(
                    key: slotMenuTabKey,
                    icon: Icons.restaurant_menu,
                    label: 'Menu',
                    selected: _detail == _SlotDetail.menu,
                    onTap: () => setState(() => _detail = _SlotDetail.menu),
                    verticalPadding: 10,
                    ellipsis: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          if (_detail == _SlotDetail.tables) _tablesPanel(slot),
          // The menu editor stays alive while the "Tables" tab is shown, so
          // switching tab does not lose what has been typed.
          Visibility(
            visible: _detail == _SlotDetail.menu,
            maintainState: true,
            child: SlotMenuConfigurationCard(
              key: _menuCardKey,
              api: widget.api,
              slot: slot,
              onDirtyChanged: (dirty) => _menuDirty = dirty,
              onMenuPublished: (slotId, menu) {
                setState(() {
                  _slots = _slots
                      .map(
                        (slot) => slot.id == slotId
                            ? slot.copyWith(menu: menu)
                            : slot,
                      )
                      .toList();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tablesPanel(ServiceSlot slot) {
    final textTheme = Theme.of(context).textTheme;
    final summary = !slot.hasLayout
        ? 'No tables allocated yet.'
        : 'Tables: ${slot.tables.map((t) {
            final no = t.tableNo.toString().padLeft(2, '0');
            return '$no (${t.seats})';
          }).join(', ')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Configured Seating:', style: textTheme.bodyMedium),
                  const Spacer(),
                  Text('${slot.capacity} Seats', style: textTheme.labelLarge),
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
          onPressed: _busy ? null : _configureTables,
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Configure Slot Tables & Capacity'),
        ),
      ],
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

enum _PickMode { source, targets }

/// Copies all the slots and table layouts of one week into one or more weeks,
/// chosen directly on a month calendar where each row is a week.
class _CopyWeeksDialog extends StatefulWidget {
  const _CopyWeeksDialog({
    required this.sourceWeek,
    required this.targetWeeks,
    required this.onSelectionChanged,
    required this.onCopy,
  });

  final DateTime sourceWeek;
  final Set<DateTime> targetWeeks;
  final void Function(DateTime source, Set<DateTime> targets)
  onSelectionChanged;

  /// Copies the weeks and returns the ones that could not be copied (empty
  /// when all were copied, null when nothing was done).
  final Future<Map<DateTime, String>?> Function(
    DateTime source,
    List<DateTime> targets,
  )
  onCopy;

  @override
  State<_CopyWeeksDialog> createState() => _CopyWeeksDialogState();
}

class _CopyWeeksDialogState extends State<_CopyWeeksDialog> {
  late DateTime _source = widget.sourceWeek;
  late final Set<DateTime> _targets = {...widget.targetWeeks};
  late DateTime _month = DateTime(_today.year, _today.month);
  _PickMode _mode = _PickMode.targets;
  bool _copying = false;
  Map<DateTime, String> _failures = const {};

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Slots can only be created in the future, so the weeks to fill start
  /// after today.
  bool _canBeTarget(DateTime monday) =>
      monday != _source && monday.isAfter(_today);

  List<DateTime> get _sortedTargets => _targets.toList()..sort();

  void _notifySelection() => widget.onSelectionChanged(_source, {..._targets});

  void _tapWeek(DateTime monday) {
    setState(() {
      _failures = const {};
      if (_mode == _PickMode.source) {
        _source = monday;
        _targets.remove(monday);
        _mode = _PickMode.targets;
      } else if (_targets.contains(monday)) {
        _targets.remove(monday);
      } else if (_canBeTarget(monday)) {
        _targets.add(monday);
      }
    });
    _notifySelection();
  }

  void _removeTarget(DateTime monday) {
    setState(() => _targets.remove(monday));
    _notifySelection();
  }

  void _clearTargets() {
    setState(_targets.clear);
    _notifySelection();
  }

  void _showMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _copy() async {
    final targets = _sortedTargets;
    setState(() {
      _copying = true;
      _failures = const {};
    });
    final failed = await widget.onCopy(_source, targets);
    if (!mounted) return;
    if (failed != null && failed.isEmpty) {
      widget.onSelectionChanged(_source, <DateTime>{});
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _copying = false;
      if (failed != null) {
        // The weeks already copied are done: only the failed ones stay chosen.
        _failures = failed;
        _targets
          ..clear()
          ..addAll(failed.keys);
      }
    });
    _notifySelection();
  }

  /// "Nov 30 – Dec 6": Monday to Sunday.
  String _weekLabel(DateTime monday) {
    final l = MaterialLocalizations.of(context);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    return '${l.formatShortMonthDay(monday)} – ${l.formatShortMonthDay(sunday)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final targets = _sortedTargets;
    final count = targets.length;
    return Dialog(
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.all(AppConstants.spacingMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppConstants.spacingSm),
                    color: AppColors.infoBadge,
                    child: const Icon(Icons.copy_all, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COPY WEEKS',
                          style: textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingXs),
                        Text(
                          'Copy all service slots and table layouts of one week '
                          'into one or more weeks.',
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
              SegmentedButton<_PickMode>(
                segments: const [
                  ButtonSegment(
                    value: _PickMode.source,
                    icon: Icon(Icons.content_copy, size: 16),
                    label: Text('Week to copy'),
                  ),
                  ButtonSegment(
                    value: _PickMode.targets,
                    icon: Icon(Icons.library_add_check_outlined, size: 16),
                    label: Text('Weeks to fill'),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: _copying
                    ? null
                    : (selection) => setState(() => _mode = selection.first),
              ),
              const SizedBox(height: AppConstants.spacingXs),
              Text(
                _mode == _PickMode.source
                    ? 'Tap the week whose slots you want to copy.'
                    : 'Tap the weeks to fill; tap a week again to remove it.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              _calendar(),
              const SizedBox(height: AppConstants.spacingSm),
              Wrap(
                spacing: AppConstants.spacingMd,
                runSpacing: AppConstants.spacingXs,
                children: [
                  _legendItem(AppColors.primary, 'Copied from'),
                  _legendItem(AppColors.successBadge, 'Copied to'),
                ],
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text('From: ${_weekLabel(_source)}', style: textTheme.labelLarge),
              const SizedBox(height: AppConstants.spacingXs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'To $count week${count == 1 ? '' : 's'}:',
                      style: textTheme.labelLarge,
                    ),
                  ),
                  if (count > 0)
                    TextButton(
                      onPressed: _copying ? null : _clearTargets,
                      child: const Text('Clear'),
                    ),
                ],
              ),
              if (count == 0)
                Text(
                  'No week chosen yet: tap the weeks to fill on the calendar.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.secondary,
                  ),
                )
              else
                Wrap(
                  spacing: AppConstants.spacingXs,
                  runSpacing: AppConstants.spacingXs,
                  children: [
                    for (final week in targets)
                      InputChip(
                        label: Text(_weekLabel(week)),
                        backgroundColor: AppColors.successBadge,
                        deleteButtonTooltipMessage:
                            'Remove ${_weekLabel(week)}',
                        onDeleted: _copying ? null : () => _removeTarget(week),
                      ),
                  ],
                ),
              if (_failures.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingSm),
                _failuresBox(),
              ],
              const SizedBox(height: AppConstants.spacingMd),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppConstants.spacingSm,
                runSpacing: AppConstants.spacingSm,
                children: [
                  TextButton(
                    onPressed: _copying
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  FilledButton.icon(
                    onPressed: (_copying || count == 0) ? null : _copy,
                    icon: _copying
                        ? const SizedBox(
                            width: AppConstants.spacingMd,
                            height: AppConstants.spacingMd,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.copy_all),
                    label: Text(
                      _copying
                          ? 'COPYING…'
                          : count == 0
                          ? 'COPY'
                          : 'COPY TO $count WEEK${count == 1 ? '' : 'S'}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _calendar() {
    final l = MaterialLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final first = DateTime(_month.year, _month.month, 1);
    final last = DateTime(_month.year, _month.month + 1, 0);
    final weeks = <DateTime>[
      for (
        var monday = isoWeekStart(first);
        !monday.isAfter(last);
        monday = DateTime(monday.year, monday.month, monday.day + 7)
      )
        monday,
    ];
    // narrowWeekdays starts on Sunday; the weeks of the hut start on Monday.
    final weekdays = [for (var i = 1; i <= 7; i++) l.narrowWeekdays[i % 7]];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.lightBorder),
      ),
      padding: const EdgeInsets.only(bottom: AppConstants.spacingXs),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: _copying ? null : () => _showMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  l.formatMonthYear(_month),
                  textAlign: TextAlign.center,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: _copying ? null : () => _showMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingXs,
            ),
            child: Row(
              children: [
                for (final day in weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          for (final monday in weeks) _weekRow(monday),
        ],
      ),
    );
  }

  Widget _weekRow(DateTime monday) {
    final isSource = monday == _source;
    final isTarget = _targets.contains(monday);
    final selectable =
        !_copying &&
        (_mode == _PickMode.source || isTarget || _canBeTarget(monday));
    final background = isSource
        ? AppColors.primary
        : isTarget
        ? AppColors.successBadge
        : Colors.transparent;
    final color = isSource
        ? Colors.white
        : selectable
        ? AppColors.text
        : AppColors.disabled;
    final role = isSource
        ? ', week to copy'
        : isTarget
        ? ', week to fill'
        : '';

    return Semantics(
      button: true,
      selected: isSource || isTarget,
      label: 'Week ${_weekLabel(monday)}$role',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('copy-week-${formatYmd(monday)}'),
        onTap: selectable ? () => _tapWeek(monday) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingXs,
            vertical: 2,
          ),
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
          color: background,
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _dayCell(
                    DateTime(monday.year, monday.month, monday.day + i),
                    color,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayCell(DateTime day, Color color) {
    final inMonth = day.month == _month.month;
    final isToday = day == _today;
    return Center(
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontSize: 13,
          color: inMonth ? color : color.withValues(alpha: 0.45),
          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          decoration: isToday ? TextDecoration.underline : null,
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: AppConstants.spacingXs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
        ),
      ],
    );
  }

  Widget _failuresBox() {
    final weeks = _failures.keys.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      color: AppColors.errorSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Not copied:',
            style: TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.bold,
            ),
          ),
          for (final week in weeks)
            Text(
              '• ${_weekLabel(week)}: ${_failures[week]}',
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
