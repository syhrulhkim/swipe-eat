import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe_eat/core/ui/app_buttons.dart';
import 'package:swipe_eat/features/auth/data/auth_repository.dart';
import 'package:swipe_eat/features/auth/presentation/phone_sign_in_page.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';

import '../../support/widget_test_support.dart';
import 'fake_auth_repository.dart';

const Size _phoneViewport = Size(390, 844);
const Size _narrowViewport = Size(320, 568);
const TextScaler _hugeTextScale = TextScaler.linear(2);

/// A hand-cranked stand-in for the one-second tick, so a test can run the
/// thirty-second countdown without waiting thirty seconds.
class _FakeTicker {
  final _controller = StreamController<void>.broadcast();

  Stream<void> call() => _controller.stream;

  Future<void> tick(WidgetTester tester, int times) async {
    for (var i = 0; i < times; i++) {
      _controller.add(null);
      // Twice: the stream event lands in a microtask, so the first pump
      // delivers it and the second draws the frame it asked for.
      await tester.pump();
      await tester.pump();
    }
  }

  Future<void> dispose() => _controller.close();
}

class _Harness {
  _Harness(this.repository, this.ticker);

  final FakeAuthRepository repository;
  final _FakeTicker ticker;
}

Future<_Harness> _pumpPage(
  WidgetTester tester, {
  Size viewport = _phoneViewport,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  useViewport(tester, viewport);
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final repository = FakeAuthRepository(supportsPhoneSignIn: true);
  final controller = AuthController(repository);
  final ticker = _FakeTicker();
  addTearDown(controller.dispose);
  addTearDown(repository.dispose);
  addTearDown(ticker.dispose);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: PhoneSignInPage(
        authController: controller,
        ticker: ticker.call,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(repository, ticker);
}

Finder get _numberField => find.byKey(const ValueKey('phone-number-field'));
Finder get _codeField => find.byKey(const ValueKey('phone-code-field'));

/// The button's enabled state, read the way the widget reports it rather than
/// by looking at pixels.
bool _sendEnabled(WidgetTester tester) {
  final button = tester.widget<AppPrimaryButton>(
    find.widgetWithText(AppPrimaryButton, 'Send code'),
  );
  return button.onPressed != null;
}

void main() {
  group('PhoneSignInPage asking for the number', () {
    testWidgets('asks for one thing, and says what happens next',
        (tester) async {
      await _pumpPage(tester);

      expect(find.text("What's your number?"), findsOneWidget);
      expect(
        find.textContaining("We'll text you a six-digit code"),
        findsOneWidget,
      );
      // Malaysia only for now: a fixed prefix, not a country picker.
      expect(find.text('+60'), findsOneWidget);
    });

    testWidgets('Send code stays off until the number could be one',
        (tester) async {
      await _pumpPage(tester);
      expect(_sendEnabled(tester), isFalse);

      await tester.enterText(_numberField, '1234');
      await tester.pump();
      expect(_sendEnabled(tester), isFalse,
          reason: 'four digits is not a Malaysian number');

      await tester.enterText(_numberField, '123456789');
      await tester.pump();
      expect(_sendEnabled(tester), isTrue);
    });

    testWidgets('the local trunk zero is dropped before +60 is added',
        (tester) async {
      final harness = await _pumpPage(tester);

      // People type the number the way it is written locally.
      await tester.enterText(_numberField, '012 345 6789');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(harness.repository.calls, contains('phone:+60123456789'));
    });

    testWidgets('a number already carrying 60 is not doubled', (tester) async {
      final harness = await _pumpPage(tester);

      await tester.enterText(_numberField, '60123456789');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(harness.repository.calls, contains('phone:+60123456789'));
    });

    testWidgets('a refused send is reported under the field', (tester) async {
      final harness = await _pumpPage(tester);
      harness.repository.nextFailure = const AuthFailure(
        'Phone sign-in is not switched on yet. Use email instead.',
      );

      await tester.enterText(_numberField, '123456789');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(
        find.text('Phone sign-in is not switched on yet. Use email instead.'),
        findsOneWidget,
      );
      // Still on the number, because no code was sent.
      expect(_codeField, findsNothing);
    });
  });

  group('PhoneSignInPage entering the code', () {
    Future<_Harness> sendCode(WidgetTester tester) async {
      final harness = await _pumpPage(tester);
      await tester.enterText(_numberField, '123456789');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      return harness;
    }

    testWidgets('the screen moves on to the code and names the number',
        (tester) async {
      await sendCode(tester);

      expect(find.text('Check your messages'), findsOneWidget);
      expect(find.textContaining('+60123456789'), findsOneWidget);
      expect(_codeField, findsOneWidget);
    });

    testWidgets('Verify waits for all six digits', (tester) async {
      await sendCode(tester);

      VoidCallback? verify() => tester
          .widget<AppPrimaryButton>(
            find.widgetWithText(AppPrimaryButton, 'Verify'),
          )
          .onPressed;

      expect(verify(), isNull);
      await tester.enterText(_codeField, '123');
      await tester.pump();
      expect(verify(), isNull);

      await tester.enterText(_codeField, '123456');
      await tester.pump();
      expect(verify(), isNotNull);
    });

    testWidgets('the code reaches the repository with the number',
        (tester) async {
      final harness = await sendCode(tester);

      await tester.enterText(_codeField, '123456');
      await tester.pump();
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(
        harness.repository.calls,
        contains('verify:+60123456789:123456'),
      );
    });

    testWidgets('a wrong code is said plainly under the field',
        (tester) async {
      final harness = await sendCode(tester);
      harness.repository.nextFailure = const AuthFailure(
        'That code is wrong or has expired. Ask for a new one.',
      );

      await tester.enterText(_codeField, '000000');
      await tester.pump();
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(
        find.text('That code is wrong or has expired. Ask for a new one.'),
        findsOneWidget,
      );
    });

    testWidgets('the resend counts down, then offers a new code',
        (tester) async {
      final harness = await sendCode(tester);

      expect(find.text('Resend in 30 s'), findsOneWidget);
      expect(find.text('Send a new code'), findsNothing);

      await harness.ticker.tick(tester, 1);
      expect(find.text('Resend in 29 s'), findsOneWidget);

      await harness.ticker.tick(tester, 29);
      expect(find.textContaining('Resend in'), findsNothing);
      expect(find.text('Send a new code'), findsOneWidget);

      await tester.tap(find.text('Send a new code'));
      await tester.pumpAndSettle();

      // Two sends for the same number: the first one, and this one.
      expect(
        harness.repository.calls.where((c) => c == 'phone:+60123456789').length,
        2,
      );
      expect(find.text('Resend in 30 s'), findsOneWidget);
    });

    testWidgets('changing the number goes back to the first step',
        (tester) async {
      await sendCode(tester);

      await tester.tap(find.text('Change number'));
      await tester.pumpAndSettle();

      expect(find.text("What's your number?"), findsOneWidget);
      expect(_codeField, findsNothing);
      expect(_numberField, findsOneWidget);
    });
  });

  group('PhoneSignInPage accessibility and layout', () {
    testWidgets('the back control is labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester);

      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('does not overflow on the narrowest phone', (tester) async {
      await _pumpPage(tester, viewport: _narrowViewport);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at a huge text scale', (tester) async {
      await _pumpPage(
        tester,
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the code step does not overflow at a huge text scale',
        (tester) async {
      await _pumpPage(
        tester,
        viewport: _narrowViewport,
        textScaler: _hugeTextScale,
      );

      await tester.enterText(_numberField, '123456789');
      await tester.pump();
      await tester.ensureVisible(find.text('Send code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(find.text('Check your messages'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
