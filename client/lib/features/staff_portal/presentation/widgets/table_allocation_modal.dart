import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/table_draft.dart';

/// Opens the table layout editor. Returns the edited list on save,
/// or null when cancelled.
Future<List<TableDraft>?> showTableAllocationDialog(
  BuildContext context, {
  required String title,
  required List<TableDraft> initialTables,
  bool readOnly = false,
}) {
  return showDialog<List<TableDraft>>(
    context: context,
    builder: (_) => TableAllocationModal(
      title: title,
      initialTables: initialTables,
      readOnly: readOnly,
    ),
  );
}

class TableAllocationModal extends StatefulWidget {
  const TableAllocationModal({
    required this.title,
    required this.initialTables,
    this.readOnly = false,
    super.key,
  });

  final String title;
  final List<TableDraft> initialTables;
  final bool readOnly;

  @override
  State<TableAllocationModal> createState() => _TableAllocationModalState();
}

class _TableAllocationModalState extends State<TableAllocationModal> {
  final _numController = TextEditingController();
  final _seatsController = TextEditingController();

  late List<TableDraft> _tables;
  bool _formOpen = false;
  int? _editingNo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tables = [...widget.initialTables]
      ..sort((a, b) => a.tableNo.compareTo(b.tableNo));
  }

  @override
  void dispose() {
    _numController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  int get _totalSeats => _tables.fold(0, (sum, t) => sum + t.seats);

  int get _nextTableNo => _tables.isEmpty
      ? 1
      : _tables.map((t) => t.tableNo).reduce((a, b) => a > b ? a : b) + 1;

  String _pad(int n) => n.toString().padLeft(2, '0');

  void _openForm({TableDraft? editing}) {
    setState(() {
      _formOpen = true;
      _editingNo = editing?.tableNo;
      _numController.text = (editing?.tableNo ?? _nextTableNo).toString();
      _seatsController.text = editing?.seats.toString() ?? '';
      _error = null;
    });
  }

  void _closeForm() {
    setState(() {
      _formOpen = false;
      _editingNo = null;
      _error = null;
    });
  }

  void _submitForm() {
    final no = int.tryParse(_numController.text.trim());
    final seats = int.tryParse(_seatsController.text.trim());

    if (no == null || no <= 0 || seats == null || seats <= 0) {
      setState(() => _error = 'Table # and seats must be positive numbers.');
      return;
    }
    final duplicate =
        _tables.any((t) => t.tableNo == no && t.tableNo != _editingNo);
    if (duplicate) {
      setState(() => _error = 'Table ${_pad(no)} already exists.');
      return;
    }

    setState(() {
      _tables = [
        ..._tables.where((t) => t.tableNo != _editingNo),
        TableDraft(tableNo: no, seats: seats),
      ]..sort((a, b) => a.tableNo.compareTo(b.tableNo));
      _formOpen = false;
      _editingNo = null;
      _error = null;
    });
  }

  void _delete(TableDraft table) {
    setState(() {
      _tables = _tables.where((t) => t.tableNo != table.tableNo).toList();
      if (_editingNo == table.tableNo) {
        _formOpen = false;
        _editingNo = null;
      }
    });
  }

  void _save() {
    if (_tables.isEmpty) {
      setState(() => _error = 'Add at least one table.');
      return;
    }
    Navigator.of(context).pop(_tables);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      shape: const RoundedRectangleBorder(),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(AppConstants.spacingMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(textTheme),
            _summary(textTheme),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.readOnly)
                      Container(
                        padding: const EdgeInsets.all(AppConstants.spacingSm),
                        margin: const EdgeInsets.only(
                          bottom: AppConstants.spacingSm,
                        ),
                        color: AppColors.infoBadge,
                        child: const Text(
                          'Layout already defined. Changing an existing '
                          'layout is not supported yet.',
                        ),
                      ),
                    if (_formOpen) _form(textTheme),
                    if (_tables.isEmpty && !_formOpen)
                      Padding(
                        padding: const EdgeInsets.all(AppConstants.spacingLg),
                        child: Center(
                          child: Text(
                            'No tables yet. Tap "Add Table" to start.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ..._tables.map(_tableRow),
                    if (_error != null && !_formOpen)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppConstants.spacingSm,
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header(TextTheme textTheme) {
    return Container(
      color: AppColors.lightSlot,
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        children: [
          const Icon(Icons.table_bar, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title.toUpperCase(),
              style: textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _summary(TextTheme textTheme) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('$_totalSeats Total Seats', style: textTheme.labelLarge),
          const SizedBox(width: 8),
          Text(
            'across ${_tables.length} table${_tables.length == 1 ? '' : 's'}',
            style: textTheme.bodySmall?.copyWith(color: AppColors.secondary),
          ),
          const Spacer(),
          if (!widget.readOnly)
            ElevatedButton.icon(
              onPressed: _formOpen ? null : () => _openForm(),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Table'),
            ),
        ],
      ),
    );
  }

  Widget _form(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editingNo == null
                ? 'NEW TABLE'
                : 'EDITING TABLE ${_pad(_editingNo!)}',
            style: textTheme.labelMedium?.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _numController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Table #',
                    fillColor: AppColors.surface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _seatsController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Seats',
                    fillColor: AppColors.surface,
                  ),
                  onSubmitted: (_) => _submitForm(),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _closeForm, child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                icon: const Icon(Icons.check, size: 16),
                label: Text(_editingNo == null ? 'Insert' : 'Update'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableRow(TableDraft table) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      padding: const EdgeInsets.all(10),
      color: AppColors.background,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            color: AppColors.lightSlot,
            child: Text(_pad(table.tableNo), style: textTheme.labelLarge),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Table ${_pad(table.tableNo)}',
                style: textTheme.labelLarge),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: AppColors.surface,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_seat,
                    size: 14, color: AppColors.secondary),
                const SizedBox(width: 4),
                Text('${table.seats} Seats', style: textTheme.bodySmall),
              ],
            ),
          ),
          if (!widget.readOnly) ...[
            IconButton(
              onPressed: () => _openForm(editing: table),
              icon: const Icon(Icons.edit, size: 16),
              tooltip: 'Edit table ${_pad(table.tableNo)}',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: () => _delete(table),
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: AppColors.danger),
              tooltip: 'Delete table ${_pad(table.tableNo)}',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      color: AppColors.lightSlot,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.readOnly ? 'Close' : 'Cancel'),
          ),
          if (!widget.readOnly) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save Table Allocations'),
            ),
          ],
        ],
      ),
    );
  }
}