import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/rich_text_controller.dart';
import '../../domain/entities/service_slot.dart';

class SlotMenuConfigurationCard extends StatefulWidget {
  const SlotMenuConfigurationCard({
    required this.api,
    required this.slot,
    required this.reusableSlots,
    required this.onMenuPublished,
    super.key,
  });

  final MountainHutApi api;
  final ServiceSlot? slot;
  final List<ServiceSlot> reusableSlots;
  final void Function(int slotId, String menu) onMenuPublished;

  @override
  State<SlotMenuConfigurationCard> createState() =>
      _SlotMenuConfigurationCardState();
}

class _SlotMenuConfigurationCardState extends State<SlotMenuConfigurationCard> {
  static const _bullet = '• ';
  static const _indent = '  ';

  final _menuController = RichTextController();
  final _editorFocus = FocusNode();
  int? _sourceSlotId;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _menuController
      ..loadHtml(widget.slot?.menu ?? '')
      ..addListener(_onEditorChanged);
  }

  @override
  void didUpdateWidget(covariant SlotMenuConfigurationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final slotChanged = oldWidget.slot?.id != widget.slot?.id;
    final menuChanged = oldWidget.slot?.menu != widget.slot?.menu;
    if (slotChanged || menuChanged) {
      final menu = widget.slot?.menu ?? '';
      if (slotChanged || menu != _menuController.toHtml()) {
        _menuController.loadHtml(menu);
      }
      _sourceSlotId = null;
    }
  }

  @override
  void dispose() {
    _menuController
      ..removeListener(_onEditorChanged)
      ..dispose();
    _editorFocus.dispose();
    super.dispose();
  }

  void _onEditorChanged() {
    if (mounted) setState(() {});
  }

  List<ServiceSlot> get _previousMenus {
    final slot = widget.slot;
    if (slot == null) return const [];
    return widget.reusableSlots
        .where(
          (candidate) =>
              candidate.id != slot.id &&
              candidate.startTime.compareTo(slot.startTime) < 0 &&
              candidate.menu?.trim().isNotEmpty == true,
        )
        .toList();
  }

  void _applyPreviousMenu() {
    final source = _previousMenus
        .where((candidate) => candidate.id == _sourceSlotId)
        .firstOrNull;
    if (source?.menu == null) return;
    _menuController.loadHtml(source!.menu!);
  }

  void _toggleStyle(RichTextStyle style) {
    _menuController.toggle(style);
    _editorFocus.requestFocus();
  }

  int get _currentLineStart {
    final text = _menuController.text;
    final selection = _menuController.selection;
    final offset = (selection.isValid ? selection.start : text.length)
        .clamp(0, text.length)
        .toInt();
    return offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
  }

  void _toggleBullet() {
    final text = _menuController.text;
    final selection = _menuController.selection;
    final lineStarts = <int>[_currentLineStart];
    if (selection.isValid && !selection.isCollapsed) {
      final end = selection.end.clamp(0, text.length);
      var newline = text.indexOf('\n', lineStarts.first);
      while (newline != -1 && newline + 1 < end) {
        lineStarts.add(newline + 1);
        newline = text.indexOf('\n', newline + 1);
      }
    }

    final remove = lineStarts.every((start) => text.startsWith(_bullet, start));
    for (final start in lineStarts.reversed) {
      if (remove || !text.startsWith(_bullet, start)) {
        _editLineStartAt(
          start,
          remove ? _bullet.length : 0,
          remove ? '' : _bullet,
        );
      }
    }
    _editorFocus.requestFocus();
  }

  void _indentLine() {
    _editLineStartAt(_currentLineStart, 0, _indent);
    _editorFocus.requestFocus();
  }

  void _editLineStartAt(int lineStart, int removeLength, String insert) {
    final selection = _menuController.selection;
    final delta = insert.length - removeLength;
    int shift(int offset) => offset >= lineStart
        ? (offset + delta).clamp(lineStart, _menuController.text.length + delta)
        : offset;
    final after = selection.isValid
        ? TextSelection(
            baseOffset: shift(selection.baseOffset),
            extentOffset: shift(selection.extentOffset),
            affinity: selection.affinity,
            isDirectional: selection.isDirectional,
          )
        : TextSelection.collapsed(offset: _menuController.text.length + delta);
    _menuController.replaceRange(
      lineStart,
      lineStart + removeLength,
      insert,
      after,
    );
  }

  Future<void> _publishMenu() async {
    final slot = widget.slot;
    if (_publishing || slot == null || _menuController.text.trim().isEmpty) {
      return;
    }
    final menu = _menuController.toHtml();

    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await widget.api.publishSlotMenu(slot.id, menu);
      final savedMenu = response['menu'];
      if (savedMenu is! String) {
        throw const ApiException(
          200,
          'INVALID_RESPONSE',
          'The server returned an invalid menu response.',
        );
      }
      if (!mounted) return;
      widget.onMenuPublished(slot.id, savedMenu);
      messenger.showSnackBar(
        const SnackBar(content: Text('Menu published successfully.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Exception catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not publish menu: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final slot = widget.slot;
    final previousMenus = _previousMenus;
    final selectedSource = previousMenus
        .where((candidate) => candidate.id == _sourceSlotId)
        .firstOrNull;
    final hasMenu = _menuController.text.trim().isNotEmpty;

    return Container(
      key: const ValueKey('slot-menu-card'),
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
            children: [
              const Icon(
                Icons.restaurant,
                color: AppColors.primary,
                size: AppConstants.spacingLg,
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Text(
                  'SLOT MENU CONFIGURATION',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm,
                  vertical: AppConstants.spacingXs,
                ),
                color: AppColors.infoBadge,
                child: Text(
                  slot == null
                      ? 'NO SLOT'
                      : '${slot.startLabel}–${slot.endLabel}',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
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
                      Icons.history,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: AppConstants.spacingXs),
                    Text(
                      'REUSE PREVIOUS MENU',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        key: const ValueKey('reuse-menu-select'),
                        value: selectedSource?.id,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        hint: Text(
                          previousMenus.isEmpty
                              ? 'No earlier menus available'
                              : 'Choose a previous menu',
                          style: textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: previousMenus
                            .map(
                              (candidate) => DropdownMenuItem(
                                value: candidate.id,
                                child: Text(
                                  '${candidate.startLabel}–${candidate.endLabel}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: previousMenus.isEmpty || _publishing
                            ? null
                            : (value) => setState(() => _sourceSlotId = value),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    TextButton(
                      key: const ValueKey('apply-previous-menu'),
                      onPressed: selectedSource == null || _publishing
                          ? null
                          : _applyPreviousMenu,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.infoBadge,
                        foregroundColor: AppColors.primary,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingMd,
                        ),
                        minimumSize: const Size(0, AppConstants.spacingXl),
                      ),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            'MENU DETAILS',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.lightBorder),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingXs,
                    vertical: AppConstants.spacingXs,
                  ),
                  color: AppColors.lightControl,
                  child: Row(
                    children: [
                      _toolbarButton(
                        label: 'B',
                        tooltip: 'Bold',
                        onPressed: slot == null || _publishing
                            ? null
                            : () => _toggleStyle(RichTextStyle.bold),
                        active: _menuController.isActive(RichTextStyle.bold),
                        bold: true,
                      ),
                      _toolbarButton(
                        label: 'I',
                        tooltip: 'Italic',
                        onPressed: slot == null || _publishing
                            ? null
                            : () => _toggleStyle(RichTextStyle.italic),
                        active: _menuController.isActive(RichTextStyle.italic),
                        italic: true,
                      ),
                      SizedBox(
                        width: AppConstants.spacingLg,
                        height: AppConstants.spacingLg,
                        child: PopupMenuButton<int>(
                          tooltip: 'Font size',
                          enabled: slot != null && !_publishing,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.format_size, size: 16),
                          onSelected: (size) {
                            _menuController.setFontSize(
                              size == 0 ? null : size,
                            );
                            _editorFocus.requestFocus();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 0,
                              child: Text('Default'),
                            ),
                            for (final size in [12, 14, 16, 18, 20, 24])
                              PopupMenuItem(value: size, child: Text('$size')),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingXs),
                      Container(
                        width: 1,
                        height: AppConstants.spacingMd,
                        color: AppColors.lightBorder,
                      ),
                      const SizedBox(width: AppConstants.spacingXs),
                      IconButton(
                        tooltip: 'Bulleted list',
                        onPressed: slot == null || _publishing
                            ? null
                            : _toggleBullet,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: AppConstants.spacingLg,
                          height: AppConstants.spacingLg,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.format_list_bulleted, size: 16),
                      ),
                      IconButton(
                        tooltip: 'Indent',
                        onPressed: slot == null || _publishing
                            ? null
                            : _indentLine,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: AppConstants.spacingLg,
                          height: AppConstants.spacingLg,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.format_indent_increase,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                TextField(
                  key: const ValueKey('slot-menu-editor'),
                  controller: _menuController,
                  focusNode: _editorFocus,
                  enabled: slot != null && !_publishing,
                  minLines: 8,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(AppConstants.spacingMd),
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.text,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (slot == null)
            Padding(
              padding: const EdgeInsets.only(top: AppConstants.spacingXs),
              child: Text(
                'Select or create a service slot before adding its menu.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ),
          const SizedBox(height: AppConstants.spacingMd),
          FilledButton.icon(
            key: const ValueKey('publish-slot-menu'),
            onPressed: slot == null || !hasMenu || _publishing
                ? null
                : _publishMenu,
            icon: _publishing
                ? const SizedBox(
                    width: AppConstants.spacingMd,
                    height: AppConstants.spacingMd,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish, size: 18),
            label: Text(
              _publishing ? 'PUBLISHING MENU...' : 'SAVE & PUBLISH MENU',
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton({
    required String label,
    required String tooltip,
    required VoidCallback? onPressed,
    bool active = false,
    bool bold = false,
    bool italic = false,
  }) {
    return SizedBox(
      width: AppConstants.spacingLg,
      height: AppConstants.spacingLg,
      child: Tooltip(
        message: tooltip,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            backgroundColor: active ? AppColors.infoBadge : null,
            foregroundColor: active ? AppColors.primary : AppColors.text,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ),
    );
  }
}
