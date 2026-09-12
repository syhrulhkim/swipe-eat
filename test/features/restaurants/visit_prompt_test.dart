import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_eat/features/restaurants/data/visit_prompt_cache.dart';
import 'package:swipe_eat/features/restaurants/presentation/visit_prompt_sheet.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart'
    show LikesAuthEvents;
import 'package:swipe_eat/features/restaurants/state/visit_prompt_controller.dart';

import 'fake_restaurant_repositories.dart';

class _FakeAuthEvents extends LikesAuthEvents {
  _FakeAuthEvents({this.userId});

  String? userId;

  @override
  Stream<AuthState>? get changes => null;

  @override
  String? get currentUserId => userId;
}

PendingVisit _visit({int? planId}) {
  return PendingVisit(
    userId: 'u1',
    restaurantId: 7,
    name: 'Sedap Corner',
    openedAt: DateTime.now().subtract(const Duration(days: 2)),
    planId: planId,
  );
}

/// Opens the sheet and hands back the box the answer lands in. Read it after
/// the sheet has closed: it is null until then, which is exactly what a
/// dismissed sheet leaves behind too.
Future<List<VisitPromptResult?>> _openSheet(
  WidgetTester tester, {
  required PendingVisit visit,
}) async {
  final answer = <VisitPromptResult?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                answer.add(await showVisitPromptSheet(context, visit: visit));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return answer;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('the sheet', () {
    testWidgets('a walk-in answered without stars is still a visit',
        (tester) async {
      final answer = await _openSheet(tester, visit: _visit());

      expect(find.text('Did you go to Sedap Corner?'), findsOneWidget);
      expect(find.textContaining('You opened directions'), findsOneWidget);

      await tester.tap(find.text('Yes, I went'));
      await tester.pumpAndSettle();

      expect(answer.single?.went, isTrue);
      expect(answer.single?.rating, isNull);
      expect(answer.single?.note, isNull);
    });

    testWidgets('a star turns the answer into a review', (tester) async {
      final answer = await _openSheet(tester, visit: _visit(planId: 3));

      // A plan says so, rather than claiming directions were opened.
      expect(find.textContaining('You had a plan there'), findsOneWidget);

      await tester.tap(find.byTooltip('4 stars'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Worth the queue  ');
      await tester.pumpAndSettle();

      // The button says what it will do now that there is something to post.
      expect(find.text('Post it'), findsOneWidget);
      await tester.tap(find.text('Post it'));
      await tester.pumpAndSettle();

      expect(answer.single?.went, isTrue);
      expect(answer.single?.rating, 4);
      expect(answer.single?.note, 'Worth the queue');
    });

    testWidgets('"I didn\'t go" drops the stars it was given', (tester) async {
      final answer = await _openSheet(tester, visit: _visit(planId: 3));

      await tester.tap(find.byTooltip('5 stars'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("I didn't go"));
      await tester.pumpAndSettle();

      expect(answer.single?.went, isFalse);
      expect(answer.single?.rating, isNull);
    });
  });

  group('the controller', () {
    test('falls back to the plan prompt, and asks the backend once', () async {
      final swipes = FakeSwipeRepository()..planPrompt = _visit(planId: 12);
      final controller = VisitPromptController(
        swipes: swipes,
        authEvents: _FakeAuthEvents(userId: 'u1'),
      );

      final first = await controller.next();
      expect(first?.planId, 12);

      // Answered: the question is gone for this run without a second lookup.
      await controller.confirm(first!, rating: 5, note: 'Good');
      expect(await controller.next(), isNull);

      expect(swipes.visitAnswers.single.rating, 5);
      expect(swipes.visitAnswers.single.planId, 12);
      expect(swipes.visitAnswers.single.went, isTrue);
    });

    test('"I didn\'t go" on a plan writes the correction back', () async {
      final swipes = FakeSwipeRepository();
      final controller = VisitPromptController(
        swipes: swipes,
        authEvents: _FakeAuthEvents(userId: 'u1'),
      );

      await controller.dismiss(_visit(planId: 12));

      expect(swipes.visitAnswers.single.went, isFalse);
      expect(swipes.visitAnswers.single.planId, 12);
    });

    test('"I didn\'t go" on a walk-in writes nothing', () async {
      final swipes = FakeSwipeRepository();
      final controller = VisitPromptController(
        swipes: swipes,
        authEvents: _FakeAuthEvents(userId: 'u1'),
      );

      await controller.dismiss(_visit());

      expect(swipes.visitAnswers, isEmpty);
    });
  });
}
