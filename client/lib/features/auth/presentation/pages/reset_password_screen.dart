import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/password_text_field.dart';

/// Sets a new password with the code received by email. Pops with `true` on success.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tokenController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.authRepository.confirmPasswordReset(
        token: _tokenController.text.trim(),
        newPassword: _newController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Set new password')),
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
                    Text('Set a new password', style: textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Paste the reset code from the email and choose a new password. '
                      'The code is valid for 24 hours and works only once.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingLg),
                    Text.rich(
                      TextSpan(
                        text: 'Reset code',
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
                      controller: _tokenController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                      validator: (v) =>
                          Validators.required(v, fieldName: 'Reset code'),
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                    PasswordTextField(
                      controller: _newController,
                      label: 'New password',
                      validator: Validators.password,
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                    PasswordTextField(
                      controller: _confirmController,
                      label: 'Confirm new password',
                      textInputAction: TextInputAction.done,
                      onSubmitted: _submit,
                      validator: (v) => v == _newController.text
                          ? null
                          : 'Passwords do not match',
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppConstants.spacingMd),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: AppConstants.spacingLg),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Set new password'),
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
