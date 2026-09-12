/// What a notification means to the router.
///
/// Pure, and separate from anything Firebase, because this is the one part of
/// the push path a test can drive: everything else is a platform channel. The
/// payload is whatever `send-push` put in the message's `data` map, and it
/// arrives with every value as a **string** — FCM's data values are strings,
/// so `plan_id` is "42" and never 42.
library;

/// Where a tapped notification should land, or null when it says nothing this
/// app can open.
///
/// Null is the safe answer, and it is taken for anything unexpected: a message
/// from a newer server, a type this build has never heard of, an id that is
/// not a number. A push that cannot be routed leaves the user where they were
/// rather than on an error screen.
String? pushRouteFor(Map<String, dynamic> data) {
  final type = data['type'];
  if (type != 'plan_invite' &&
      type != 'join_request' &&
      type != 'join_accepted') {
    return null;
  }

  final planId = int.tryParse('${data['plan_id']}');
  if (planId == null || planId <= 0) {
    return null;
  }

  // All three land on the plan: the invite to answer it, the request for the
  // owner to accept it, the acceptance to see the evening you just joined.
  return '/plans/$planId';
}
