class HikeDraft {
  const HikeDraft({
    required this.destination,
    required this.routeDescription,
    required this.passagePoints,
    required this.departureTime,
    required this.expectedReturnTime,
  });

  final String destination;
  final String routeDescription;
  final List<String> passagePoints;
  final DateTime departureTime;
  final DateTime expectedReturnTime;

  Map<String, dynamic> toJson() => {
    'destination': destination,
    'route': routeDescription,
    'departure_time': _fmt(departureTime),
    'expected_return': _fmt(expectedReturnTime),
    'waypoints': passagePoints
        .where((point) => point.trim().isNotEmpty)
        .map((point) => {'name': point.trim()})
        .toList(),
  };

  String _fmt(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
