import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/auth_context.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/register_form.dart';
import '../widgets/security_card.dart';
import '../widgets/sign_in_form.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.authContext,
    required this.authRepository,
    this.onSignIn,
    this.onRegister,
    this.onForgotPassword,
    super.key,
  });

  final AuthContext authContext;
  final AuthRepository authRepository;
  final VoidCallback? onSignIn;
  final VoidCallback? onRegister;
  final VoidCallback? onForgotPassword;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegistration = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isReservation => widget.authContext == AuthContext.tableReservation;

  Future<void> _signIn(String email, String password) async {
    await _runAuthAction(
      () => widget.authRepository.signIn(email: email, password: password),
      widget.onSignIn,
    );
  }

  Future<void> _register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    await _runAuthAction(
      () => widget.authRepository.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
      ),
      widget.onRegister,
    );
  }

  Future<void> _runAuthAction(
    Future<void> Function() action,
    VoidCallback? onSuccess,
  ) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await action();
      if (mounted) onSuccess?.call();
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
    final title = _isReservation ? 'Table Reservation' : 'Hiker Access';

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        titleSpacing: 0,
        title: Row(
          children: [
            const Icon(
              Icons.landscape_outlined,
              color: AppColors.tertiary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AuthToggle(
                    isRegistration: _isRegistration,
                    onChanged: (value) {
                      setState(() => _isRegistration = value);
                    },
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _isRegistration
                        ? RegisterForm(
                            key: const ValueKey('register'),
                            authContext: widget.authContext,
                            onSubmit: _register,
                            errorMessage: _errorMessage,
                            isSubmitting: _isSubmitting,
                          )
                        : SignInForm(
                            key: const ValueKey('sign-in'),
                            authContext: widget.authContext,
                            onSubmit: _signIn,
                            onForgotPassword: widget.onForgotPassword,
                            errorMessage: _errorMessage,
                            isSubmitting: _isSubmitting,
                          ),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                  const SecurityCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthToggle extends StatelessWidget {
  const _AuthToggle({
    required this.isRegistration,
    required this.onChanged,
  });

  final bool isRegistration;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.outlined.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: 'Register as New Hiker',
              selected: isRegistration,
              onPressed: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              label: 'Sign In',
              selected: !isRegistration,
              onPressed: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected ? Colors.white : Colors.transparent,
        foregroundColor: selected ? AppColors.primary : AppColors.text,
        shape: const RoundedRectangleBorder(),
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
