import 'package:geolocator/geolocator.dart';

import '../features/friends/models/friend.dart';
import '../features/plans/data/plans_repository.dart';
import '../features/plans/models/friend_plan.dart';
import '../features/plans/models/plan.dart';

/// Plans that make the Calendar tab look like the S6 prototype.
///
/// Enabled with `--dart-define=USE_DEV_PLANS=true`. The restaurants and friends
/// are fictional; the photos are the same Unsplash stills the prototype uses.
class DevPlansRepository implements PlansRepository {
  static const String _chiliCover =
      'https://images.unsplash.com/photo-1689997122000-c94449288dd1?auto=format&fit=crop&w=200&q=70';
  static const String _satayCover =
      'https://images.unsplash.com/photo-1603088549155-6ae9395b928f?auto=format&fit=crop&w=200&q=70';
  static const String _kakRosCover =
      'https://images.unsplash.com/photo-1770966485209-e20d97337f1a?auto=format&fit=crop&w=200&q=70';

  @override
  Future<List<Plan>> list({required DateTime from, int limit = 300}) async {
    return [
      Plan(
        id: 1,
        restaurantId: 101,
        date: DateTime(2026, 9, 2),
        hour: 12,
        minute: 30,
        withFriends: true,
        restaurantName: 'Chili Pan Mee 88',
        coverUrl: _chiliCover,
        tag: 'Dry noodles',
        neighbourhood: 'Kepong',
        latitude: 3.1950,
        longitude: 101.6320,
        members: const [
          PlanMember(userId: 'mei', status: 'invited'),
          PlanMember(userId: 'syafiq', status: 'invited'),
        ],
      ),
      Plan(
        id: 2,
        restaurantId: 102,
        date: DateTime(2026, 9, 2),
        hour: 20,
        minute: 30,
        restaurantName: 'Bakar & Bara Satay',
        coverUrl: _satayCover,
        tag: 'Satay',
        neighbourhood: 'Kajang',
        latitude: 2.9936,
        longitude: 101.7870,
      ),
      Plan(
        id: 3,
        restaurantId: 103,
        date: DateTime(2026, 9, 4),
        hour: 20,
        minute: 0,
        withFriends: true,
        restaurantName: 'Warung Kak Ros',
        coverUrl: _kakRosCover,
        tag: 'Nasi lemak',
        neighbourhood: 'Kampung Baru',
        latitude: 3.1614,
        longitude: 101.7045,
        members: const [
          PlanMember(userId: 'aiman', status: 'going'),
          PlanMember(userId: 'mei', status: 'going'),
          PlanMember(userId: 'syafiq', status: 'invited'),
        ],
      ),
    ];
  }

  /// Two friends' evenings, so `USE_DEV_PLANS` shows the Friends section the
  /// way the prototype does: one with people you know on it, one with nobody.
  @override
  Future<List<FriendPlan>> friendsPlans({
    required DateTime from,
    int limit = 100,
  }) async {
    return [
      FriendPlan(
        id: 501,
        owner: const FriendProfile(id: 'aisyah', name: 'Aisyah Rahman'),
        restaurantId: 201,
        restaurantName: 'Nasi Kandar Pelita',
        date: DateTime(2026, 9, 3),
        hour: 19,
        minute: 30,
        coverUrl: _kakRosCover,
        goingCount: 3,
        goingFriends: const [
          FriendProfile(id: 'farah', name: 'Farah Idris'),
        ],
      ),
      FriendPlan(
        id: 502,
        owner: const FriendProfile(id: 'aiman', name: 'Aiman Zulkifli'),
        restaurantId: 202,
        restaurantName: 'Sate Kajang Hj Samuri',
        date: DateTime(2026, 9, 5),
        timeLabel: 'late',
        coverUrl: _satayCover,
        asked: true,
      ),
    ];
  }

  @override
  Future<void> setShared(int planId, bool shared) async {}

  @override
  Future<int> create({
    required int restaurantId,
    required DateTime date,
    String? time,
    String? timeLabel,
    bool withFriends = false,
    bool shared = false,
  }) async {
    return 1000;
  }

  @override
  Future<void> cancel(int planId) async {}

  @override
  Future<void> setTime(
    int planId, {
    String? time,
    String? timeLabel,
  }) async {}

  @override
  Future<int> markKept(DateTime today) async => 0;

  @override
  Future<PlanStats> stats(DateTime today) async {
    return const PlanStats(plansKept: 27, streakWeeks: 6);
  }
}

/// A KL fix so the dev plans render the same distances the prototype shows.
Future<Position> devUserPosition() async {
  return Position(
    longitude: 101.6869,
    latitude: 3.1390,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
