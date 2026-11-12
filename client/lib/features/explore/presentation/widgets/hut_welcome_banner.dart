import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/hut_information.dart';
import '../../../../core/theme/app_colors.dart';

class HutHomeHeader extends StatelessWidget {
  const HutHomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HutInformation>(
      future: HutInformation.asset,
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Row(
          children: [
            if (info == null)
              const Icon(Icons.landscape_outlined, color: AppColors.tertiary)
            else
              Image.network(
                info.logoUrl,
                height: AppConstants.spacingXl,
                width: AppConstants.spacingXl,
                fit: BoxFit.contain,
                semanticLabel: AppConstants.appName,
                errorBuilder: (context, error, stackTrace) => const Tooltip(
                  message: 'Mountain Hut logo unavailable',
                  child: Icon(
                    Icons.landscape_outlined,
                    color: AppColors.tertiary,
                  ),
                ),
              ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (info != null)
                    Text(
                      info.homeSubtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _HutTab { location, directions, nearby }

class HutWelcomeBanner extends StatefulWidget {
  const HutWelcomeBanner({super.key});

  @override
  State<HutWelcomeBanner> createState() => _HutWelcomeBannerState();
}

class _HutWelcomeBannerState extends State<HutWelcomeBanner> {
  _HutTab _selectedTab = _HutTab.location;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HutInformation>(
      future: HutInformation.asset,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Unable to load hut information: ${snapshot.error}',
            style: const TextStyle(color: AppColors.danger),
          );
        }
        final info = snapshot.data;
        if (info == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final theme = Theme.of(context).textTheme;
        return Container(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          decoration: BoxDecoration(
            color: AppColors.infoSurface,
            border: Border.all(color: AppColors.lightBorder),
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm,
                  vertical: AppConstants.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successBadge,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.terrain,
                      size: AppConstants.spacingMd,
                      color: AppColors.tertiary,
                    ),
                    const SizedBox(width: AppConstants.spacingXs),
                    Text(
                      info.elevation.toUpperCase(),
                      style: theme.labelSmall?.copyWith(
                        color: AppColors.tertiary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Text(info.name, style: theme.titleMedium),
              const SizedBox(height: AppConstants.spacingSm),
              Text(
                info.description,
                style: theme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Wrap(
                spacing: AppConstants.spacingSm,
                runSpacing: AppConstants.spacingSm,
                children: [
                  for (final amenity in info.amenities)
                    _AmenityBadge(amenity: amenity),
                ],
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingXs),
                decoration: BoxDecoration(
                  color: AppColors.lightControl,
                  border: Border.all(color: AppColors.lightBorder),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Row(
                  children: [
                    _tab(
                      _HutTab.location,
                      Icons.location_on_outlined,
                      info.locationLabel,
                    ),
                    const SizedBox(width: AppConstants.spacingXs),
                    _tab(
                      _HutTab.directions,
                      Icons.hiking,
                      info.directionsLabel,
                    ),
                    const SizedBox(width: AppConstants.spacingXs),
                    _tab(
                      _HutTab.nearby,
                      Icons.landscape_outlined,
                      info.nearbyLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.lightBorder),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: switch (_selectedTab) {
                  _HutTab.location => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.navigation_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(info.locationName, style: theme.labelLarge),
                            const SizedBox(height: AppConstants.spacingXs),
                            Text(
                              info.locationDescription,
                              style: theme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingSm),
                            Row(
                              children: [
                                const Icon(
                                  Icons.pin_drop_outlined,
                                  size: AppConstants.spacingMd,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: AppConstants.spacingXs),
                                Expanded(
                                  child: Text(
                                    info.coordinates,
                                    style: theme.labelSmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _HutTab.directions => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final trail in info.trails) ...[
                        _PlaceTile(place: trail),
                        if (trail != info.trails.last)
                          const SizedBox(height: AppConstants.spacingSm),
                      ],
                    ],
                  ),
                  _HutTab.nearby => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var index = 0;
                        index < info.nearby.length;
                        index++
                      ) ...[
                        _PlaceTile(
                          place: info.nearby[index],
                          markerColor: index.isOdd
                              ? AppColors.tertiary
                              : AppColors.primary,
                        ),
                        if (index < info.nearby.length - 1)
                          const SizedBox(height: AppConstants.spacingSm),
                      ],
                    ],
                  ),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tab(_HutTab tab, IconData icon, String label) {
    final selected = _selectedTab == tab;
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: Material(
          color: selected ? AppColors.surface : Colors.transparent,
          elevation: selected ? 1 : 0,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            onTap: () => setState(() => _selectedTab = tab),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingXs,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: AppConstants.spacingMd, color: color),
                    const SizedBox(width: AppConstants.spacingXs),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
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

class _AmenityBadge extends StatelessWidget {
  const _AmenityBadge({required this.amenity});

  final HutAmenity amenity;

  @override
  Widget build(BuildContext context) {
    final icon = switch (amenity.type) {
      HutAmenityType.dining => Icons.soup_kitchen_outlined,
      HutAmenityType.shelter => Icons.bed_outlined,
      HutAmenityType.charging => Icons.bolt,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.lightBorder),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppConstants.spacingMd,
            color: amenity.type == HutAmenityType.charging
                ? AppColors.tertiary
                : AppColors.primary,
          ),
          const SizedBox(width: AppConstants.spacingXs),
          Flexible(
            child: Text(
              amenity.label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, this.markerColor});

  final HutPlace place;
  final Color? markerColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (markerColor != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppConstants.spacingXs),
              child: Icon(
                Icons.circle,
                size: AppConstants.spacingSm,
                color: markerColor,
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(place.name, style: theme.labelLarge)),
                    if (place.duration != null) ...[
                      const SizedBox(width: AppConstants.spacingSm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingSm,
                          vertical: AppConstants.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSm,
                          ),
                        ),
                        child: Text(
                          place.duration!,
                          style: theme.labelSmall?.copyWith(
                            color: AppColors.surface,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  place.description,
                  style: theme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
