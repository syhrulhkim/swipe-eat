import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/auth/state/auth_controller.dart';
import 'package:swipe_eat/features/dashboard/presentation/dashboard_page.dart';
import 'package:swipe_eat/features/dashboard/state/dashboard_tab_request.dart';
import 'package:swipe_eat/features/plans/data/plans_repository.dart';
import 'package:swipe_eat/features/plans/state/plans_controller.dart';
import 'package:swipe_eat/features/restaurants/state/likes_controller.dart';

import '../../support/widget_test_support.dart';
import '../auth/fake_auth_repository.dart';
import 'fake_plans_repository.dart';

final DateTime _now = DateTime(2026, 9, 2, 11);

int _visibleTabIndex(WidgetTester tester) {
  return tester.widget<IndexedStack>(find.byType(IndexedStack)).index!;
}

Future<(DashboardTabRequest, PlansController)> _pumpDashboard(
  WidgetTester tester, {
  FakePlansRepository? repository,
  LikesController? likes,
}) async {
  useViewport(tester, const Size(390, 844));
  final tabs = DashboardTabRequest();
  addTearDown(tabs.dispose);
  final plans = PlansController(
    repository: repository ?? FakePlansRepository(),
    clock: () => _now,
    followAuthChanges: false,
    likes: likes,
  );
  addTearDown(plans.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: DashboardPage(
        authController:
            AuthController(FakeAuthRepository(sessionPresent: true)),
        tabRequests: tabs,
        plans: plans,
      ),
    ),
  );
  // Not pumpAndSettle: the other tabs run their own idle animations, so the
  // tree never goes quiet.
  await tester.pump();
  await tester.pump(kMotionDuration);

  return (tabs, plans);
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('the very first tab request is honoured', (tester) async {
    // The regression this guards: a lazily-seeded revision is first read
    // inside the listener, by which time the request has already bumped it, so
    // the request compares equal to itself and is dropped.
    final (tabs, _) = await _pumpDashboard(tester);
    expect(_visibleTabIndex(tester), 0);

    tabs.show(3);
    await tester.pump();
    await tester.pump(kMotionDuration);

    expect(_visibleTabIndex(tester), 3);
  });

  testWidgets('a second request to another tab is honoured too',
      (tester) async {
    final (tabs, _) = await _pumpDashboard(tester);

    tabs.show(3);
    await tester.pump();
    await tester.pump(kMotionDuration);
    tabs.show(0);
    await tester.pump();
    await tester.pump(kMotionDuration);

    expect(_visibleTabIndex(tester), 0);
  });

  testWidgets('the dashboard loads the plans and publishes the planned ids',
      (tester) async {
    final likes = LikesController(followAuthChanges: false);
    addTearDown(likes.dispose);
    final repository = FakePlansRepository(
      rows: [testPlan(1, restaurantId: 306, date: DateTime(2026, 9, 4))],
      stats: const PlanStats(plansKept: 12, streakWeeks: 3),
    );

    final (_, plans) = await _pumpDashboard(
      tester,
      repository: repository,
      likes: likes,
    );
    await tester.pump();

    expect(plans.isLoaded, isTrue);
    expect(plans.stats.plansKept, 12);
    expect(likes.plannedRestaurantIds, {306});
  });
}
