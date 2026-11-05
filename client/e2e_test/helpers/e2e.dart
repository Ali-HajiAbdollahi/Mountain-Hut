// Shared helpers for the end-to-end tests.
//
// The E2E tests run the REAL app (MountainHutApp) against the REAL backend:
// no fakes. The backend must be running on http://localhost:3001 with a fresh
// database:   cd server && npm run start:e2e
//
// Test data is created through the API (as the seeded employee) on days that have
// no slots yet, so tests do not depend on each other or on the seed dates.
//
// The same tests run on the Windows desktop app and in Chrome. In the browser every
// API client shares ONE session cookie with the app, so each preparation or check
// below opens its own session and logs out at the end (harmless on desktop).
import 'dart:math';

import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:client/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const password = 'password123';
const staffEmail = 'elena@hut.it'; // seeded employee

final _random = Random();

typedef Hiker = ({String email, String name});

/// Fails with a clear message if the backend is not running.
Future<void> checkBackend() async {
  try {
    await MountainHutApi().health();
  } catch (e) {
    fail('Backend not reachable on http://localhost:3001 ($e).\n'
        'Start it first:  cd server && npm run start:e2e');
  }
}

/// Runs [action] in a session logged in as [email], then logs out.
Future<T> asUser<T>(String email, Future<T> Function(MountainHutApi api) action) async {
  final api = MountainHutApi();
  await api.login(email, password);
  try {
    return await action(api);
  } finally {
    await _logout(api);
  }
}

Future<void> _logout(MountainHutApi api) async {
  try {
    await api.logout();
  } catch (_) {
    // no session to close
  }
}

/// Registers a new hiker with a unique email (and leaves no session open).
Future<Hiker> newHiker([String name = 'E2E Hiker']) async {
  final email = uniqueEmail();
  final api = MountainHutApi();
  await api.register(name: name, email: email, phone: '+39 333 0000000', password: password);
  await _logout(api);
  return (email: email, name: name);
}

String uniqueEmail() =>
    'e2e.${DateTime.now().microsecondsSinceEpoch}.${_random.nextInt(1 << 20)}@mail.it';

/// The bookings of a hiker, as stored on the server.
Future<List<Map<String, dynamic>>> bookingsOf(Hiker hiker) => asUser(hiker.email, (api) => api.myBookings());

/// Books through the API as [hiker] and returns the booking.
Future<Map<String, dynamic>> bookAs(Hiker hiker, int slotId, int people,
        {List<Map<String, dynamic>> requirements = const []}) =>
    asUser(hiker.email, (api) async {
      final res = await api.book(slotId: slotId, people: people, requirements: requirements);
      return res['booking'] as Map<String, dynamic>;
    });

/// The slots of a day (public endpoint).
Future<List<Map<String, dynamic>>> slotsOn(DateTime day) => MountainHutApi().listSlots(ymd(day));

/// A future day (between 30 and 360 days from today) that has no slots yet.
/// Not further: the staff portal calendar stops at 1 January of next-next year.
Future<DateTime> freshDay() async {
  final now = DateTime.now();
  for (var attempt = 0; attempt < 20; attempt++) {
    final day = DateTime(now.year, now.month, now.day + 30 + _random.nextInt(330));
    if ((await slotsOn(day)).isEmpty) return day;
  }
  throw StateError('No free day found');
}

/// Creates a slot through the API, as the seeded employee, and returns its tsID.
Future<int> createSlot(DateTime day, String start, String end, List<Map<String, dynamic>> tables) =>
    asUser(staffEmail, (api) async {
      final slot = await api.createSlot(
        startTime: '${ymd(day)} $start',
        endTime: '${ymd(day)} $end',
        tables: tables,
      );
      return (slot['tsID'] as num).toInt();
    });

List<Map<String, dynamic>> tablesOf(List<int> seats) =>
    [for (var i = 0; i < seats.length; i++) {'table_no': i + 1, 'seats': seats[i]}];

String two(int n) => n.toString().padLeft(2, '0');

/// 'YYYY-MM-DD' (API format)
String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// 'MM/DD/YYYY' (format shown by the app and typed in the date pickers)
String mdy(DateTime d) => '${two(d.month)}/${two(d.day)}/${d.year}';

// ── Driving the app ─────────────────────────────────────────────────────────

/// Starts the real app, as main() does, with a new session.
Future<void> launchApp(WidgetTester tester) async {
  // A tall logical screen: long pages (results, booking cards) are built entirely,
  // without the test having to scroll to bring them into existence.
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Unmount any app from earlier in the same test, so the new one starts from scratch,
  // and close any session left in the browser (shared cookie on the web).
  await tester.pumpWidget(const SizedBox.shrink());
  await _logout(MountainHutApi());
  final api = MountainHutApi();
  await tester.pumpWidget(MountainHutApp(api: api, authRepository: AuthRepositoryImpl(api)));
  await tester.pumpAndSettle();
}

/// Waits until [finder] finds something: the app talks to a real server,
/// so answers do not arrive in a fixed number of frames.
Future<void> waitFor(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 15)}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out after ${timeout.inSeconds}s waiting for: ${finder.describeMatch(Plurality.one)}\n'
          '${describeScreen()}');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// What is on screen (texts and icons), printed when a wait times out.
String describeScreen() {
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText())
      .whereType<String>()
      .toSet();
  final icons = find
      .byType(Icon)
      .evaluate()
      .map((e) => 'U+${(e.widget as Icon).icon?.codePoint.toRadixString(16).toUpperCase()}')
      .toSet();
  return 'On screen — texts: $texts\nicons: $icons';
}

/// Waits until [finder] finds nothing any more.
Future<void> waitUntilGone(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 15)}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for it to disappear: $finder');
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// Taps [finder] like a user: waits until it exists and until a tap at its centre
/// would really reach it (e.g. not while a closing dialog still covers it).
Future<void> tap(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();

  final end = DateTime.now().add(const Duration(seconds: 10));
  while (!_receivesTaps(tester, finder.first)) {
    if (DateTime.now().isAfter(end)) {
      fail('Something covers ${finder.describeMatch(Plurality.one)}: it cannot be tapped.\n${describeScreen()}');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

bool _receivesTaps(WidgetTester tester, Finder finder) {
  final target = tester.renderObject(finder);
  if (target is! RenderBox || !target.hasSize) return false;
  final centre = target.localToGlobal(target.size.center(Offset.zero));
  return tester.hitTestOnBinding(centre).path.any((entry) => entry.target == target);
}

Future<void> type(WidgetTester tester, Finder field, String text) async {
  await waitFor(tester, field);
  await tester.ensureVisible(field.first);
  await tester.enterText(field.first, text);
  await tester.pumpAndSettle();
}

Finder fieldWithHint(String hint) => find.widgetWithText(TextFormField, hint);

/// Types [day] in an open Material date picker (input mode) and confirms.
Future<void> typeInDatePicker(WidgetTester tester, DateTime day) async {
  await tap(tester, find.byIcon(Icons.edit_outlined));
  await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), mdy(day));
  await tap(tester, find.text('OK'));
}

/// Types a time in an open Material time picker (input mode) and confirms.
Future<void> typeInTimePicker(WidgetTester tester, int hour, int minute) async {
  await tap(tester, find.byIcon(Icons.keyboard_outlined));
  final inputs = find.descendant(of: find.byType(Dialog).last, matching: find.byType(TextField));
  await tester.enterText(inputs.at(0), two(hour));
  await tester.enterText(inputs.at(1), two(minute));
  await tap(tester, find.text('OK'));
}

/// Sign in from the "Log In" tab of the bottom navigation.
Future<void> signInFromNavigation(WidgetTester tester, String email) async {
  await tap(tester, find.text('Log In'));
  await signIn(tester, email);
}

/// Fills the sign-in form of the auth screen (switching to it if needed) and submits.
Future<void> signIn(WidgetTester tester, String email, {bool continueBooking = false}) async {
  if (find.text('Sign In to Alpine Hut').evaluate().isEmpty) {
    await tap(tester, find.widgetWithText(TextButton, 'Sign In'));
  }
  await type(tester, fieldWithHint('hiker@domain.com'), email);
  await type(tester, fieldWithHint('••••••••••••'), password);
  await tap(tester, find.widgetWithText(ElevatedButton, continueBooking ? 'Sign In & Continue Booking' : 'Sign In'));
}

/// Explore page: chooses the date of the availability search.
Future<void> chooseSearchDate(WidgetTester tester, DateTime day) async {
  await tap(tester, find.ancestor(of: find.byIcon(Icons.calendar_today), matching: find.byType(InkWell)));
  await typeInDatePicker(tester, day);
  await waitUntilGone(tester, find.byType(CircularProgressIndicator));
}

/// Explore page: sets the party size with the +/- buttons (default is 6).
Future<void> setGuests(WidgetTester tester, int guests) async {
  var current = 6;
  while (current != guests) {
    await tap(tester, find.byIcon(guests > current ? Icons.add : Icons.remove));
    current += guests > current ? 1 : -1;
  }
  await waitFor(tester, find.textContaining('$guests Guests', findRichText: true));
}

Future<void> checkAvailability(WidgetTester tester) async {
  await tap(tester, find.text('Check Availability'));
  await waitFor(
    tester,
    find.byWidgetPredicate((w) =>
        w is Text &&
        (w.data == 'Proceed to Reservation' || w.data == 'No availability found for this slot')),
  );
}
