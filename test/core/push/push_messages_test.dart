import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/push/push_messages.dart';

void main() {
  group('pushRouteFor', () {
    test('all three notifications open the plan they are about', () {
      // The invite to answer it, the request for the owner to accept, the
      // acceptance to see the evening you have just joined.
      for (final type in ['plan_invite', 'join_request', 'join_accepted']) {
        expect(
          pushRouteFor({'type': type, 'plan_id': '42'}),
          '/plans/42',
          reason: '$type should open the plan',
        );
      }
    });

    test('the id arrives as a string, because FCM has no other kind', () {
      // Data values on an FCM message are strings. A parser that expected an
      // int would route nobody, and would do it silently.
      expect(pushRouteFor({'type': 'plan_invite', 'plan_id': '7'}),
          '/plans/7');
    });

    test('a type this build has never heard of opens nothing', () {
      // A newer server may send something this app does not have a screen
      // for; leaving the user where they are beats an error.
      expect(pushRouteFor({'type': 'plan_cancelled', 'plan_id': '42'}), isNull);
      expect(pushRouteFor(const {}), isNull);
    });

    test('an id that is not a plan is refused', () {
      expect(pushRouteFor({'type': 'plan_invite'}), isNull);
      expect(pushRouteFor({'type': 'plan_invite', 'plan_id': 'nope'}), isNull);
      expect(pushRouteFor({'type': 'plan_invite', 'plan_id': '0'}), isNull);
      expect(pushRouteFor({'type': 'plan_invite', 'plan_id': '-3'}), isNull);
    });
  });
}
