import 'package:swipe_eat/features/plans/data/plans_repository.dart';
import 'package:swipe_eat/features/plans/models/plan.dart';

/// A minimal but real [Plan] for list fixtures.
Plan testPlan(
  int id, {
  required DateTime date,
  int? restaurantId,
  int? hour = 20,
  int? minute = 0,
  String? timeLabel,
  bool withFriends = false,
  PlanStatus status = PlanStatus.planned,
  String name = 'Warung Kak Ros',
  String? coverUrl,
  String? tag = 'Nasi lemak',
  String? neighbourhood = 'Kepong',
  double? latitude,
  double? longitude,
  List<PlanMember> members = const [],
}) {
  return Plan(
    id: id,
    restaurantId: restaurantId ?? id,
    date: date,
    hour: hour,
    minute: minute,
    timeLabel: timeLabel,
    withFriends: withFriends,
    status: status,
    restaurantName: name,
    coverUrl: coverUrl,
    tag: tag,
    neighbourhood: neighbourhood,
    latitude: latitude,
    longitude: longitude,
    members: members,
  );
}

/// Stands in for the `plans` table and its RPCs. It applies the rules the
/// database applies — one plan per owner, restaurant and day (D107); past
/// plans flip to kept unless cancelled (D108); cancelled rows are never
/// listed — so a controller test exercises the real behaviour rather than a
/// permissive stub. It records the arguments it was handed so a widget test
/// can assert on what the screen asked for.
class FakePlansRepository implements PlansRepository {
  FakePlansRepository({
    List<Plan> rows = const [],
    PlanStats stats = const PlanStats(),
  })  : _rows = List.of(rows),
        _stats = stats;

  List<Plan> _rows;
  PlanStats _stats;

  int _nextId = 1000;

  /// Every `list` call's `from`, in order.
  final List<DateTime> listedFrom = <DateTime>[];

  /// Every `create` call's arguments, in order.
  final List<Map<String, Object?>> created = <Map<String, Object?>>[];

  final List<int> cancelled = <int>[];
  final List<Map<String, Object?>> retimed = <Map<String, Object?>>[];
  final List<DateTime> markedKeptOn = <DateTime>[];
  final List<DateTime> statsFor = <DateTime>[];

  /// Thrown by the next call to whichever method names it, then cleared.
  Object? failList;
  Object? failCreate;
  Object? failCancel;
  Object? failMarkKept;

  /// Replaces the table wholesale, as a refresh from the server would.
  void setRows(List<Plan> rows) => _rows = List.of(rows);

  void setStats(PlanStats stats) => _stats = stats;

  List<Plan> get rows => List.unmodifiable(_rows);

  @override
  Future<List<Plan>> list({required DateTime from, int limit = 300}) async {
    listedFrom.add(from);
    final failure = failList;
    if (failure != null) {
      failList = null;
      throw failure;
    }
    final visible = [
      for (final plan in _rows)
        if (plan.status != PlanStatus.cancelled && !plan.date.isBefore(from))
          plan,
    ]..sort((a, b) {
        final byDay = a.date.compareTo(b.date);
        return byDay != 0 ? byDay : a.sortMinutes.compareTo(b.sortMinutes);
      });

    return visible.take(limit).toList();
  }

  @override
  Future<int> create({
    required int restaurantId,
    required DateTime date,
    String? time,
    String? timeLabel,
    bool withFriends = false,
  }) async {
    created.add(<String, Object?>{
      'restaurantId': restaurantId,
      'date': formatPlanDate(date),
      'time': time,
      'timeLabel': timeLabel,
      'withFriends': withFriends,
    });
    final failure = failCreate;
    if (failure != null) {
      failCreate = null;
      throw failure;
    }

    final parts = time?.split(':') ?? const <String>[];
    final hour = parts.isEmpty ? null : int.tryParse(parts.first);
    final minute = parts.length < 2 ? null : int.tryParse(parts[1]);

    // The unique index: a second lock-in on the same day moves the plan that
    // is already there rather than adding a second row.
    final existing = _rows.indexWhere(
      (plan) =>
          plan.restaurantId == restaurantId &&
          plan.date.year == date.year &&
          plan.date.month == date.month &&
          plan.date.day == date.day,
    );
    if (existing >= 0) {
      final held = _rows[existing];
      _rows[existing] = testPlan(
        held.id,
        restaurantId: restaurantId,
        date: date,
        hour: hour,
        minute: minute,
        timeLabel: timeLabel,
        withFriends: withFriends,
        name: held.restaurantName,
        coverUrl: held.coverUrl,
        tag: held.tag,
        neighbourhood: held.neighbourhood,
        latitude: held.latitude,
        longitude: held.longitude,
        // Same row, new time: the guests stay on it.
        members: held.members,
      );
      return held.id;
    }

    final id = _nextId++;
    _rows.add(
      testPlan(
        id,
        restaurantId: restaurantId,
        date: date,
        hour: hour,
        minute: minute,
        timeLabel: timeLabel,
        withFriends: withFriends,
      ),
    );
    return id;
  }

  @override
  Future<void> cancel(int planId) async {
    cancelled.add(planId);
    final failure = failCancel;
    if (failure != null) {
      failCancel = null;
      throw failure;
    }
    _rows = [
      for (final plan in _rows)
        if (plan.id != planId) plan,
    ];
  }

  @override
  Future<void> setTime(int planId, {String? time, String? timeLabel}) async {
    retimed.add(<String, Object?>{
      'planId': planId,
      'time': time,
      'timeLabel': timeLabel,
    });
    // The controller re-reads after this, so the row has to have moved — a
    // fake that only logged the call would let a screen pass a test it fails
    // in the app, still showing the old time.
    final parts = time?.split(':');
    for (var i = 0; i < _rows.length; i++) {
      if (_rows[i].id != planId) {
        continue;
      }
      _rows[i] = _moved(_rows[i], parts, timeLabel);
    }
  }

  @override
  Future<int> markKept(DateTime today) async {
    markedKeptOn.add(today);
    final failure = failMarkKept;
    if (failure != null) {
      failMarkKept = null;
      throw failure;
    }
    var flipped = 0;
    final next = <Plan>[];
    for (final plan in _rows) {
      if (plan.status == PlanStatus.planned && plan.date.isBefore(today)) {
        flipped += 1;
        next.add(
          testPlan(
            plan.id,
            restaurantId: plan.restaurantId,
            date: plan.date,
            hour: plan.hour,
            minute: plan.minute,
            timeLabel: plan.timeLabel,
            withFriends: plan.withFriends,
            status: PlanStatus.kept,
            name: plan.restaurantName,
            coverUrl: plan.coverUrl,
            tag: plan.tag,
            neighbourhood: plan.neighbourhood,
            latitude: plan.latitude,
            longitude: plan.longitude,
            // Flipping a status must not empty the guest list. The database
            // updates one column; a fake that rebuilt the row and dropped its
            // members would make every past dinner look like it was eaten
            // alone, which is exactly what "Ate with recently" reads.
            members: plan.members,
          ),
        );
      } else {
        next.add(plan);
      }
    }
    _rows = next;
    return flipped;
  }

  @override
  Future<PlanStats> stats(DateTime today) async {
    statsFor.add(today);
    return _stats;
  }
}

/// [Plan] has no `copyWith` — nothing in the app needs one, and one existing
/// only for a fake is a production API paying rent for a test. This is the
/// three fields `setTime` moves, over the rest of the row unchanged.
Plan _moved(Plan plan, List<String>? parts, String? timeLabel) {
  return Plan(
    id: plan.id,
    restaurantId: plan.restaurantId,
    date: plan.date,
    hour: parts == null ? null : int.tryParse(parts[0]),
    minute: parts == null || parts.length < 2 ? null : int.tryParse(parts[1]),
    timeLabel: timeLabel,
    withFriends: plan.withFriends,
    status: plan.status,
    restaurantName: plan.restaurantName,
    coverUrl: plan.coverUrl,
    tag: plan.tag,
    neighbourhood: plan.neighbourhood,
    latitude: plan.latitude,
    longitude: plan.longitude,
    members: plan.members,
  );
}
