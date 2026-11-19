import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/repositories/auth_repository.dart';
import 'reset_password_screen.dart';

/// Asks for the email of the account and requests a reset link. Pops with `true` once the
/// password has been reset (here or on the "set new password" screen it opens).
class RequestPasswordResetScreen extends StatefulWidget {
  const RequestPasswordResetScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<RequestPasswordResetScreen> createState() =>
      _RequestPasswordResetScreenState();
}

class _RequestPasswordResetScreenState
    extends State<RequestPasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _requested = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.authRepository.requestPasswordReset(
        _emailController.text.trim(),
      );
      if (mounted) setState(() => _requested = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on AppException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openSetNewPassword() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ResetPasswordScreen(authRepository: widget.authRepository),
      ),
    );
    if (done == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Forgot your password?', style: textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Enter the email of your account and we will send you a link '
                      'to choose a new password.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingLg),
                    Text.rich(
                      TextSpan(
                        text: 'Email Address',
                        style: textTheme.labelLarge,
                        children: const [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        hintText: 'hiker@domain.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: Validators.email,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppConstants.spacingMd),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: AppConstants.spacingMd),
                    if (_requested) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: AppColors.infoBadge,
                        child: Text(
                          'If an account exists for this email, a reset link has been '
                          'sent. It is valid for 24 hours.',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                    ],
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.mail_outline),
                      label: Text(_requested ? 'Send again' : 'Send reset link'),
                    ),
                    const SizedBox(height: AppConstants.spacingSm),
                    TextButton(
                      onPressed: _openSetNewPassword,
                      child: const Text('I already have a reset code'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
