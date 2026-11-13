class HikeDraft {
  const HikeDraft({
    required this.destination,
    required this.routeDescription,
    required this.passagePoints,
    required this.departureTime,
    required this.expectedReturnTime,
    required this.partySize,
    required this.hikerPhone,
    required this.emergencyContact,
  });

  final String destination;
  final String routeDescription;
  final List<String> passagePoints;
  final DateTime departureTime;
  final DateTime expectedReturnTime;
  final int partySize;
  final String hikerPhone;
  final String emergencyContact;

  Map<String, dynamic> toJson() => {
        'destination': destination,
        'route_description': routeDescription,
        'passage_points': passagePoints,
        'departure_time': _fmt(departureTime),
        'expected_return_time': _fmt(expectedReturnTime),
        'party_size': partySize,
        'hiker_phone': hikerPhone,
        'emergency_contact': emergencyContact,
      };

  String _fmt(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}