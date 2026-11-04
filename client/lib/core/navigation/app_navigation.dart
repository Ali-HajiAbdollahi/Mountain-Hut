import 'package:flutter/material.dart';

import '../network/mountain_hut_api.dart';
import '../../features/auth/domain/entities/auth_context.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/pages/auth_screen.dart';
import '../../features/booking/data/repositories/booking_repository_impl.dart';
import '../../features/booking/domain/entities/booking_allocation.dart';
import '../../features/booking/presentation/pages/booking_page.dart';
import '../../features/booking/presentation/pages/booking_success_page.dart';
import '../../features/explore/presentation/pages/explore_page.dart';
import '../../features/hiker_portal/presentation/pages/my_bookings_page.dart';

class AppNavigation {
  const AppNavigation._();

  static Route<void> explore({
    required AuthRepository authRepository,
    required MountainHutApi api,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => ExplorePage(authRepository: authRepository, api: api),
    );
  }

  static Route<void> auth({
    required AuthRepository authRepository,
    required AuthContext authContext,
    ValueChanged<Map<String, dynamic>>? onSignIn,
    ValueChanged<Map<String, dynamic>>? onRegister,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => AuthScreen(
        authContext: authContext,
        authRepository: authRepository,
        onSignIn: onSignIn,
        onRegister: onRegister,
      ),
    );
  }

  static Route<void> booking({
    required MountainHutApi api,
    required BookingAllocation allocation,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => BookingPage(
        allocation: allocation,
        repository: BookingRepositoryImpl(api),
        api: api,
      ),
    );
  }

  static Route<void> bookingSuccess({
    required MountainHutApi api,
    required Map<String, dynamic> booking,
    required BookingAllocation allocation,
    required bool notificationSent,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => BookingSuccessPage(
        api: api,
        booking: booking,
        allocation: allocation,
        notificationSent: notificationSent,
      ),
    );
  }

  static Route<void> myBookings({required MountainHutApi api}) {
    return MaterialPageRoute<void>(builder: (_) => MyBookingsPage(api: api));
  }
}
