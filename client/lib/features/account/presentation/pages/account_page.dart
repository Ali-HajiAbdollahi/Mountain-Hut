import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';
import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    required this.api,
    this.authRepository,
    this.onExplore,
    this.onBookings,
    this.onStaffPortal,
    this.onLogout,
    super.key,
  });

  final MountainHutApi api;
  final AuthRepository? authRepository;
  final VoidCallback? onExplore;
  final VoidCallback? onBookings;
  final VoidCallback? onStaffPortal;
  final VoidCallback? onLogout;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  bool get _isStaff => _user?['role'] == 'employee';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await widget.api.currentUser();
      if (mounted) {
        setState(() {
          _user = user;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      await widget.api.logout();
      if (mounted) {
        if (widget.onLogout != null) {
          widget.onLogout!();
        } else {
          AppNavigation.navigatorKey.currentState?.popUntil(
            (route) => route.isFirst,
          );
        }
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        leading: const Icon(Icons.cabin_outlined, color: AppColors.primary),
        title: Text(_isStaff ? 'STAFF ACCOUNT' : 'HIKER ACCOUNT'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppConstants.myBookingsContentMaxWidth,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(AppConstants.spacingMd),
                    children: [
                      _ProfileHeader(user: _user!, isStaff: _isStaff),
                      const SizedBox(height: AppConstants.spacingLg),
                      _RegistryInfo(user: _user!, isStaff: _isStaff),
                      const SizedBox(height: AppConstants.spacingLg),
                      _VerifiedCard(isStaff: _isStaff),
                      const SizedBox(height: AppConstants.spacingLg),
                      FilledButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('LOG OUT'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.errorSurface,
                          foregroundColor: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingMd),
                      Text(
                        _isStaff
                            ? 'MOUNTAIN HUT STAFF PORTAL • V1.0'
                            : 'MOUNTAIN HUT RESERVATION SYSTEM • V1.0',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Session encrypted',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.disabled,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: AppBottomNavigation(
        role: _isStaff ? AppNavigationRole.employee : AppNavigationRole.hiker,
        selectedTab: AppNavigationTab.account,
        onExplore: widget.onExplore,
        onBookings: widget.onBookings,
        onStaffPortal: widget.onStaffPortal,
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.isStaff});

  final Map<String, dynamic> user;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? '';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
    return Container(
      color: AppColors.infoSurface,
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            color: AppColors.primary,
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  color: AppColors.lightSlot,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isStaff
                            ? Icons.location_on_outlined
                            : Icons.verified_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isStaff ? 'HUT STAFF' : 'REGISTERED HIKER',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  isStaff ? 'Mountain Staff Profile' : 'Hiker Profile',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistryInfo extends StatelessWidget {
  const _RegistryInfo({required this.user, required this.isStaff});

  final Map<String, dynamic> user;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (Icons.person_outline, 'Full Name', user['name']?.toString() ?? ''),
      (
        Icons.mail_outline,
        isStaff ? 'Staff Email' : 'Registered Email',
        user['email']?.toString() ?? '',
      ),
      if (!isStaff)
        (
          Icons.phone_outlined,
          'Primary Mobile Number',
          user['phone']?.toString() ?? '',
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'REGISTRY INFORMATION',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              'Read-only',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Container(
          color: AppColors.infoSurface,
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                _InfoRow(
                  icon: rows[index].$1,
                  label: rows[index].$2,
                  value: rows[index].$3,
                ),
                if (index < rows.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppConstants.spacingMd),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: AppConstants.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VerifiedCard extends StatelessWidget {
  const _VerifiedCard({required this.isStaff});

  final bool isStaff;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.infoSurface,
    padding: const EdgeInsets.all(AppConstants.spacingMd),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.verified_user_outlined, color: AppColors.primary),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.text, fontSize: 12),
              children: [
                TextSpan(
                  text: isStaff
                      ? 'Verified Mountain Personnel\n'
                      : 'Verified Mountain Hiker\n',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: isStaff
                      ? 'Credentials authenticated via Swiss Mountain Club Staff Directory. Registry modifications require hut warden clearance.'
                      : 'Profile authenticated for mountain reservations and hut safety registry.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
