import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/booking_allocation.dart';
import '../widgets/email_notification_card.dart';

class BookingSuccessPage extends StatelessWidget {
  const BookingSuccessPage({
    required this.api,
    required this.booking,
    required this.allocation,
    required this.notificationSent,
    super.key,
  });

  final Map<String, dynamic> booking;
  final MountainHutApi api;
  final BookingAllocation allocation;
  final bool notificationSent;

  List<Map<String, dynamic>> get _requirements {
    final values = booking['requirements'];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  List<Map<String, dynamic>> get _tables {
    final values = booking['tables'];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  String get _tablesLabel {
    final numbers =
        _tables
            .map((table) => table['table_no'])
            .whereType<num>()
            .map((number) => number.toInt())
            .toList()
          ..sort();
    if (numbers.isNotEmpty) {
      final label = numbers.length == 1 ? 'Table' : 'Tables';
      return '$label ${numbers.join(' & ')}';
    }
    return allocation.tablesLabel;
  }

  String get _dietaryNotes {
    if (_requirements.isEmpty) return 'No dietary requirements specified.';
    return _requirements
        .map((requirement) {
          final description = requirement['description']?.toString() ?? '';
          return requirement['allergy'] == true
              ? '$description (Kitchen Alert)'
              : description;
        })
        .join(', ');
  }

  bool get _hasKitchenAlert =>
      _requirements.any((requirement) => requirement['allergy'] == true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.landscape_outlined, color: AppColors.tertiary),
            SizedBox(width: AppConstants.spacingSm),
            Text('Table Reservation'),
          ],
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppConstants.bookingContentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              children: [
                _ConfirmationCard(notificationSent: notificationSent),
                const SizedBox(height: AppConstants.spacingMd),
                _SummaryCard(
                  booking: booking,
                  allocation: allocation,
                  tablesLabel: _tablesLabel,
                  dietaryNotes: _dietaryNotes,
                  hasKitchenAlert: _hasKitchenAlert,
                ),
                const SizedBox(height: AppConstants.spacingMd),
                const _InfoCard(),
                const SizedBox(height: AppConstants.spacingMd),
                FilledButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(AppNavigation.myBookings(api: api)),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View in My Bookings'),
                  iconAlignment: IconAlignment.end,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  icon: const Icon(Icons.search),
                  label: const Text('Back to Home / Explore'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.infoSurface,
                    side: BorderSide.none,
                    foregroundColor: AppColors.text,
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

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({required this.notificationSent});

  final bool notificationSent;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              color: AppColors.success,
              child: const Icon(Icons.check, color: Colors.white, size: 34),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              'Your table is reserved!',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingXs),
            Text(
              'We look forward to welcoming you at the mountain hut.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (notificationSent) ...[
              const SizedBox(height: AppConstants.spacingMd),
              const EmailNotificationCard(),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.booking,
    required this.allocation,
    required this.tablesLabel,
    required this.dietaryNotes,
    required this.hasKitchenAlert,
  });

  final Map<String, dynamic> booking;
  final BookingAllocation allocation;
  final String tablesLabel;
  final String dietaryNotes;
  final bool hasKitchenAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.infoSurface,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RESERVATION SUMMARY',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                '#${booking['reference'] ?? booking['bID'] ?? ''}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          _SummaryRow(
            icon: Icons.person_outline,
            label: 'Reserved by',
            value: booking['contact_name']?.toString() ?? '',
          ),
          _SummaryRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: allocation.date,
          ),
          _SummaryRow(
            icon: Icons.schedule_outlined,
            label: 'Meal Service Slot',
            value:
                '${allocation.seatingLabel.replaceAll(' Seating', '')} ${allocation.startTime} – ${allocation.endTime}',
          ),
          _SummaryRow(
            icon: Icons.groups_outlined,
            label: 'Party Size',
            value: '${allocation.partySize} Guests',
            subtitle: tablesLabel,
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingSm),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.restaurant_outlined,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: AppConstants.spacingXs),
                    const Expanded(
                      child: Text(
                        'Dietary Notes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (hasKitchenAlert)
                      Text(
                        'KITCHEN ALERT',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Text(dietaryNotes),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXs),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      color: AppColors.surface,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.textSecondary),
          SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Text(
              '48-Hour Modification Rule: Changes or cancellations can be managed up to 48 hours prior to your seating via My Bookings.',
            ),
          ),
        ],
      ),
    );
  }
}
