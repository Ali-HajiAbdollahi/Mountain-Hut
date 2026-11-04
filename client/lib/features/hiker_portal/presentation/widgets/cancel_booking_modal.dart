import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';

Future<bool> showCancelBookingModal(
  BuildContext context, {
  required Map<String, dynamic> booking,
  required MountainHutApi api,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => _CancelBookingDialog(booking: booking, api: api),
  );
  return confirmed == true;
}

class _CancelBookingDialog extends StatefulWidget {
  const _CancelBookingDialog({required this.booking, required this.api});

  final Map<String, dynamic> booking;
  final MountainHutApi api;

  @override
  State<_CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends State<_CancelBookingDialog> {
  bool _isSubmitting = false;
  String? _error;

  Future<void> _cancel() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.api.cancelBooking(_id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  int get _id => int.tryParse('${widget.booking['bID']}') ?? 0;

  @override
  Widget build(BuildContext context) {
    final reference =
        widget.booking['reference'] ?? 'MH-${widget.booking['bID']}';
    final date = widget.booking['start_time']?.toString() ?? '';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACTION REQUIRED • REF $reference',
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingXs),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                ),
                const SizedBox(width: AppConstants.spacingSm),
                const Expanded(
                  child: Text(
                    'Cancel Reservation?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              'Are you sure you want to cancel your booking for $date?',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            const Text(
              'This action cannot be undone and the assigned tables will be released.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Container(
              color: const Color(0xFFE0F7E7),
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: AppColors.tertiary,
                    size: 17,
                  ),
                  SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: Text(
                      'Policy Verified: Cancellation is permitted (>48 hours prior to service).',
                      style: TextStyle(fontSize: 11, color: AppColors.tertiary),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppConstants.spacingSm),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: AppConstants.spacingMd),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _cancel,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: Text(
                  _isSubmitting ? 'CANCELLING...' : 'YES, CANCEL BOOKING',
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lightControl,
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('KEEP RESERVATION'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
