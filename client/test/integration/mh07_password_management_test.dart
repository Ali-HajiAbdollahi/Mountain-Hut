// MH-07 Reserve for an hiker — integration tests for the forced password change after login and for
// the password recovery screens (AuthScreen with a fake repository, no backend).
import 'package:client/core/network/mountain_hut_api.dart';
import 'package:client/features/auth/domain/entities/auth_context.dart';
import 'package:client/features/auth/domain/repositories/auth_repository.dart';
import 'package:client/features/auth/presentation/pages/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

class _AuthRepository implements AuthRepository {
  final calls = <Call>[];
  Map<String, dynamic> signedInUser = {'uID': 5, 'role': 'hiker', 'must_change_password': false};
  ApiException? changeError;
  ApiException? resetError;

  @override
  Future<Map<String, dynamic>> signIn({required String email, required String password}) async {
    calls.add(Call('signIn', {'email': email, 'password': password}));
    return signedInUser;
  }

  @override
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    calls.add(Call('changePassword', {'current': currentPassword, 'new': newPassword}));
    if (changeError != null) throw changeError!;
    return {...signedInUser, 'must_change_password': false};
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    calls.add(Call('requestPasswordReset', {'email': email}));
  }

  @override
  Future<void> confirmPasswordReset({required String token, required String newPassword}) async {
    calls.add(Call('confirmPasswordReset', {'token': token, 'new': newPassword}));
    if (resetError != null) throw resetError!;
  }
}

void main() {
  late _AuthRepository repository;
  Map<String, dynamic>? signedIn;

  setUp(() {
    repository = _AuthRepository();
    signedIn = null;
  });

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openSignIn(WidgetTester tester) async {
    await pumpPage(
      tester,
      AuthScreen(
        authContext: AuthContext.directAccess,
        authRepository: repository,
        onSignIn: (user) => signedIn = user,
      ),
    );
    await tap(tester, find.text('Sign In').first);
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'hiker@domain.com'), 'luca@mail.it');
    await tester.enterText(find.widgetWithIcon(TextFormField, Icons.lock_outline), 'Temp-Passw0rd');
    await tap(tester, find.text('Sign In').last);
  }

  // Both screens list their fields in this order: (temporary password | reset code), new, confirm.
  Finder passwordField(String label) => find.byType(TextFormField).at(
      const {'Temporary password': 0, 'New password': 1, 'Confirm new password': 2}[label]!);

  group('Temporary password after login', () {
    testWidgets('opens "Change password" before anything else when a change is required', (tester) async {
      repository.signedInUser = {'uID': 5, 'role': 'hiker', 'must_change_password': true};
      await openSignIn(tester);
      await signIn(tester);

      expect(find.text('Choose a new password'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(signedIn, isNull); // the app is not entered yet
    });

    testWidgets('the forced screen cannot be dismissed with the system back button', (tester) async {
      repository.signedInUser = {'uID': 5, 'role': 'hiker', 'must_change_password': true};
      await openSignIn(tester);
      await signIn(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Choose a new password'), findsOneWidget);
    });

    testWidgets('after changing the password the user enters the app, without the flag', (tester) async {
      repository.signedInUser = {'uID': 5, 'role': 'hiker', 'must_change_password': true};
      await openSignIn(tester);
      await signIn(tester);

      await tester.enterText(passwordField('Temporary password'), 'Temp-Passw0rd');
      await tester.enterText(passwordField('New password'), 'My-own-password');
      await tester.enterText(passwordField('Confirm new password'), 'My-own-password');
      await tap(tester, find.widgetWithText(ElevatedButton, 'Change password'));

      expect(repository.calls.last.method, 'changePassword');
      expect(repository.calls.last.args, {'current': 'Temp-Passw0rd', 'new': 'My-own-password'});
      expect(signedIn, containsPair('must_change_password', false));
      expect(find.text('Choose a new password'), findsNothing);
    });

    testWidgets('validates the new password and shows a server refusal', (tester) async {
      repository.signedInUser = {'uID': 5, 'role': 'hiker', 'must_change_password': true};
      repository.changeError = const ApiException(400, 'VALIDATION_ERROR', 'Current password is not correct');
      await openSignIn(tester);
      await signIn(tester);

      await tester.enterText(passwordField('Temporary password'), 'Temp-Passw0rd');
      await tester.enterText(passwordField('New password'), 'short');
      await tap(tester, find.widgetWithText(ElevatedButton, 'Change password'));
      expect(find.text('Password must be at least 8 characters'), findsOneWidget);

      await tester.enterText(passwordField('New password'), 'Temp-Passw0rd');
      await tap(tester, find.widgetWithText(ElevatedButton, 'Change password'));
      expect(find.text('The new password must be different'), findsOneWidget);

      await tester.enterText(passwordField('New password'), 'My-own-password');
      await tester.enterText(passwordField('Confirm new password'), 'Another-password');
      await tap(tester, find.widgetWithText(ElevatedButton, 'Change password'));
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(repository.calls.where((c) => c.method == 'changePassword'), isEmpty);

      await tester.enterText(passwordField('Confirm new password'), 'My-own-password');
      await tap(tester, find.widgetWithText(ElevatedButton, 'Change password'));
      expect(find.text('Current password is not correct'), findsOneWidget);
      expect(signedIn, isNull);
    });

    testWidgets('a normal sign-in goes straight into the app', (tester) async {
      await openSignIn(tester);
      await signIn(tester);

      expect(find.text('Choose a new password'), findsNothing);
      expect(signedIn, containsPair('uID', 5));
    });
  });

  group('Forgot password', () {
    testWidgets('the "Forgot?" button opens the reset request, which always gives the same answer', (tester) async {
      await openSignIn(tester);
      await tap(tester, find.text('Forgot?'));
      expect(find.text('Forgot your password?'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'hiker@domain.com'), 'nobody@mail.it');
      await tap(tester, find.text('Send reset link'));

      expect(repository.calls.last.method, 'requestPasswordReset');
      expect(repository.calls.last.args, {'email': 'nobody@mail.it'});
      expect(find.textContaining('If an account exists for this email'), findsOneWidget);
    });

    testWidgets('the email must be valid', (tester) async {
      await openSignIn(tester);
      await tap(tester, find.text('Forgot?'));
      await tester.enterText(find.widgetWithText(TextFormField, 'hiker@domain.com'), 'not-an-email');
      await tap(tester, find.text('Send reset link'));

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(repository.calls.where((c) => c.method == 'requestPasswordReset'), isEmpty);
    });

    testWidgets('a reset code sets the new password and returns to the sign in', (tester) async {
      await openSignIn(tester);
      await tap(tester, find.text('Forgot?'));
      await tap(tester, find.text('I already have a reset code'));
      expect(find.text('Set a new password'), findsOneWidget);

      await tester.enterText(find.widgetWithIcon(TextFormField, Icons.vpn_key_outlined), 'token-from-email');
      await tester.enterText(passwordField('New password'), 'My-new-password');
      await tester.enterText(passwordField('Confirm new password'), 'My-new-password');
      await tap(tester, find.widgetWithText(ElevatedButton, 'Set new password'));

      expect(repository.calls.last.method, 'confirmPasswordReset');
      expect(repository.calls.last.args, {'token': 'token-from-email', 'new': 'My-new-password'});
      expect(find.text('Hiker Access'), findsOneWidget); // back on the sign-in screen
      expect(find.text('Password updated. Sign in with your new password.'), findsOneWidget);
    });

    testWidgets('an expired or used code shows the server message and keeps the form', (tester) async {
      repository.resetError = const ApiException(400, 'VALIDATION_ERROR', 'Invalid or expired reset link');
      await openSignIn(tester);
      await tap(tester, find.text('Forgot?'));
      await tap(tester, find.text('I already have a reset code'));

      await tester.enterText(find.widgetWithIcon(TextFormField, Icons.vpn_key_outlined), 'old-token');
      await tester.enterText(passwordField('New password'), 'My-new-password');
      await tester.enterText(passwordField('Confirm new password'), 'My-new-password');
      await tap(tester, find.widgetWithText(ElevatedButton, 'Set new password'));

      expect(find.text('Invalid or expired reset link'), findsOneWidget);
      expect(find.text('Set a new password'), findsOneWidget);
    });
  });
}
