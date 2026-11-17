import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/password_text_field.dart';

/// Pops with the updated user once the password has been changed.
///
/// When [forced] is true (the account has a temporary password) the screen cannot be left
/// without changing the password.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    required this.authRepository,
    this.forced = true,
    super.key,
  });

  final AuthRepository authRepository;
  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentController.dispose();
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
      final user = await widget.authRepository.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (mounted) Navigator.of(context).pop(user);
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
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.forced,
          title: const Text('Change password'),
        ),
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
                      Text('Choose a new password', style: textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        widget.forced
                            ? 'Your account was created by the hut staff with a '
                                'temporary password. Choose your own password to continue.'
                            : 'Enter your current password and choose a new one.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingLg),
                      PasswordTextField(
                        controller: _currentController,
                        label: widget.forced
                            ? 'Temporary password'
                            : 'Current password',
                        validator: (v) =>
                            Validators.required(v, fieldName: 'Current password'),
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      PasswordTextField(
                        controller: _newController,
                        label: 'New password',
                        validator: (v) {
                          final error = Validators.password(v);
                          if (error != null) return error;
                          if (v == _currentController.text) {
                            return 'The new password must be different';
                          }
                          return null;
                        },
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
                        label: const Text('Change password'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
