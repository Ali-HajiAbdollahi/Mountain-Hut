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
import '../../features/account/presentation/pages/account_page.dart';
import '../../features/staff_portal/presentation/pages/staff_dashboard_page.dart';
import '../../features/hike_registration/presentation/pages/hike_registration_page.dart';

class AppNavigation {
  const AppNavigation._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Route<void> explore({
    required AuthRepository authRepository,
    required MountainHutApi api,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          ExplorePage(authRepository: authRepository, api: api),
    );
  }

  static Route<void> auth({
    required AuthRepository authRepository,
    required AuthContext authContext,
    ValueChanged<Map<String, dynamic>>? onSignIn,
    ValueChanged<Map<String, dynamic>>? onRegister,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => AuthScreen(
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
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => BookingPage(
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
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          BookingSuccessPage(
            api: api,
            booking: booking,
            allocation: allocation,
            notificationSent: notificationSent,
          ),
    );
  }

  static Route<void> myBookings({
    required MountainHutApi api,
    AuthRepository? authRepository,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          MyBookingsPage(api: api, authRepository: authRepository),
    );
  }

  static Route<void> account({
    AuthRepository? authRepository,
    required MountainHutApi api,
    VoidCallback? onExplore,
    VoidCallback? onBookings,
    VoidCallback? onStaffPortal,
    VoidCallback? onLogout,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => AccountPage(
        api: api,
        authRepository: authRepository,
        onExplore: onExplore,
        onBookings: onBookings,
        onStaffPortal: onStaffPortal,
        onLogout: onLogout,
      ),
    );
  }

  static Route<void> staffPortal({
    required AuthRepository authRepository,
    required MountainHutApi api,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          StaffDashboardPage(authRepository: authRepository, api: api),
    );
  }

  static Route<void> hikeRegistration({required MountainHutApi api}) {
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) =>
          HikeRegistrationPage(api: api),
    );
  }
}
