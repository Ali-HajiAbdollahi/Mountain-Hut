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

/// Descriptive presentation of the hut on the home page: name, key facts,
/// description and amenities, with location, routes and nearby spots
/// available as collapsible details.
class HutWelcomeBanner extends StatelessWidget {
  const HutWelcomeBanner({super.key});

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
        final secondary = theme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        );
        return Card(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: theme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Wrap(
                  spacing: AppConstants.spacingMd,
                  runSpacing: AppConstants.spacingXs,
                  children: [
                    _HutFact(icon: Icons.terrain, text: info.elevation),
                    _HutFact(
                      icon: Icons.location_on_outlined,
                      text: info.locationName,
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingMd),
                Text(
                  info.description,
                  style: theme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                Wrap(
                  spacing: AppConstants.spacingMd,
                  runSpacing: AppConstants.spacingXs,
                  children: [
                    for (final amenity in info.amenities)
                      _HutFact(
                        icon: _amenityIcon(amenity.type),
                        text: amenity.label,
                        iconColor: AppColors.primary,
                        textColor: AppColors.text,
                      ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingSm),
                const Divider(),
                _HutDetails(
                  icon: Icons.map_outlined,
                  title: info.locationLabel,
                  children: [
                    Text(info.locationDescription, style: secondary),
                    const SizedBox(height: AppConstants.spacingXs),
                    Text(info.coordinates, style: secondary),
                  ],
                ),
                _HutDetails(
                  icon: Icons.hiking,
                  title: info.directionsLabel,
                  children: [
                    for (final trail in info.trails) _PlaceRow(place: trail),
                  ],
                ),
                _HutDetails(
                  icon: Icons.landscape_outlined,
                  title: info.nearbyLabel,
                  children: [
                    for (final place in info.nearby) _PlaceRow(place: place),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static IconData _amenityIcon(HutAmenityType type) => switch (type) {
    HutAmenityType.dining => Icons.soup_kitchen_outlined,
    HutAmenityType.shelter => Icons.bed_outlined,
    HutAmenityType.charging => Icons.bolt,
  };
}

/// A short fact shown inline: an icon followed by a text.
class _HutFact extends StatelessWidget {
  const _HutFact({
    required this.icon,
    required this.text,
    this.iconColor = AppColors.textSecondary,
    this.textColor = AppColors.textSecondary,
  });

  final IconData icon;
  final String text;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppConstants.spacingMd, color: iconColor),
        const SizedBox(width: AppConstants.spacingXs),
        Flexible(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: textColor),
          ),
        ),
      ],
    );
  }
}

/// A collapsible section of additional information, closed by default.
class _HutDetails extends StatelessWidget {
  const _HutDetails({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(icon, size: 20, color: AppColors.primary),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      shape: const Border(),
      collapsedShape: const Border(),
      children: children,
    );
  }
}

/// A trail or a nearby spot: name, optional duration and a short description.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place});

  final HutPlace place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  place.name,
                  style: theme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (place.duration != null) ...[
                const SizedBox(width: AppConstants.spacingSm),
                Text(
                  place.duration!,
                  style: theme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            place.description,
            style: theme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
