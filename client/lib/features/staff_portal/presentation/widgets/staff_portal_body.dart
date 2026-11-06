import 'package:flutter/material.dart';

import '../../../../core/network/mountain_hut_api.dart';
import '../../../../core/theme/app_colors.dart';
import 'slot_capacity_section.dart';
import 'walk_in_booking_section.dart';

enum _StaffTab { capacity, booking }

class StaffPortalBody extends StatefulWidget {
  const StaffPortalBody({required this.api, super.key});

  final MountainHutApi api;

  @override
  State<StaffPortalBody> createState() => _StaffPortalBodyState();
}

class _StaffPortalBodyState extends State<StaffPortalBody> {
  _StaffTab _tab = _StaffTab.capacity;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.all(4),
            color: AppColors.background,
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    icon: Icons.grid_view,
                    label: 'Define Slot Capacity',
                    selected: _tab == _StaffTab.capacity,
                    onTap: () => setState(() => _tab = _StaffTab.capacity),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _TabButton(
                    icon: Icons.phone_in_talk,
                    label: 'Phone / Walk-in Booking',
                    selected: _tab == _StaffTab.booking,
                    onTap: () => setState(() => _tab = _StaffTab.booking),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab.index,
            children: [
              SlotCapacitySection(api: widget.api),
              WalkInBookingSection(api: widget.api),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        color: selected ? AppColors.primary : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}