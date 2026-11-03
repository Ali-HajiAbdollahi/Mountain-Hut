import '../../../../core/network/mountain_hut_api.dart';
import '../../domain/repositories/booking_repository.dart';

class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this._api);

  final MountainHutApi _api;

  @override
  Future<Map<String, dynamic>> createBooking({
    required int slotId,
    required int partySize,
    required List<Map<String, dynamic>> requirements,
  }) {
    return _api.book(
      slotId: slotId,
      people: partySize,
      requirements: requirements,
    );
  }
}
