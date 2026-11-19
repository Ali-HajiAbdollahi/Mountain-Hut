import 'dart:convert';

import 'package:flutter/services.dart';

enum HutAmenityType { dining, shelter, charging }

class HutAmenity {
  const HutAmenity({required this.type, required this.label});

  factory HutAmenity.fromJson(Map<String, dynamic> json) => HutAmenity(
    type: HutAmenityType.values.byName(json['type'] as String),
    label: json['label'] as String,
  );

  final HutAmenityType type;
  final String label;
}

class HutPlace {
  const HutPlace({
    required this.name,
    required this.description,
    this.duration,
  });

  factory HutPlace.fromJson(Map<String, dynamic> json) => HutPlace(
    name: json['name'] as String,
    description: json['description'] as String,
    duration: json['duration'] as String?,
  );

  final String name;
  final String description;
  final String? duration;
}

class HutInformation {
  const HutInformation({
    required this.logoUrl,
    required this.homeSubtitle,
    required this.elevation,
    required this.name,
    required this.description,
    required this.amenities,
    required this.locationLabel,
    required this.locationName,
    required this.locationDescription,
    required this.coordinates,
    required this.directionsLabel,
    required this.trails,
    required this.nearbyLabel,
    required this.nearby,
  });

  factory HutInformation.fromJson(Map<String, dynamic> json) => HutInformation(
    logoUrl: json['logoUrl'] as String,
    homeSubtitle: json['homeSubtitle'] as String,
    elevation: json['elevation'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    amenities: (json['amenities'] as List<dynamic>)
        .map((item) => HutAmenity.fromJson(item as Map<String, dynamic>))
        .toList(),
    locationLabel: json['locationLabel'] as String,
    locationName: json['locationName'] as String,
    locationDescription: json['locationDescription'] as String,
    coordinates: json['coordinates'] as String,
    directionsLabel: json['directionsLabel'] as String,
    trails: (json['trails'] as List<dynamic>)
        .map((item) => HutPlace.fromJson(item as Map<String, dynamic>))
        .toList(),
    nearbyLabel: json['nearbyLabel'] as String,
    nearby: (json['nearby'] as List<dynamic>)
        .map((item) => HutPlace.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  static final Future<HutInformation> asset = _load();

  static Future<HutInformation> _load() async {
    final json = await rootBundle.loadString(
      'assets/config/hut_information.json',
    );
    return HutInformation.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  final String logoUrl;
  final String homeSubtitle;
  final String elevation;
  final String name;
  final String description;
  final List<HutAmenity> amenities;
  final String locationLabel;
  final String locationName;
  final String locationDescription;
  final String coordinates;
  final String directionsLabel;
  final List<HutPlace> trails;
  final String nearbyLabel;
  final List<HutPlace> nearby;
}
