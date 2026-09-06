import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../restaurants/state/likes_controller.dart' show LikesAuthEvents;
import '../data/friends_repository.dart';
import '../models/friend.dart';

/// Who the user knows, held once for the whole app.
///
/// One shared instance, because five surfaces ask the same question and none
/// of them can see the others: the You tab's count, the invite list, the
/// wishlist's "From Aiman", the calendar's avatar stacks and the friends page
/// itself. Five controllers would mean five `get_friends` calls and five
/// chances to disagree about how many friends there are.
///
/// The cache is a **map by id**, not a list, because most of what is asked of
/// it is "what is this id's name" — the wishlist has a `from_user_id` and
/// nothing else, and a plan card has a list of them.
class FriendsController extends ChangeNotifier {
  FriendsController({
    FriendsRepository? repository,
    bool followAuthChanges = true,
    LikesAuthEvents authEvents = const LikesAuthEvents(),
  })  : _repository = repository ?? FriendsRepository(),
        _followAuthChanges = followAuthChanges,
        _authEvents = authEvents;

  /// The shared instance the app wires up. Swappable for the same reason
  /// `LikesController.instance` is: a widget test needs its own.
  static FriendsController instance = FriendsController();

  /// Swaps [instance] for a test's own. There is no restore — every test that
  /// depends on friends installs its own.
  @visibleForTesting
  static void debugSetInstance(FriendsController controller) {
    instance = controller;
  }

  final FriendsRepository _repository;
  final bool _followAuthChanges;
  final LikesAuthEvents _authEvents;
  StreamSubscription<AuthState>? _authSubscription;
  String? _accountId;

  Map<String, FriendProfile> _byId = const {};
  Map<int, List<PlanPerson>> _planPeople = const {};
  List<FriendProfile> _friends = const [];
  List<FriendRequest> _requests = const [];
  bool _loaded = false;
  bool _loading = false;
  String? _error;
  Future<void>? _pending;

  /// Bumped by [reset] so an in-flight load cannot publish one account's
  /// address book into the next account's session.
  int _generation = 0;

  List<FriendProfile> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get requests => List.unmodifiable(_requests);

  /// Only the ones I can answer. An outgoing request is on the page but it is
  /// not a thing to do.
  List<FriendRequest> get incomingRequests =>
      [for (final r in _requests) if (r.incoming) r];

  bool get isLoaded => _loaded;
  bool get loading => _loading;
  String? get error => _error;
  int get count => _friends.length;
  bool get isEmpty => _loaded && _friends.isEmpty;

  /// The name behind an id, or null when that person is not a friend.
  ///
  /// Null rather than a placeholder: the wishlist row already knows how to say
  /// "From a friend", and a controller that invented "Someone" would take that
  /// decision away from the widget that owns the sentence.
  FriendProfile? profileFor(String? userId) =>
      userId == null ? null : _byId[userId];

  String? nameFor(String? userId) => profileFor(userId)?.name;

  /// Everybody on a plan, faces and answers included, or an empty list when
  /// that plan has not been loaded yet.
  ///
  /// Separate from the friends cache on purpose: a plan's guests are not
  /// necessarily *your* friends — somebody the owner invited can be a stranger
  /// to you — so their names cannot be looked up in [profileFor]. `Plan.members`
  /// carries ids and statuses and no names at all, which is what this fills in.
  List<PlanPerson> peopleFor(int planId) =>
      List.unmodifiable(_planPeople[planId] ?? const <PlanPerson>[]);

  /// Loads the rosters for a set of plans in one call.
  ///
  /// The calendar draws a month at a time and would otherwise ask once per
  /// card. Plans already held are re-read rather than skipped: an answer can
  /// arrive between two openings of the same screen, and a stale "2 confirmed"
  /// is the kind of wrong that looks right.
  ///
  /// Generation-guarded like [refresh], so a month loaded under one account
  /// cannot land in the next one's session. A failure leaves what was already
  /// cached alone — the plan cards keep their old line rather than emptying.
  Future<void> loadPlanPeople(Iterable<int> planIds) async {
    final ids = planIds.toSet();
    if (ids.isEmpty) {
      return;
    }
    final generation = _generation;
    try {
      final people = await _repository.planPeople(ids);
      if (generation != _generation) {
        return;
      }
      final grouped = <int, List<PlanPerson>>{
        for (final id in ids) id: <PlanPerson>[],
      };
      for (final person in people) {
        (grouped[person.planId] ??= <PlanPerson>[]).add(person);
      }
      _planPeople = {..._planPeople, ...grouped};
      notifyListeners();
    } on Object catch (error) {
      debugPrint('Loading plan people failed: $error');
    }
  }

  /// Loads once; concurrent callers share the request. A failed load clears its
  /// handle so the next call retries rather than caching the failure.
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

  Future<void> refresh() async {
    final generation = _generation;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final friends = await _repository.friends();
      // A failed request list is not a failed load: the friends themselves are
      // the thing every other screen waits on, and a pending-request badge is
      // worth losing before a whole page is.
      var requests = const <FriendRequest>[];
      try {
        requests = await _repository.requests();
      } on Object catch (error) {
        debugPrint('Loading friend requests failed: $error');
      }

      if (generation != _generation) {
        return;
      }
      _publish(friends);
      _requests = requests;
      _loaded = true;
    } on Object catch (error) {
      debugPrint('Friends load failed: $error');
      if (generation != _generation) {
        return;
      }
      _error = 'Could not load your friends.';
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Answers a request, or drops a friendship. Refreshes rather than patching
  /// the list by hand: accepting moves a row from one list to the other, and
  /// two lists edited in place are two chances to disagree.
  Future<void> act(String userId, FriendAction action) async {
    await _repository.act(userId, action);
    await refresh();
  }

  /// What the onboarding step's "Add N friends" does. Returns how many landed.
  Future<int> sendRequests(Iterable<String> userIds) async {
    final sent = await _repository.sendRequests(userIds);
    if (sent > 0) {
      await refresh();
    }
    return sent;
  }

  /// Who among these numbers is already here. Straight through to the
  /// repository, which hashes them — the controller never holds a number.
  Future<List<FriendProfile>> matchContacts(Iterable<String> rawNumbers) =>
      _repository.matchContacts(rawNumbers);

  /// Empties the cache on sign-out, so the next account does not open the
  /// invite screen on somebody else's friends.
  void reset() {
    _generation += 1;
    _byId = const {};
    _friends = const [];
    _requests = const [];
    _planPeople = const {};
    _loaded = false;
    _loading = false;
    _error = null;
    _pending = null;
    notifyListeners();
  }

  void _publish(List<FriendProfile> friends) {
    _friends = friends;
    _byId = {for (final friend in friends) friend.id: friend};
  }

  /// Follows the account the same way `PlansController` does, and for the same
  /// reason: this is an app-lifetime singleton holding one person's address
  /// book, so a second sign-in on the same device must not open on the first
  /// one's friends.
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
}
