abstract interface class BookingRepository {
  Future<Map<String, dynamic>> createBooking({
    required int slotId,
    required int partySize,
    required List<Map<String, dynamic>> requirements,
  });
}
