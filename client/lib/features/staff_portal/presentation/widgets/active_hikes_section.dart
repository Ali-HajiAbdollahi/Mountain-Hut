import 'package:flutter/material.dart';

import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';

class ActiveHikesSection extends StatefulWidget {
  const ActiveHikesSection({required this.api, super.key});

  final MountainHutApi api;

  @override
  State<ActiveHikesSection> createState() => _ActiveHikesSectionState();
}

class _ActiveHikesSectionState extends State<ActiveHikesSection> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _hikes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final hikes = await widget.api.listActiveHikes();
      if (!mounted) return;
      setState(() {
        _hikes = hikes;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load active hikes.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.danger,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_hikes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hiking, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'No active hikes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Active hikes will appear here when hikers depart.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '${_hikes.length} active ${_hikes.length == 1 ? 'hike' : 'hikes'}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          ..._hikes.map(_buildHikeCard),
        ],
      ),
    );
  }

  Widget _buildHikeCard(Map<String, dynamic> hike) {
    final waypoints = (hike['waypoints'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((point) => point['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hike['hiker_name']?.toString() ?? 'Unknown hiker',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(Icons.directions_walk, color: AppColors.success),
              ],
            ),
            const Divider(height: 24),
            _detail(
              Icons.flag_outlined,
              'Destination',
              hike['destination']?.toString() ?? 'Not specified',
            ),
            if ((hike['route']?.toString() ?? '').isNotEmpty)
              _detail(Icons.route, 'Route', hike['route'].toString()),
            _detail(
              Icons.schedule,
              'Expected return',
              hike['expected_return']?.toString() ?? 'Not specified',
            ),
            if (waypoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'WAYPOINTS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              ...waypoints.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${entry.key + 1}. ${entry.value}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
