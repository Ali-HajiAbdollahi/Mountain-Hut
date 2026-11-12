import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../widgets/cancel_booking_modal.dart';
import '../widgets/modify_reservation_modal.dart';

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({required this.api, this.authRepository, super.key});

  final MountainHutApi api;
  final AuthRepository? authRepository;

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _bookings = const [];
  bool _loading = true;
  String? _error;
  Timer? _bookingEndTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBookings();
  }

  @override
  void dispose() {
    _bookingEndTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadBookings();
    }
  }

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bookings = await widget.api.myBookings();
      bookings.sort((a, b) {
        DateTime parse(Object? value) =>
            DateTime.parse((value?.toString() ?? '').replaceFirst(' ', 'T'));
        final left = parse(a['start_time']);
        final right = parse(b['start_time']);
        return right.compareTo(left);
      });
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
      _scheduleBookingEndUpdate();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load bookings: $error';
        });
      }
    }
  }

  void _scheduleBookingEndUpdate() {
    _bookingEndTimer?.cancel();
    final now = DateTime.now();
    DateTime? nextEnd;
    for (final booking in _bookings) {
      final end = _bookingEnd(booking);
      if (end != null &&
          end.isAfter(now) &&
          (nextEnd == null || end.isBefore(nextEnd))) {
        nextEnd = end;
      }
    }
    if (nextEnd == null) return;
    _bookingEndTimer = Timer(nextEnd.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleBookingEndUpdate();
    });
  }

  bool _isModifiable(Map<String, dynamic> booking) {
    final start = booking['start_time']?.toString();
    if (start == null) return false;
    final parsed = DateTime.tryParse(start.replaceFirst(' ', 'T'));
    return parsed != null &&
        parsed.difference(DateTime.now()) >= const Duration(hours: 48);
  }

  Future<void> _modify(Map<String, dynamic> booking) async {
    if (!await showModifyReservationModal(
      context,
      booking: booking,
      api: widget.api,
    )) {
      return;
    }
    await _loadBookings();
  }

  Future<void> _cancel(Map<String, dynamic> booking) async {
    if (!await showCancelBookingModal(
      context,
      booking: booking,
      api: widget.api,
    )) {
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your booking was successfully cancelled.')),
    );
    await _loadBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        leading: const Icon(
          Icons.landscape_outlined,
          color: AppColors.tertiary,
        ),
        title: const Text('My Bookings'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppConstants.myBookingsContentMaxWidth,
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorState(message: _error!, onRetry: _loadBookings)
                : ListView(
                    padding: const EdgeInsets.all(AppConstants.spacingMd),
                    children: [
                      Text(
                        'My Reservations',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Manage your upcoming mountain hut dining bookings.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      const _PolicyNotice(),
                      const SizedBox(height: AppConstants.spacingMd),
                      if (_bookings.isEmpty)
                        const _EmptyState()
                      else
                        for (final booking in _bookings)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppConstants.spacingMd,
                            ),
                            child: _BookingCard(
                              booking: booking,
                              modifiable: _isModifiable(booking),
                              onModify: () => _modify(booking),
                              onCancel: () => _cancel(booking),
                            ),
                          ),
                    ],
                  ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        role: AppNavigationRole.hiker,
        selectedTab: AppNavigationTab.bookings,
        onExplore: widget.authRepository == null
            ? () => AppNavigation.navigatorKey.currentState?.popUntil(
                (route) => route.isFirst,
              )
            : () => AppNavigation.navigatorKey.currentState?.pushReplacement(
                AppNavigation.explore(
                  authRepository: widget.authRepository!,
                  api: widget.api,
                ),
              ),
        onAccount: () {
          final navigator = AppNavigation.navigatorKey.currentState;
          if (navigator == null) return;
          navigator.push(
            AppNavigation.account(
              api: widget.api,
              authRepository: widget.authRepository,
              onExplore: widget.authRepository == null
                  ? () => navigator.popUntil((route) => route.isFirst)
                  : () => navigator.pushReplacement(
                      AppNavigation.explore(
                        authRepository: widget.authRepository!,
                        api: widget.api,
                      ),
                    ),
              onBookings: () => navigator.pushReplacement(
                AppNavigation.myBookings(
                  api: widget.api,
                  authRepository: widget.authRepository,
                ),
              ),
              onLogout: widget.authRepository == null
                  ? null
                  : () => navigator.pushAndRemoveUntil(
                      AppNavigation.explore(
                        authRepository: widget.authRepository!,
                        api: widget.api,
                      ),
                      (route) => false,
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.modifiable,
    required this.onModify,
    required this.onCancel,
  });

  final Map<String, dynamic> booking;
  final bool modifiable;
  final VoidCallback onModify;
  final VoidCallback onCancel;

  String get _reference => '#${booking['reference'] ?? 'MH-${booking['bID']}'}';

  String _time(Object? value) {
    final text = value?.toString() ?? '';
    return text.length >= 16 ? text.substring(11, 16) : text;
  }

  String get _date {
    final text = booking['start_time']?.toString() ?? '';
    return text.length >= 10 ? text.substring(0, 10) : text;
  }

  String get _tables {
    final values = booking['tables'];
    if (values is! List) return 'Table assignment pending';
    final numbers =
        values
            .whereType<Map>()
            .map((item) => item['table_no'])
            .whereType<num>()
            .map((number) => number.toInt())
            .toList()
          ..sort();
    return numbers.isEmpty
        ? 'Table assignment pending'
        : '${numbers.length == 1 ? 'Table' : 'Tables'} ${numbers.join(' & ')}';
  }

  String get _requirements {
    final values = booking['requirements'];
    if (values is! List || values.isEmpty) return 'No dietary requirements';
    return values
        .whereType<Map>()
        .map((item) {
          final description = item['description']?.toString() ?? '';
          return item['allergy'] == true
              ? '$description (Allergy Flag)'
              : description;
        })
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final end = _bookingEnd(booking);
    final canCancel = end != null && end.isAfter(DateTime.now());
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'REF  $_reference',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                _StatusBadge(modifiable: modifiable),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Row(
              children: [
                Expanded(
                  child: _DetailBox(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date & Slot',
                    value:
                        '$_date\n${_time(booking['start_time'])} - ${_time(booking['end_time'])}',
                  ),
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: _DetailBox(
                    icon: Icons.groups_outlined,
                    label: 'Party Size',
                    value: '${booking['n_people'] ?? 0} Guests\n$_tables',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Container(
              color: AppColors.infoSurface,
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              child: Row(
                children: [
                  const Icon(Icons.restaurant_outlined, size: 16),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: Text(
                      _requirements,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            if (modifiable) ...[
              _BookingPolicyBox(until: _modifiableUntil(booking['start_time'])),
              const SizedBox(height: AppConstants.spacingSm),
              FilledButton.icon(
                onPressed: onModify,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('EDIT / CHANGE BOOKING'),
              ),
            ] else ...[
              const _LockedWarningBox(),
              const SizedBox(height: AppConstants.spacingSm),
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.lock_outline),
                label: const Text('MODIFICATION LOCKED'),
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: AppConstants.spacingSm),
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('CANCEL BOOKING'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
            ] else if (end == null) ...[
              const SizedBox(height: AppConstants.spacingSm),
              const Text('Cancellation unavailable: invalid booking end time.'),
            ],
          ],
        ),
      ),
    );
  }
}

DateTime? _bookingEnd(Map<String, dynamic> booking) => DateTime.tryParse(
  (booking['end_time']?.toString() ?? '').replaceFirst(' ', 'T'),
);

class _BookingPolicyBox extends StatelessWidget {
  const _BookingPolicyBox({required this.until});

  final String until;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.infoBadge,
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.primary, size: 16),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              'Modifiable until $until (more than 48h before slot)',
              style: const TextStyle(fontSize: 11, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

String _modifiableUntil(Object? value) {
  final start = DateTime.tryParse(
    (value?.toString() ?? '').replaceFirst(' ', 'T'),
  );
  if (start == null) return '48 hours before the slot';
  final until = start.subtract(const Duration(hours: 48));
  final month = until.month.toString().padLeft(2, '0');
  final day = until.day.toString().padLeft(2, '0');
  return '${until.year}-$month-$day, '
      '${until.hour.toString().padLeft(2, '0')}:'
      '${until.minute.toString().padLeft(2, '0')}';
}

class _LockedWarningBox extends StatelessWidget {
  const _LockedWarningBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.errorSurface,
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      child: const Row(
        children: [
          Icon(Icons.lock_person_outlined, color: AppColors.danger, size: 18),
          SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              'Editing is locked: Changes must be made at least 48 hours in advance.',
              style: TextStyle(fontSize: 11, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.modifiable});

  final bool modifiable;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: modifiable ? AppColors.successBadge : AppColors.lightControl,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        modifiable ? '● Confirmed' : '🔒 Editing locked',
        style: TextStyle(
          color: modifiable ? AppColors.tertiary : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DetailBox extends StatelessWidget {
  const _DetailBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.infoSurface,
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PolicyNotice extends StatelessWidget {
  const _PolicyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.infoSurface,
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              'Mountain Table Policy: Reservations can be modified up to 48 hours before your slot and cancelled until the slot ends.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppConstants.spacingXl),
      child: Center(child: Text('You have no upcoming reservations.')),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppConstants.spacingSm),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
