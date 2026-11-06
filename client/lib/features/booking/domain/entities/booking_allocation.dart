class BookingAllocation {
  const BookingAllocation({
    required this.date,
    required this.slotId,
    required this.startTime,
    required this.endTime,
    required this.partySize,
    required this.seasonLabel,
    required this.seatingLabel,
    required this.tablesLabel,
  });

  final String date;
  final int slotId;
  final String startTime;
  final String endTime;
  final int partySize;
  final String seasonLabel;
  final String seatingLabel;
  final String tablesLabel;
}
