import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/hike_draft.dart';
import '../widgets/passage_points_field.dart';

class HikeRegistrationPage extends StatefulWidget {
  const HikeRegistrationPage({required this.api, super.key});

  final MountainHutApi api;

  @override
  State<HikeRegistrationPage> createState() => _HikeRegistrationPageState();
}

class _HikeRegistrationPageState extends State<HikeRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final _destinationCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  final _hikerPhoneCtrl = TextEditingController();
  final _iceCtrl = TextEditingController();

  List<String> _passagePoints = const [];
  DateTime _departureTime = DateTime.now().add(const Duration(hours: 1));
  DateTime _expectedReturn = DateTime.now().add(const Duration(hours: 5));
  int _partySize = 1;

  bool _submitting = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _routeCtrl.dispose();
    _hikerPhoneCtrl.dispose();
    _iceCtrl.dispose();
    super.dispose();
  }

  String _fmtDt(DateTime dt) {
    final date =
        '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  Future<void> _pickDateTime({required bool isDeparture}) async {
    final initial = isDeparture ? _departureTime : _expectedReturn;
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (time == null || !mounted) return;

    final picked = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);

    setState(() {
      if (isDeparture) {
        _departureTime = picked;
        if (!_expectedReturn.isAfter(_departureTime)) {
          _expectedReturn =
              _departureTime.add(const Duration(hours: 4));
        }
      } else {
        _expectedReturn = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_expectedReturn.isAfter(_departureTime)) {
      setState(() =>
          _errorMessage = 'Expected return must be after departure time.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final draft = HikeDraft(
      destination: _destinationCtrl.text.trim(),
      routeDescription: _routeCtrl.text.trim(),
      passagePoints: _passagePoints,
      departureTime: _departureTime,
      expectedReturnTime: _expectedReturn,
      partySize: _partySize,
      hikerPhone: _hikerPhoneCtrl.text.trim(),
      emergencyContact: _iceCtrl.text.trim(),
    );

    try {
      // TODO: replace with api.registerHike(draft) when backend is ready.
      // For now, simulate a successful submission.
      await Future.delayed(const Duration(milliseconds: 600));
      debugPrint('Hike draft submitted: ${draft.toJson()}');
      if (!mounted) return;
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _errorMessage = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register a Hike'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: _submitted ? _successView() : _formView(),
    );
  }

  Widget _successView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                color: AppColors.success, size: 64),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              'Hike Registered',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Your planned hike to ${_destinationCtrl.text} has been '
              'recorded. Stay safe on the trail!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to Explore'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formView() {
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.infoBadge,
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Register your planned hike so the hut warden '
                    'can monitor your safety on the trail.',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Destination
          _sectionLabel('DESTINATION', Icons.place),
          const SizedBox(height: 6),
          TextFormField(
            controller: _destinationCtrl,
            decoration: const InputDecoration(
                hintText: 'e.g. Monte Viso Base'),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                Validators.required(v, fieldName: 'Destination'),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Route Description
          _sectionLabel('ROUTE DESCRIPTION', Icons.route),
          const SizedBox(height: 6),
          TextFormField(
            controller: _routeCtrl,
            decoration: const InputDecoration(
                hintText: 'e.g. via the Chiaretto lake'),
            textInputAction: TextInputAction.next,
            maxLines: 2,
            validator: (v) =>
                Validators.required(v, fieldName: 'Route description'),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Passage Points
          _sectionLabel(
              'INTERMEDIATE PASSAGE POINTS', Icons.location_on_outlined),
          const SizedBox(height: 6),
          PassagePointsField(
            points: _passagePoints,
            onChanged: (pts) => setState(() => _passagePoints = pts),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Departure Time
          _sectionLabel('DEPARTURE TIME', Icons.login),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _pickDateTime(isDeparture: true),
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.schedule),
              ),
              child: Text(_fmtDt(_departureTime)),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Expected Return
          _sectionLabel('EXPECTED RETURN TIME', Icons.logout),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _pickDateTime(isDeparture: false),
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.schedule),
              ),
              child: Text(_fmtDt(_expectedReturn)),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Party Size
          _sectionLabel('PARTY SIZE', Icons.group),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _partySize.toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  decoration:
                      const InputDecoration(hintText: '1'),
                  onChanged: (v) =>
                      setState(() => _partySize = int.tryParse(v) ?? 1),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) {
                      return 'Enter a valid party size (≥ 1)';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Hiker Phone
          _sectionLabel('HIKER PHONE', Icons.phone_outlined),
          const SizedBox(height: 6),
          TextFormField(
            controller: _hikerPhoneCtrl,
            decoration: const InputDecoration(
                hintText: '+39 333 4455667'),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                Validators.required(v, fieldName: 'Hiker phone'),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Emergency Contact (ICE)
          _sectionLabel('EMERGENCY CONTACT (ICE)', Icons.emergency),
          const SizedBox(height: 6),
          TextFormField(
            controller: _iceCtrl,
            decoration: const InputDecoration(
                hintText: '+39 340 1122334'),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (v) =>
                Validators.required(v, fieldName: 'Emergency contact'),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Error
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.errorSurface,
              child: Text(
                _errorMessage!,
                style:
                    const TextStyle(color: AppColors.danger),
              ),
            ),
            const SizedBox(height: AppConstants.spacingMd),
          ],

          // Submit
          ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.hiking, size: 18),
            label: Text(
                _submitting ? 'Registering…' : 'Register Hike'),
          ),
          const SizedBox(height: AppConstants.spacingLg),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.secondary,
              ),
        ),
      ],
    );
  }
}