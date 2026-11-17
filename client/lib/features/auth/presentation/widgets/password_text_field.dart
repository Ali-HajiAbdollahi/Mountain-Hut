import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class PasswordTextField extends StatefulWidget {
  const PasswordTextField({
    required this.controller,
    required this.label,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: widget.label,
            style: Theme.of(context).textTheme.labelLarge,
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
          controller: widget.controller,
          obscureText: _obscured,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: (_) => widget.onSubmitted?.call(),
          validator: widget.validator,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _obscured ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscured ? Icons.visibility_outlined : Icons.visibility_off,
              ),
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
          ),
        ),
      ],
    );
  }
}
