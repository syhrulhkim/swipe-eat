import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../restaurants/state/likes_controller.dart'
    show LikesAuthEvents, LikesController;
import '../data/plans_repository.dart';
import '../domain/plan_labels.dart';
import '../models/plan.dart';

/// Every screen's answer to "has this place got a day yet?".
///
/// One shared instance, because four surfaces ask it — the Calendar tab, the
/// Bites chips, the Bites tiles and the wishlist rows — and none of them can
/// see the others. A per-screen controller would mean four loads and four
/// chances to disagree.
///
/// The clock arrives through the constructor. "Today", "Tonight" and "Fri 4"
/// are all statements about now, and a widget that read `DateTime.now` itself
/// would be a widget no test could pin down.
class PlansController extends ChangeNotifier {
  PlansController({
    PlansRepository? repository,
    DateTime Function()? clock,
    bool followAuthChanges = true,
    LikesAuthEvents authEvents = const LikesAuthEvents(),
    LikesController? likes,
  })  : _repository = repository ?? PlansRepository(),
        _likes = likes,
        _clock = clock ?? DateTime.now,
        _followAuthChanges = followAuthChanges,
        _authEvents = authEvents;

  /// The shared instance the app wires up. Swappable for the same reason
  /// `LikesController.instance` is: a widget test needs its own.
  static PlansController instance = PlansController();

  /// Swaps [instance] for a test's own. There is no restore — every test that
  /// depends on plans installs its own.
  @visibleForTesting
  static void debugSetInstance(PlansController controller) {
    instance = controller;
  }

  final PlansRepository _repository;
  final DateTime Function() _clock;
  final LikesController? _likes;
  final bool _followAuthChanges;
  final LikesAuthEvents _authEvents;
  StreamSubscription<AuthState>? _authSubscription;
  String? _accountId;

  List<Plan> _plans = const [];
  PlanStats _stats = const PlanStats();
  bool _loaded = false;
  bool _loading = false;
  String? _error;
  Future<void>? _pending;

  /// Bumped by [reset] so an in-flight load cannot publish one account's
  /// evenings into the next account's session.
  int _generation = 0;

  /// Today, as the phone reckons it. Public because the calendar draws around
  /// it and the page must not consult a second clock.
  DateTime get now => _clock();

  List<Plan> get plans => List.unmodifiable(_plans);
  bool get isLoaded => _loaded;
  bool get loading => _loading;
  String? get error => _error;
  PlanStats get stats => _stats;

  bool get isEmpty => _loaded && _plans.isEmpty;

  /// What the Bites tab's "Planned" / "Not planned yet" chips filter on.
  ///
  /// Upcoming plans only. A dinner that already happened is a visit, not a
  /// plan, and a tile that still said "Planned" a week later would be lying.
  Set<int> get plannedRestaurantIds =>
      Set.unmodifiable(upcoming.map((plan) => plan.restaurantId));

  /// The badge a tile or a wishlist row shows: "Today", "Tonight", "Fri 4", or
  /// "Sat 12 Sep" once the day leaves this month. Null when the place has no
  /// plan.
  ///
  /// The *soonest* plan wins when a place has more than one, because the badge
  /// answers "when am I next going", not "how many times have I booked this".
  String? plannedLabelFor(int restaurantId) {
    Plan? soonest;
    for (final plan in upcoming) {
      if (plan.restaurantId != restaurantId) {
        continue;
      }
      if (soonest == null || _isBefore(plan, soonest)) {
        soonest = plan;
      }
    }
    return soonest == null ? null : plannedLabel(soonest, now);
  }

  /// Every label at once — what `LikesTabView` takes, so the grid does not run
  /// a scan of the plan list per tile.
  Map<int, String> get plannedLabels {
    final labels = <int, String>{};
    final soonest = <int, Plan>{};
    for (final plan in upcoming) {
      final held = soonest[plan.restaurantId];
      if (held == null || _isBefore(plan, held)) {
        soonest[plan.restaurantId] = plan;
      }
    }
    final at = now;
    soonest.forEach((restaurantId, plan) {
      labels[restaurantId] = plannedLabel(plan, at);
    });
    return labels;
  }

  /// The plans on one day, earliest first with "Late" last.
  List<Plan> plansOn(DateTime date) {
    final onDay = [
      for (final plan in _plans)
        if (isSameDay(plan.date, date)) plan,
    ]..sort((a, b) => a.sortMinutes.compareTo(b.sortMinutes));

    return onDay;
  }

  /// Today and everything after it, in the order the sections are listed.
  List<Plan> get upcoming {
    final today = _startOfToday();
    final rows = [
      for (final plan in _plans)
        if (!plan.date.isBefore(today)) plan,
    ]..sort((a, b) {
        final byDay = a.date.compareTo(b.date);
        return byDay != 0 ? byDay : a.sortMinutes.compareTo(b.sortMinutes);
      });

    return rows;
  }

  /// The days in [month] that carry at least one plan.
  Set<int> plannedDaysIn(DateTime month) {
    return {
      for (final plan in _plans)
        if (isSameMonth(plan.date, month)) plan.date.day,
    };
  }

  /// Loads once; concurrent callers share the request. A failed load clears
  /// its handle so the next call retries rather than caching the failure.
  Future<void> ensureLoaded() {
    _ensureAuthSubscription();
    if (_loaded) {
      return Future.value();
    }
    final pending = _pending;
    if (pending != null) {
      return pending;
    }
    late final Future<void> load;
    load = refresh().whenComplete(() {
      // Identity check, not a blind null: reset() drops the handle and a newer
      // load may own it by the time this stale future settles.
      if (identical(_pending, load)) {
        _pending = null;
      }
    });
    _pending = load;
    return load;
  }

  /// Reads the calendar, and flips yesterday's plans to kept on the way in
  /// (D108). The flip runs first so the list that comes back is already
  /// truthful about what is still ahead.
  Future<void> refresh() async {
    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();

    final today = _startOfToday();

    try {
      // A failed flip is not a failed load: the calendar is still readable and
      // the worst case is a stale status the next launch fixes.
      try {
        await _repository.markKept(today);
      } on Object catch (error) {
        debugPrint('Marking past plans kept failed: $error');
      }

      final rows = await _repository.list(from: firstOfMonth(today));
      final stats = await _repository.stats(today);
      if (generation != _generation) {
        return;
      }
      _plans = rows;
      _stats = stats;
      _loaded = true;
      _publishToLikes();
    } on Object catch (error) {
      debugPrint('Plans load failed: $error');
      if (generation != _generation) {
        return;
      }
      _error = 'Could not load your plans.';
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// "Lock it in". Returns the new plan's id, and leaves the list refreshed —
  /// the RPC hands back a bare row with no restaurant joined onto it, which is
  /// not enough to draw a calendar line with.
  Future<int> create({
    required int restaurantId,
    required DateTime date,
    String? time,
    String? timeLabel,
    bool withFriends = false,
  }) async {
    final id = await _repository.create(
      restaurantId: restaurantId,
      date: date,
      time: time,
      timeLabel: timeLabel,
      withFriends: withFriends,
    );
    await refresh();
    return id;
  }

  /// Drops a plan off the calendar. Optimistic: the row leaves the list before
  /// the server is asked, because a swipe-away that waits for a round trip
  /// reads as a tap that did not land. A failed cancel puts it back.
  Future<void> cancel(int planId) async {
    final before = _plans;
    _plans = [
      for (final plan in _plans)
        if (plan.id != planId) plan,
    ];
    _publishToLikes();
    notifyListeners();

    try {
      await _repository.cancel(planId);
    } on Object catch (error) {
      debugPrint('Cancelling a plan failed: $error');
      _plans = before;
      _publishToLikes();
      notifyListeners();
      rethrow;
    }
  }

  /// Moves a plan to another slot. Same day, different hour.
  Future<void> setTime(int planId, {String? time, String? timeLabel}) async {
    await _repository.setTime(planId, time: time, timeLabel: timeLabel);
    await refresh();
  }

  /// Empties the cache on sign-out, so the next account does not open the
  /// calendar on somebody else's week.
  void reset() {
    _generation += 1;
    _plans = const [];
    _stats = const PlanStats();
    _loaded = false;
    _loading = false;
    _error = null;
    _pending = null;
    _publishToLikes();
    notifyListeners();
  }

  /// Hands the ids to [LikesController], which is what the Bites grid's
  /// chips and the planned pill on a tile actually read. Resolved lazily, and
  /// per call, because `LikesController.instance` is swapped by tests.
  void _publishToLikes() {
    final likes = _likes ?? LikesController.instance;
    likes.setPlannedRestaurantIds(plannedRestaurantIds);
  }

  /// Follows the account the same way [LikesController] does, and for the same
  /// reason: this is an app-lifetime singleton holding one person's evenings,
  /// so a second sign-in on the same device must not open on the first one's
  /// week. Kept off `Supabase.instance` in tests by [LikesAuthEvents], which
  /// returns a null stream when the singleton was never initialised.
  void _ensureAuthSubscription() {
    if (!_followAuthChanges || _authSubscription != null) {
      return;
    }
    final changes = _authEvents.changes;
    if (changes == null) {
      return;
    }
    _accountId = _authEvents.currentUserId;
    _authSubscription = changes.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedOut:
          _accountId = null;
          reset();
        case AuthChangeEvent.signedIn:
          // The stream replays its latest event to each new listener, so the
          // first `signedIn` seen here is usually the session already being
          // loaded for. Only an actual change of account may drop the cache.
          final incoming = state.session?.user.id;
          if (incoming != _accountId) {
            _accountId = incoming;
            reset();
          }
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  DateTime _startOfToday() {
    final at = now;
    return DateTime(at.year, at.month, at.day);
  }

  bool _isBefore(Plan a, Plan b) {
    final byDay = a.date.compareTo(b.date);
    return byDay != 0 ? byDay < 0 : a.sortMinutes < b.sortMinutes;
  }
}
