import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/auth_context.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({
    required this.authContext,
    required this.onSubmit,
    this.errorMessage,
    this.isSubmitting = false,
    super.key,
  });

  final AuthContext authContext;
  final Future<void> Function(
    String name,
    String email,
    String phone,
    String password,
  ) onSubmit;
  final String? errorMessage;
  final bool isSubmitting;

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  bool get _isReservation => widget.authContext == AuthContext.tableReservation;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      await widget.onSubmit(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _mobileController.text.trim(),
        _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hiker Registration',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            _isReservation
                ? 'Complete your hiker profile to continue your reservation.'
                : 'Create your hiker profile to get started.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          _RegisterField(
            label: 'Full Name',
            required: true,
            controller: _nameController,
            hintText: 'Elena Rostova',
            icon: Icons.person_outline,
            validator: (value) =>
                Validators.required(value, fieldName: 'Full Name'),
            textInputAction: TextInputAction.next,
          ),
          _RegisterField(
            label: 'Email Address',
            required: true,
            controller: _emailController,
            hintText: 'elena.rostova@alps.org',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            textInputAction: TextInputAction.next,
          ),
          _RegisterField(
            label: 'Mobile Number',
            required: true,
            controller: _mobileController,
            hintText: '+43 664 1234567',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) =>
                Validators.required(value, fieldName: 'Mobile Number'),
            textInputAction: TextInputAction.next,
          ),
          _RegisterField(
            label: 'Password',
            required: true,
            controller: _passwordController,
            hintText: '••••••••••••',
            icon: Icons.lock_outline,
            obscureText: true,
            validator: Validators.password,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          if (widget.errorMessage != null) ...[
            Text(
              widget.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: AppConstants.spacingMd),
          ],
          const SizedBox(height: AppConstants.spacingSm),
          ElevatedButton.icon(
            onPressed: widget.isSubmitting ? null : _submit,
            icon: const Icon(Icons.arrow_forward),
            iconAlignment: IconAlignment.end,
            label: widget.isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isReservation
                        ? 'Create Account & Continue Booking'
                        : 'Create Account',
                  ),
          ),
        ],
      ),
    );
  }
}

class _RegisterField extends StatelessWidget {
  const _RegisterField({
    required this.label,
    required this.required,
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.validator,
    required this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.onSubmitted,
  });

  final String label;
  final bool required;
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style: Theme.of(context).textTheme.labelLarge,
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.danger),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(icon),
            ),
            keyboardType: keyboardType,
            obscureText: obscureText,
            textInputAction: textInputAction,
            onFieldSubmitted: onSubmitted,
            validator: validator,
          ),
        ],
      ),
    );
  }
}
