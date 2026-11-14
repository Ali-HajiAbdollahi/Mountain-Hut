import 'package:flutter/material.dart';

/// Character styles supported by [RichTextController].
enum RichTextStyle {
  bold(1),
  italic(2);

  const RichTextStyle(this.flag);

  final int flag;
}

/// A [TextEditingController] that keeps character formatting and renders it
/// so the editor shows formatted text instead of markup characters.
///
/// The formatted content is exchanged with the backend as simple HTML
/// (`<strong>`, `<em>`, font-size spans, `<br>`) through [toHtml] and [loadHtml].
class RichTextController extends TextEditingController {
  RichTextController({String? html}) {
    if (html != null) loadHtml(html);
  }

  static final _token = RegExp(
    r'<(/?)(strong|b|em|i)>|<br\s*/?>|&(amp|lt|gt|quot|#39);|<span\s+style="font-size:\s*[1-9]\d?px"\s*>|</span\s*>|[^<&]+|[\s\S]',
    caseSensitive: false,
  );
  static final _fontSizeToken = RegExp(r'[1-9]\d?');
  static const _fontSizeShift = 2;
  static const _fontSizeMask = 0xff << _fontSizeShift;

  List<int> _flags = [];
  int? _typingFlags;
  bool _applyingEdit = false;

  /// Whether [style] applies to the selection, or to the next typed text when
  /// the selection is collapsed.
  bool isActive(RichTextStyle style) {
    final selection = this.selection;
    if (!selection.isValid || text.isEmpty) {
      return (_typingFlags ?? 0) & style.flag != 0;
    }
    if (selection.isCollapsed) {
      return (_typingFlags ?? _flagsBefore(selection.start)) & style.flag != 0;
    }
    for (var i = selection.start; i < selection.end; i++) {
      if (_flags[i] & style.flag == 0) return false;
    }
    return true;
  }

  void toggle(RichTextStyle style) {
    final selection = this.selection;
    if (!selection.isValid || selection.isCollapsed) {
      final current = _typingFlags ?? _flagsBefore(_caret);
      _typingFlags = current ^ style.flag;
    } else {
      final enable = !isActive(style);
      for (var i = selection.start; i < selection.end; i++) {
        _flags[i] = enable ? _flags[i] | style.flag : _flags[i] & ~style.flag;
      }
    }
    notifyListeners();
  }

  /// Applies a font size to the selection, or to subsequently typed text.
  /// A null size restores the editor's default.
  void setFontSize(int? size) {
    if (size != null && (size < 1 || size > 99)) {
      throw RangeError.range(size, 1, 99, 'size');
    }
    int withSize(int flags) =>
        (flags & ~_fontSizeMask) | ((size ?? 0) << _fontSizeShift);
    final selection = this.selection;
    if (!selection.isValid || selection.isCollapsed) {
      _typingFlags = withSize(_typingFlags ?? _flagsBefore(_caret));
    } else {
      for (var i = selection.start; i < selection.end; i++) {
        _flags[i] = withSize(_flags[i]);
      }
    }
    notifyListeners();
  }

  /// Replaces `[start, end)` with [insert]; the inserted text inherits the
  /// style of the character before it unless a style was toggled by the user.
  void replaceRange(int start, int end, String insert, TextSelection after) {
    final inherited = _typingFlags ?? _flagsBefore(start);
    _flags = [
      ..._flags.sublist(0, start),
      ...List.filled(insert.length, inherited),
      ..._flags.sublist(end),
    ];
    final newText = text.replaceRange(start, end, insert);
    _applyingEdit = true;
    super.value = TextEditingValue(text: newText, selection: after);
    _applyingEdit = false;
  }

  /// Replaces the whole content with [html], hiding the markup.
  void loadHtml(String html) {
    final buffer = StringBuffer();
    final flags = <int>[];
    var bold = 0;
    var italic = 0;
    final fontSizes = <int>[];

    void add(String value) {
      buffer.write(value);
      final current =
          (bold > 0 ? RichTextStyle.bold.flag : 0) |
          (italic > 0 ? RichTextStyle.italic.flag : 0) |
          ((fontSizes.isEmpty ? 0 : fontSizes.last) << _fontSizeShift);
      flags.addAll(List.filled(value.length, current));
    }

    for (final match in _token.allMatches(html)) {
      final value = match.group(0)!;
      final tag = match.group(2)?.toLowerCase();
      final entity = match.group(3);
      if (tag != null) {
        final delta = match.group(1) == '/' ? -1 : 1;
        if (tag == 'strong' || tag == 'b') {
          bold = (bold + delta).clamp(0, 1 << 20).toInt();
        } else {
          italic = (italic + delta).clamp(0, 1 << 20).toInt();
        }
      } else if (value.toLowerCase().startsWith('<br')) {
        add('\n');
      } else if (value.toLowerCase().startsWith('<span')) {
        fontSizes.add(int.parse(_fontSizeToken.firstMatch(value)!.group(0)!));
      } else if (value.toLowerCase().startsWith('</span')) {
        if (fontSizes.isNotEmpty) fontSizes.removeLast();
      } else if (entity != null) {
        add(switch (entity) {
          'amp' => '&',
          'lt' => '<',
          'gt' => '>',
          'quot' => '"',
          _ => "'",
        });
      } else {
        add(value);
      }
    }

    _flags = flags;
    _typingFlags = null;
    _applyingEdit = true;
    super.value = TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
    _applyingEdit = false;
  }

  String toHtml() {
    final buffer = StringBuffer();
    var start = 0;
    while (start < text.length) {
      var end = start + 1;
      while (end < text.length && _flags[end] == _flags[start]) {
        end++;
      }
      final flags = _flags[start];
      final bold = flags & RichTextStyle.bold.flag != 0;
      final italic = flags & RichTextStyle.italic.flag != 0;
      final fontSize = (flags & _fontSizeMask) >> _fontSizeShift;
      if (fontSize != 0) {
        buffer.write('<span style="font-size: ${fontSize}px">');
      }
      if (bold) buffer.write('<strong>');
      if (italic) buffer.write('<em>');
      buffer.write(
        text
            .substring(start, end)
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('\n', '<br>'),
      );
      if (italic) buffer.write('</em>');
      if (bold) buffer.write('</strong>');
      if (fontSize != 0) buffer.write('</span>');
      start = end;
    }
    return buffer.toString();
  }

  @override
  set value(TextEditingValue newValue) {
    if (_applyingEdit) {
      super.value = newValue;
      return;
    }
    final oldText = text;
    if (newValue.text == oldText) {
      if (newValue.selection != selection) _typingFlags = null;
      super.value = newValue;
      return;
    }
    _syncFlags(oldText, newValue);
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) return TextSpan(style: style, text: '');

    final spans = <InlineSpan>[];
    var start = 0;
    while (start < text.length) {
      var end = start + 1;
      while (end < text.length && _flags[end] == _flags[start]) {
        end++;
      }
      final flags = _flags[start];
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            fontSize: (flags & _fontSizeMask) == 0
                ? null
                : ((flags & _fontSizeMask) >> _fontSizeShift).toDouble(),
            fontWeight: flags & RichTextStyle.bold.flag != 0
                ? FontWeight.bold
                : null,
            fontStyle: flags & RichTextStyle.italic.flag != 0
                ? FontStyle.italic
                : null,
          ),
        ),
      );
      start = end;
    }
    return TextSpan(style: style, children: spans);
  }

  int get _caret => selection.isValid ? selection.start : text.length;

  int _flagsBefore(int offset) {
    if (_flags.isEmpty) return 0;
    if (offset > 0) return _flags[offset - 1];
    return _flags.first;
  }

  // Aligns the per-character styles with a text change made by the keyboard.
  void _syncFlags(String oldText, TextEditingValue newValue) {
    final newText = newValue.text;
    final cursor = newValue.selection.isValid && newValue.selection.isCollapsed
        ? newValue.selection.baseOffset
        : newText.length;

    var suffix = 0;
    if (cursor <= newText.length &&
        oldText.endsWith(newText.substring(cursor))) {
      suffix = newText.length - cursor;
    } else {
      final limit = oldText.length < newText.length
          ? oldText.length
          : newText.length;
      while (suffix < limit &&
          oldText[oldText.length - 1 - suffix] ==
              newText[newText.length - 1 - suffix]) {
        suffix++;
      }
    }

    final maxPrefix =
        (oldText.length < newText.length ? oldText.length : newText.length) -
        suffix;
    var prefix = 0;
    while (prefix < maxPrefix && oldText[prefix] == newText[prefix]) {
      prefix++;
    }

    final inserted = newText.length - prefix - suffix;
    final inherited = _typingFlags ?? _flagsBefore(prefix);
    _flags = [
      ..._flags.sublist(0, prefix),
      ...List.filled(inserted < 0 ? 0 : inserted, inherited),
      ..._flags.sublist(oldText.length - suffix),
    ];
    if (_flags.length != newText.length) {
      _flags = List.filled(newText.length, 0);
    }
  }
}
