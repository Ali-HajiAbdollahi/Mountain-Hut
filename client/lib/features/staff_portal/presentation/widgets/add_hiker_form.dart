import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import 'hiker_lookup_field.dart';

enum HikerMode { quickAdd, fullRegistration }

/// The result returned when the employee confirms a hiker choice.
/// Matches the three modes of the backend: existing / temporary / register.
sealed class HikerChoice {
  Map<String, dynamic> toJson();
}

class ExistingHiker extends HikerChoice {
  ExistingHiker(this.hiker);

  final HikerResult hiker;

  @override
  Map<String, dynamic> toJson() => {
        'mode': 'existing',
        'uID': hiker.uId,
      };
}

class TemporaryHiker extends HikerChoice {
  TemporaryHiker({required this.name, this.phone});

  final String name;
  final String? phone;

  @override
  Map<String, dynamic> toJson() => {
        'mode': 'temporary',
        'name': name,
        if (phone != null) 'phone': phone,
      };
}

class RegisterHiker extends HikerChoice {
  RegisterHiker({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  });

  final String name;
  final String email;
  final String phone;
  final String password;

  @override
  Map<String, dynamic> toJson() => {
        'mode': 'register',
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      };
}

/// Hiker lookup + "Add New Hiker" panel (Quick Add / Full Registration).
/// Calls [onConfirmed] with the chosen [HikerChoice] when ready.
class AddHikerForm extends StatefulWidget {
  const AddHikerForm({
    required this.api,
    required this.onConfirmed,
    super.key,
  });

  final dynamic api; // MountainHutApi — kept dynamic to avoid circular imports
  final ValueChanged<HikerChoice> onConfirmed;

  @override
  State<AddHikerForm> createState() => _AddHikerFormState();
}

class _AddHikerFormState extends State<AddHikerForm> {
  HikerResult? _selected;
  bool _showAddPanel = false;
  HikerMode _mode = HikerMode.quickAdd;

  void _onSelected(HikerResult h) {
    setState(() {
      _selected = h;
      _showAddPanel = false;
    });
  }

  void _onNotFound(String _) {
    setState(() {
      _selected = null;
      _showAddPanel = true;
    });
  }

  void _onCleared() {
    setState(() {
      _selected = null;
      _showAddPanel = false;
    });
  }

  void _onConfirmed(HikerChoice choice) {
    widget.onConfirmed(choice);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HikerLookupField(
          api: widget.api,
          onSelected: _onSelected,
          onNotFound: _onNotFound,
          onCleared: _onCleared,
        ),
        if (_selected != null) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _onConfirmed(ExistingHiker(_selected!)),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirm Hiker'),
          ),
        ],
        if (_showAddPanel && _selected == null) ...[
          const SizedBox(height: 16),
          _modeSelector(),
          const SizedBox(height: 12),
          if (_mode == HikerMode.quickAdd)
            _QuickAddForm(onConfirmed: _onConfirmed)
          else
            _FullRegistrationForm(onConfirmed: _onConfirmed),
        ],
      ],
    );
  }

  Widget _modeSelector() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'GUEST PROFILE MODE',
          style: textTheme.labelMedium?.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Temporary Hiker',
                subtitle: 'Fast entry for phone calls & walk-ins.',
                icon: Icons.bolt,
                selected: _mode == HikerMode.quickAdd,
                onTap: () => setState(() => _mode = HikerMode.quickAdd),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModeButton(
                label: 'Regular Profile',
                subtitle: 'Create persistent profile with full details.',
                icon: Icons.badge,
                selected: _mode == HikerMode.fullRegistration,
                onTap: () =>
                    setState(() => _mode = HikerMode.fullRegistration),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Mode selector button ──────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: selected ? AppColors.primary : AppColors.lightControl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.text,
                    ),
                  ),
                ),
                Icon(icon,
                    size: 16,
                    color: selected ? Colors.white : AppColors.secondary),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: selected ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Add form ────────────────────────────────────────────────────────────

class _QuickAddForm extends StatefulWidget {
  const _QuickAddForm({required this.onConfirmed});
  final ValueChanged<HikerChoice> onConfirmed;

  @override
  State<_QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends State<_QuickAddForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onConfirmed(
        TemporaryHiker(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: AppColors.infoBadge,
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Temporary guest: no online profile created. '
                    'Quick check-in only.',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          _field(
            label: 'Hiker / Party Lead Name',
            required: true,
            controller: _nameController,
            hint: 'e.g. Martin S. (Walk-in)',
            validator: (v) => Validators.required(v, fieldName: 'Name'),
            action: TextInputAction.next,
          ),
          _field(
            label: 'Phone Number',
            required: false,
            controller: _phoneController,
            hint: '+41 79 123 4567',
            keyboard: TextInputType.phone,
            action: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.verified, size: 18),
            label: const Text('Confirm Temporary Hiker'),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required bool required,
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(hintText: hint),
            keyboardType: keyboard,
            textInputAction: action,
            onFieldSubmitted: onSubmitted,
            validator: validator,
          ),
        ],
      ),
    );
  }
}

// ── Full Registration form ────────────────────────────────────────────────────

class _FullRegistrationForm extends StatefulWidget {
  const _FullRegistrationForm({required this.onConfirmed});
  final ValueChanged<HikerChoice> onConfirmed;

  @override
  State<_FullRegistrationForm> createState() => _FullRegistrationFormState();
}

class _FullRegistrationFormState extends State<_FullRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onConfirmed(
        RegisterHiker(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PERSISTENT HIKER MEMBERSHIP FILE',
            style: textTheme.labelMedium?.copyWith(color: AppColors.secondary),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          _field(
            label: 'Full Name',
            controller: _nameController,
            hint: 'Elena Rossi',
            icon: Icons.person_outline,
            validator: (v) => Validators.required(v, fieldName: 'Full Name'),
            action: TextInputAction.next,
          ),
          _field(
            label: 'Email Address',
            controller: _emailController,
            hint: 'elena.rossi@alpinists.ch',
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress,
            validator: Validators.email,
            action: TextInputAction.next,
          ),
          _field(
            label: 'Mobile Phone',
            controller: _phoneController,
            hint: '+41 78 890 1234',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone,
            validator: (v) =>
                Validators.required(v, fieldName: 'Mobile Phone'),
            action: TextInputAction.next,
          ),
          _field(
            label: 'Password',
            controller: _passwordController,
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: true,
            validator: Validators.password,
            action: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.verified, size: 18),
            label: const Text('Confirm Registration'),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    bool obscure = false,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: label,
              style: Theme.of(context).textTheme.labelLarge,
              children: const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.danger),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon),
            ),
            keyboardType: keyboard,
            obscureText: obscure,
            textInputAction: action,
            onFieldSubmitted: onSubmitted,
            validator: validator,
          ),
        ],
      ),
    );
  }
}