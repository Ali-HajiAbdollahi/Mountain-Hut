import 'package:flutter/material.dart';

import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/debouncer.dart';

/// A hiker returned by GET /api/staff/hikers?query=
class HikerResult {
  const HikerResult({
    required this.uId,
    required this.name,
    this.email,
    this.phone,
  });

  factory HikerResult.fromJson(Map<String, dynamic> json) => HikerResult(
        uId: (json['uID'] as num).toInt(),
        name: json['name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
      );

  final int uId;
  final String name;
  final String? email;
  final String? phone;

  String get subtitle {
    final parts = [?email, ?phone];
    return parts.join(' · ');
  }
}

/// Search bar that queries the staff hiker-lookup API.
/// Calls [onSelected] when the employee taps a result.
/// Calls [onNotFound] when the query is non-empty but no results are found,
/// so the parent can show the "Add New Hiker" form.
class HikerLookupField extends StatefulWidget {
  const HikerLookupField({
    required this.api,
    required this.onSelected,
    required this.onNotFound,
    this.onCleared,
    super.key,
  });

  final MountainHutApi api;
  final ValueChanged<HikerResult> onSelected;
  final ValueChanged<String> onNotFound;
  final VoidCallback? onCleared;

  @override
  State<HikerLookupField> createState() => _HikerLookupFieldState();
}

class _HikerLookupFieldState extends State<HikerLookupField> {
  final _controller = TextEditingController();
  final _debouncer = Debouncer();
  final _focusNode = FocusNode();

  List<HikerResult> _results = const [];
  bool _loading = false;
  bool _searched = false;
  String? _error;
  HikerResult? _selected;
  bool _showDropdown = false;

  @override
  void dispose() {
    _controller.dispose();
    _debouncer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _searched = false;
        _loading = false;
        _error = null;
        _showDropdown = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _searched = false;
    });

    try {
      final data = await widget.api.searchHikers(q);
      if (!mounted) return;
      final results = data.map(HikerResult.fromJson).toList();
      setState(() {
        _results = results;
        _loading = false;
        _searched = true;
        _showDropdown = results.isNotEmpty;
      });
      if (results.isEmpty) widget.onNotFound(q);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _searched = true;
        _showDropdown = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the server.';
        _loading = false;
        _searched = true;
        _showDropdown = false;
      });
    }
  }

  void _select(HikerResult hiker) {
    setState(() {
      _selected = hiker;
      _showDropdown = false;
      _results = const [];
      _searched = false;
    });
    _controller.text = hiker.name;
    _focusNode.unfocus();
    widget.onSelected(hiker);
  }

  void _clear() {
    setState(() {
      _selected = null;
      _results = const [];
      _searched = false;
      _loading = false;
      _error = null;
      _showDropdown = false;
    });
    _controller.clear();
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'QUICK HIKER LOOKUP',
          style: textTheme.labelMedium?.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: _selected == null,
          decoration: InputDecoration(
            hintText: 'Search by name, mobile, or email…',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clear,
                        tooltip: 'Clear',
                      )
                    : null),
          ),
          onChanged: (v) {
            if (_selected != null) return;
            setState(() => _showDropdown = false);
            _debouncer.run(() => _search(v));
          },
          onTap: () {
            if (_selected == null && _results.isNotEmpty) {
              setState(() => _showDropdown = true);
            }
          },
        ),
        if (_showDropdown && _results.isNotEmpty) _dropdown(),
        if (!_loading && _searched && _results.isEmpty && _error == null)
          _statusBar(
            icon: Icons.person_search,
            text: 'No registered hiker found. '
                'Use the form below to add one.',
            color: AppColors.textSecondary,
          ),
        if (_error != null)
          _statusBar(
            icon: Icons.error_outline,
            text: _error!,
            color: AppColors.danger,
          ),
        if (_selected != null) _selectedCard(),
      ],
    );
  }

  Widget _dropdown() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
      ),
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: _results.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.lightBorder),
        itemBuilder: (_, i) {
          final h = _results[i];
          return InkWell(
            onTap: () => _select(h),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.name,
                            style: Theme.of(context).textTheme.labelLarge),
                        if (h.subtitle.isNotEmpty)
                          Text(
                            h.subtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: AppColors.secondary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusBar({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.background,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedCard() {
    final h = _selected!;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      color: AppColors.successBadge,
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name,
                    style: Theme.of(context).textTheme.labelLarge),
                if (h.subtitle.isNotEmpty)
                  Text(
                    h.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _clear,
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}