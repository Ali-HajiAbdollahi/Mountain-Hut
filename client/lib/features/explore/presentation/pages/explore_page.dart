import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/auth_context.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../booking/domain/entities/booking_allocation.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    required this.authRepository,
    required this.api,
    super.key,
  });

  final AuthRepository authRepository;
  final MountainHutApi api;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  bool _hasCheckedAvailability = false;
  bool _isCheckingAvailability = false;
  bool _isLoadingSlots = true;
  bool _isHikerSignedIn = false;
  String? _errorMessage;
  String? _slotsErrorMessage;
  Map<String, dynamic>? _availability;
  List<Map<String, dynamic>> _slots = const [];
  int _guests = 6;
  int _selectedSlot = 0;
  int _availabilityRequestVersion = 0;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _restoreSession();
    _loadSlots();
  }

  Future<void> _restoreSession() async {
    try {
      final user = await widget.api.currentUser();
      if (mounted && user['role'] == 'hiker') {
        setState(() => _isHikerSignedIn = true);
      }
    } on ApiException {
      // An anonymous visitor is expected when no session exists.
    }
  }

  Future<void> _loadSlots() async {
    final date = _formatDate(_selectedDate);
    _availabilityRequestVersion++;
    setState(() {
      _isLoadingSlots = true;
      _slotsErrorMessage = null;
      _hasCheckedAvailability = false;
      _availability = null;
    });
    try {
      final slots = await widget.api.listSlots(date);
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _isLoadingSlots = false;
        _slotsErrorMessage = null;
        _selectedSlot = 0;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingSlots = false;
        _slotsErrorMessage = error.message;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingSlots = false;
        _slotsErrorMessage = 'Unable to load meal service slots: $error';
      });
    }
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final firstSelectableDate = DateTime(today.year, today.month, today.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(firstSelectableDate)
          ? firstSelectableDate
          : _selectedDate,
      firstDate: firstSelectableDate,
      lastDate: DateTime(2035),
    );
    if (date == null || !mounted) return;
    setState(() => _selectedDate = date);
    await _loadSlots();
  }

  Future<void> _checkAvailability() async {
    final requestVersion = ++_availabilityRequestVersion;
    final requestedDate = _formatDate(_selectedDate);
    final requestedGuests = _guests;
    final requestedSlot = _selectedSlot;
    setState(() {
      _isCheckingAvailability = true;
      _hasCheckedAvailability = false;
      _availability = null;
      _errorMessage = null;
    });
    try {
      if (_slots.isEmpty) return;
      final selectedSlot = _slots[requestedSlot];
      final result = await widget.api.checkAvailability(
        date: requestedDate,
        time: _slotTime(selectedSlot['start_time']),
        partySize: requestedGuests,
      );
      if (!mounted) return;
      if (requestVersion != _availabilityRequestVersion) return;
      setState(() {
        _availability = result;
        _hasCheckedAvailability = true;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to check availability: $error');
      }
    } finally {
      if (mounted) setState(() => _isCheckingAvailability = false);
    }
  }

  String _slotTime(Object? value) {
    final startTime = value?.toString() ?? '';
    return startTime.length >= 16 ? startTime.substring(11, 16) : startTime;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _displayDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  void _invalidateAvailability() {
    _availabilityRequestVersion++;
    setState(() {
      _hasCheckedAvailability = false;
      _availability = null;
      _errorMessage = null;
    });
  }

  void _openAuth(AuthContext authContext) {
    if (authContext == AuthContext.tableReservation && _isHikerSignedIn) {
      _openBooking();
      return;
    }

    void handleAuthenticatedUser(Map<String, dynamic> user) {
      if (user['role'] != 'hiker' || !mounted) return;
      if (authContext == AuthContext.tableReservation) {
        setState(() => _isHikerSignedIn = true);
        Navigator.of(context).pop();
        _openBooking();
        return;
      }
      setState(() => _isHikerSignedIn = true);
      Navigator.of(context).pop();
    }

    Navigator.of(context).push(
      AppNavigation.auth(
        authRepository: widget.authRepository,
        authContext: authContext,
        onSignIn: handleAuthenticatedUser,
        onRegister: handleAuthenticatedUser,
      ),
    );
  }

  void _openBooking() {
    final slot = _selectedSlotDetails;
    final slotId = _intValue(slot?['tsID']);
    if (slotId == null) {
      setState(() {
        _errorMessage = 'The selected meal slot is no longer available.';
      });
      return;
    }
    Navigator.of(context).push(
      AppNavigation.booking(
        api: widget.api,
        allocation: BookingAllocation(
          date: _displayDate(_selectedDate),
          slotId: slotId,
          startTime: _timeLabel(slot?['start_time']),
          endTime: _timeLabel(slot?['end_time']),
          partySize: _guests,
          seasonLabel: _seasonLabel(_selectedDate),
          seatingLabel: _seatingLabel(slot?['start_time']),
          tablesLabel: _allocatedTablesLabel(),
        ),
      ),
    );
  }

  int? _intValue(Object? value) {
    return switch (value) {
      int number => number,
      String text => int.tryParse(text),
      _ => null,
    };
  }

  String _timeLabel(Object? value) {
    final text = value?.toString() ?? '';
    return text.length >= 16 ? text.substring(11, 16) : text;
  }

  String _seasonLabel(DateTime date) {
    return switch (date.month) {
      12 || 1 || 2 => 'Winter Peak',
      3 || 4 || 5 => 'Spring Peak',
      6 || 7 || 8 => 'Summer Peak',
      _ => 'Autumn Peak',
    };
  }

  String _seatingLabel(Object? value) {
    final time = _timeLabel(value);
    final hour = int.tryParse(time.split(':').first) ?? 0;
    return hour < 17 ? 'Lunch Seating' : 'Dinner Seating';
  }

  String _allocatedTablesLabel() {
    final allocation = _availability?['allocation'];
    if (allocation is! List) return '';
    final tables =
        allocation
            .whereType<Map>()
            .map((item) => item['table_no'])
            .whereType<num>()
            .map((number) => number.toInt())
            .toSet()
            .toList()
          ..sort();
    if (tables.isEmpty) return '';
    return 'Tables ${tables.join(' & ')}';
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ELEVATION 2,140M', style: TextStyle(fontSize: 10)),
            Text('Search', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppConstants.exploreContentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              children: [
                const Text(
                  'ELEVATION 2,140M',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Check Table Availability',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Material(
                      color: AppColors.tertiary.withValues(alpha: 0.18),
                      child: IconButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                        color: AppColors.tertiary,
                        icon: const Icon(Icons.home_outlined),
                        tooltip: 'Home',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingSm),
                const Text(
                  'Welcome to Mountain Hut. Savor hot meals and panoramic ridge views. Plan your stop below.',
                ),
                const SizedBox(height: AppConstants.spacingMd),
                _AvailabilityCard(
                  guests: _guests,
                  slots: _slots,
                  selectedSlot: _selectedSlot,
                  isLoadingSlots: _isLoadingSlots,
                  slotsErrorMessage: _slotsErrorMessage,
                  isCheckingAvailability: _isCheckingAvailability,
                  dateLabel: _displayDate(_selectedDate),
                  onDateSelected: _selectDate,
                  onGuestsChanged: (value) {
                    setState(() => _guests = value);
                    _invalidateAvailability();
                  },
                  onSlotChanged: (value) {
                    setState(() => _selectedSlot = value);
                    _invalidateAvailability();
                  },
                  onCheckAvailability: _checkAvailability,
                  onRetrySlots: _loadSlots,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppConstants.spacingMd),
                  _ErrorMessage(message: _errorMessage!),
                ],
                if (_hasCheckedAvailability) ...[
                  const SizedBox(height: AppConstants.spacingMd),
                  const _SearchResultsHeader(),
                  _AvailabilityResults(
                    result: _availability!,
                    slotDetails: _selectedSlotDetails,
                  ),
                  if (_availability!['available'] == true) ...[
                    const SizedBox(height: AppConstants.spacingMd),
                    FilledButton(
                      onPressed: () => _openAuth(AuthContext.tableReservation),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Proceed to Reservation'),
                          SizedBox(width: AppConstants.spacingSm),
                          Icon(Icons.arrow_forward),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingSm),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppConstants.spacingXs),
                          Text(
                            'Registered hiker account required to finalize booking',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _ExploreBottomNavigation(
        isSignedIn: _isHikerSignedIn,
        onLogin: () => _openAuth(AuthContext.directAccess),
        onMyBookings: () => Navigator.of(
          context,
        ).push(AppNavigation.myBookings(api: widget.api)),
      ),
    );
  }

  Map<String, dynamic>? get _selectedSlotDetails {
    if (_selectedSlot < 0 || _selectedSlot >= _slots.length) return null;
    return _slots[_selectedSlot];
  }
}

class _ExploreBottomNavigation extends StatelessWidget {
  const _ExploreBottomNavigation({
    required this.isSignedIn,
    required this.onLogin,
    required this.onMyBookings,
  });

  final bool isSignedIn;
  final VoidCallback onLogin;
  final VoidCallback onMyBookings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            children: [
              Expanded(
                child: _BottomNavigationItem(
                  icon: Icons.search,
                  label: 'Explore',
                  selected: true,
                ),
              ),
              Expanded(
                child: isSignedIn
                    ? _BottomNavigationItem(
                        icon: Icons.calendar_month_outlined,
                        label: 'My Bookings',
                        onPressed: onMyBookings,
                      )
                    : _BottomNavigationItem(
                        icon: Icons.login,
                        label: 'Log In',
                        onPressed: onLogin,
                      ),
              ),
              if (isSignedIn)
                const Expanded(
                  child: _BottomNavigationItem(
                    icon: Icons.person_outline,
                    label: 'Account',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavigationItem extends StatelessWidget {
  const _BottomNavigationItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return ClipRect(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.guests,
    required this.slots,
    required this.selectedSlot,
    required this.dateLabel,
    required this.onDateSelected,
    required this.isLoadingSlots,
    required this.slotsErrorMessage,
    required this.isCheckingAvailability,
    required this.onGuestsChanged,
    required this.onSlotChanged,
    required this.onCheckAvailability,
    required this.onRetrySlots,
  });

  final int guests;
  final List<Map<String, dynamic>> slots;
  final int selectedSlot;
  final String dateLabel;
  final VoidCallback onDateSelected;
  final bool isLoadingSlots;
  final String? slotsErrorMessage;
  final bool isCheckingAvailability;
  final ValueChanged<int> onGuestsChanged;
  final ValueChanged<int> onSlotChanged;
  final VoidCallback onCheckAvailability;
  final VoidCallback onRetrySlots;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel(icon: Icons.search, text: 'FIND A TABLE'),
                Text('Public Access', style: TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMd),
            const _SectionLabel(icon: Icons.calendar_today, text: 'Date'),
            const SizedBox(height: AppConstants.spacingSm),
            InkWell(
              onTap: onDateSelected,
              child: InputDecorator(
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  suffixIcon: Icon(Icons.calendar_today),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.lightBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.lightBorder),
                  ),
                ),
                child: Text(dateLabel),
              ),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            const _SectionLabel(
              icon: Icons.restaurant,
              text: 'Meal Service Slot',
            ),
            const SizedBox(height: AppConstants.spacingSm),
            if (isLoadingSlots)
              const Center(child: CircularProgressIndicator())
            else if (slotsErrorMessage != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      slotsErrorMessage!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                  ),
                  TextButton(
                    onPressed: onRetrySlots,
                    child: const Text('Retry'),
                  ),
                ],
              )
            else if (slots.isEmpty)
              const Text('No meal service slots are available for this date.')
            else
              for (var index = 0; index < slots.length; index++)
                _SlotTile(
                  label: _slotLabel(slots[index]),
                  leadingIcon: _slotIcon(slots[index]),
                  selected: selectedSlot == index,
                  onTap: () => onSlotChanged(index),
                ),
            const SizedBox(height: AppConstants.spacingSm),
            const _SectionLabel(icon: Icons.groups, text: 'Party Size'),
            const SizedBox(height: AppConstants.spacingSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(text: '$guests Guests'),
                      TextSpan(
                        text: ' (Hiker Group)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.lightBorder),
                    color: AppColors.lightControl,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: guests > 1
                            ? () => onGuestsChanged(guests - 1)
                            : null,
                        icon: const Icon(Icons.remove),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.lightControl,
                        ),
                      ),
                      IconButton(
                        onPressed: () => onGuestsChanged(guests + 1),
                        icon: const Icon(Icons.add),
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.lightControl,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSm),
            FilledButton.icon(
              onPressed: isCheckingAvailability || slots.isEmpty
                  ? null
                  : onCheckAvailability,
              icon: isCheckingAvailability
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                isCheckingAvailability
                    ? 'Checking Availability...'
                    : 'Check Availability',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _slotLabel(Map<String, dynamic> slot) {
    final start = _displayTime(slot['start_time']);
    final end = _displayTime(slot['end_time']);
    final meal = start.startsWith('12:') || start.startsWith('13:')
        ? 'Lunch'
        : start.startsWith('19:')
        ? 'Dinner'
        : 'Meal';
    return '$meal $start - $end';
  }

  String _displayTime(Object? value) {
    final timestamp = value?.toString() ?? '';
    return timestamp.length >= 16 ? timestamp.substring(11, 16) : timestamp;
  }

  IconData _slotIcon(Map<String, dynamic> slot) {
    final start = _displayTime(slot['start_time']);
    return start.startsWith('12:') || start.startsWith('13:')
        ? Icons.lunch_dining
        : Icons.room_service;
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.label,
    required this.leadingIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData leadingIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected
        ? AppColors.primary
        : AppColors.textSecondary;

    return Column(
      children: [
        Card(
          elevation: selected ? 2 : 0,
          shadowColor: selected
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.transparent,
          margin: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          color: selected ? AppColors.surface : AppColors.lightSlot,
          child: ListTile(
            dense: true,
            onTap: onTap,
            leading: Icon(leadingIcon, size: 18, color: foregroundColor),
            title: Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: foregroundColor,
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
      ],
    );
  }
}

class _AvailabilityResults extends StatelessWidget {
  const _AvailabilityResults({required this.result, required this.slotDetails});

  final Map<String, dynamic> result;
  final Map<String, dynamic>? slotDetails;

  @override
  Widget build(BuildContext context) {
    final available = result['available'] == true;
    final slot = result['slot'] is Map
        ? Map<String, dynamic>.from(result['slot'] as Map)
        : null;
    final allocation = result['allocation'] is List
        ? (result['allocation'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final tables = slotDetails?['tables'] is List
        ? (slotDetails!['tables'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final totalSeats = allocation.fold<int>(
      0,
      (sum, item) => sum + (item['seats'] as int? ?? 0),
    );

    if (!available) {
      return const _NoAvailabilityCard();
    }

    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.successBadge,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingSm,
                      vertical: AppConstants.spacingXs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 14,
                          color: AppColors.success,
                        ),
                        SizedBox(width: AppConstants.spacingXs),
                        Text(
                          'Available (Shared Seating)',
                          style: TextStyle(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.infoBadge,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingSm,
                      vertical: AppConstants.spacingXs,
                    ),
                    child: Text(
                      '$totalSeats Total Seats',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(_formatSlotDate(slot)),
            const Divider(),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.table_restaurant, size: 16),
                      SizedBox(width: AppConstants.spacingXs),
                      Expanded(child: Text('Seat Distribution Breakdown')),
                    ],
                  ),
                ),
                SizedBox(width: AppConstants.spacingSm),
                Flexible(child: Text('Mountain Dining Hall')),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Wrap(
              spacing: AppConstants.spacingSm,
              runSpacing: AppConstants.spacingSm,
              children: [
                for (final item in allocation)
                  _TableAllocationCard(
                    tableNumber: item['table_no'] as int? ?? 0,
                    seats: item['seats'] as int? ?? 0,
                    capacity: _tableCapacity(tables, item['table_no']),
                  ),
              ],
            ),
            const Divider(),
            Container(
              color: AppColors.infoSurface,
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16),
                  SizedBox(width: AppConstants.spacingXs),
                  Expanded(
                    child: Text(
                      'Shared Seating Rule: Tables are shared with fellow hikers; private tables are not available in the hut.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSlotDate(Map<String, dynamic>? slot) {
    final start = slot?['start_time']?.toString() ?? '';
    final end = slot?['end_time']?.toString() ?? '';
    if (start.length < 16 || end.length < 16) return '$start – $end';

    final dateParts = start.substring(0, 10).split('-');
    final month = int.tryParse(dateParts[1]) ?? 0;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final meal = start.substring(11, 13) == '19' ? 'Dinner' : 'Lunch';
    final monthName = month >= 1 && month <= 12 ? months[month - 1] : '';
    return '$monthName ${dateParts[2]}, ${dateParts[0]} • '
        '$meal ${start.substring(11, 16)} - ${end.substring(11, 16)}';
  }

  int _tableCapacity(List<Map<String, dynamic>> tables, Object? tableNumber) {
    for (final table in tables) {
      if (table['table_no'] == tableNumber) {
        return table['seats'] as int? ?? 0;
      }
    }
    return 0;
  }
}

class _SearchResultsHeader extends StatelessWidget {
  const _SearchResultsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'SEARCH RESULTS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.circle, size: 8, color: AppColors.success),
              const SizedBox(width: AppConstants.spacingXs),
              Text(
                'Live Hut Capacity',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableAllocationCard extends StatelessWidget {
  const _TableAllocationCard({
    required this.tableNumber,
    required this.seats,
    required this.capacity,
  });

  final int tableNumber;
  final int seats;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      color: AppColors.infoSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Table $tableNumber'),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingXs,
                    vertical: 2,
                  ),
                  child: Text(
                    '$seats Seats',
                    style: const TextStyle(
                      color: AppColors.surface,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            children: List.generate(
              seats.clamp(1, 6),
              (_) => const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Icon(
                  Icons.event_seat,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            '$seats of $capacity bench spots',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NoAvailabilityCard extends StatelessWidget {
  const _NoAvailabilityCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      color: AppColors.errorSurface,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.event_busy, color: AppColors.danger, size: 24),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No availability found for this slot',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingXs),
                  Text(
                    'Please select a different time slot manually or reduce party size to fit open bench benches.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      color: AppColors.errorSurface,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.softBlue),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
