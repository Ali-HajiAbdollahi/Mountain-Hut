import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/booking_allocation.dart';
import '../../domain/repositories/booking_repository.dart';
import '../widgets/dietary_requirements_section.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({
    required this.allocation,
    required this.repository,
    required this.api,
    super.key,
  });

  final BookingAllocation allocation;
  final BookingRepository repository;
  final MountainHutApi api;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _requirements = <DietaryRequirementDraft>[];
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final requirement in _requirements) {
      requirement.dispose();
    }
    super.dispose();
  }

  void _removeRequirement(int index) {
    final requirement = _requirements.removeAt(index);
    requirement.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    final requirements = <Map<String, dynamic>>[];
    for (final requirement in _requirements) {
      final description = requirement.controller.text.trim();
      if (description.isEmpty) {
        setState(
          () => _errorMessage = 'Complete or remove empty requirements.',
        );
        return;
      }
      requirements.add({
        'description': description,
        'allergy': requirement.isAllergy,
      });
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final response = await widget.repository.createBooking(
        slotId: widget.allocation.slotId,
        partySize: widget.allocation.partySize,
        requirements: requirements,
      );
      if (!mounted) return;
      final booking = response['booking'];
      if (booking is! Map<String, dynamic>) {
        setState(() => _errorMessage = 'The reservation response was invalid.');
        return;
      }
      Navigator.of(context).pushReplacement(
        AppNavigation.bookingSuccess(
          api: widget.api,
          booking: booking,
          allocation: widget.allocation,
          notificationSent:
              (response['notification'] as Map?)?['status'] == 'accepted',
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on AppException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        leading: const BackButton(),
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
                _SectionHeader(
                  title: 'CONFIRMED ALLOCATION',
                  trailing: const _LockedLabel(),
                ),
                const SizedBox(height: AppConstants.spacingSm),
                _AllocationCard(allocation: widget.allocation),
                const SizedBox(height: AppConstants.spacingMd),
                const _InfoCard(
                  text:
                      'Date, time, and party size are locked from your availability check. Mountain Hut operations close alterations 2 hours prior to seating.',
                ),
                const SizedBox(height: AppConstants.spacingXl),
                DietaryRequirementsSection(
                  requirements: _requirements,
                  onDelete: _removeRequirement,
                  onAdd: () {
                    if (!_isSubmitting) {
                      setState(
                        () => _requirements.add(DietaryRequirementDraft()),
                      );
                    }
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppConstants.spacingSm),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppConstants.spacingMd),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('CONFIRM RESERVATION'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        trailing,
      ],
    );
  }
}

class _LockedLabel extends StatelessWidget {
  const _LockedLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.lock_outline,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppConstants.spacingXs),
        Text(
          'Parameters Locked',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({required this.allocation});

  final BookingAllocation allocation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AllocationContainer(
            child: _AllocationValue(
              label: 'DATE',
              value: allocation.date,
              subtitle: allocation.seasonLabel,
              icon: Icons.calendar_today_outlined,
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: _AllocationContainer(
            child: _AllocationValue(
              label: 'TIME SLOT',
              value: '${allocation.startTime}–${allocation.endTime}',
              subtitle: allocation.seatingLabel,
              icon: Icons.schedule_outlined,
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: _AllocationContainer(
            child: _AllocationValue(
              label: 'PARTY SIZE',
              value: '${allocation.partySize} Guests',
              subtitle: allocation.tablesLabel,
              icon: Icons.groups_outlined,
            ),
          ),
        ),
      ],
    );
  }
}

class _AllocationContainer extends StatelessWidget {
  const _AllocationContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: const BoxDecoration(
        color: AppColors.lightControl,
        borderRadius: BorderRadius.zero,
      ),
      child: child,
    );
  }
}

class _AllocationValue extends StatelessWidget {
  const _AllocationValue({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Icon(icon, size: 14, color: AppColors.textSecondary),
          ],
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(value, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      color: AppColors.infoSurface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
