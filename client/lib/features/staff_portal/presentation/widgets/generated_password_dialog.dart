import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Shows the password generated for a new hiker profile. The server returns it only once,
/// so the dialog cannot be dismissed by tapping outside: the employee must press "Done".
Future<void> showGeneratedPasswordDialog(
  BuildContext context, {
  required String email,
  required String password,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _GeneratedPasswordDialog(email: email, password: password),
  );
}

class _GeneratedPasswordDialog extends StatefulWidget {
  const _GeneratedPasswordDialog({required this.email, required this.password});

  final String email;
  final String password;

  @override
  State<_GeneratedPasswordDialog> createState() =>
      _GeneratedPasswordDialogState();
}

class _GeneratedPasswordDialogState extends State<_GeneratedPasswordDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.password));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      shape: const RoundedRectangleBorder(),
      backgroundColor: AppColors.surface,
      title: Text('HIKER ACCOUNT CREATED', style: textTheme.labelMedium),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Account: ${widget.email}', style: textTheme.bodyMedium),
            const SizedBox(height: AppConstants.spacingMd),
            Text('Generated password', style: textTheme.labelLarge),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.lightControl,
              child: SelectableText(
                widget.password,
                key: const ValueKey('generated-password'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            OutlinedButton.icon(
              onPressed: _copy,
              icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
              label: Text(_copied ? 'Copied' : 'Copy password'),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              'Give this password to the hiker now: it is shown only once and '
              'cannot be read again. The hiker must change it at the first '
              'login, and can recover access by email at any time.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
