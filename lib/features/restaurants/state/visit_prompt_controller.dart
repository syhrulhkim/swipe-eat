import 'package:flutter/foundation.dart';

import '../data/swipe_repository.dart';
import '../data/visit_prompt_cache.dart';
import 'likes_controller.dart';

/// Ties the directions button to the Visited list: it remembers who was sent
/// where, and hands the dashboard the one trip worth asking about on the next
/// visit to the app.
///
/// No [ChangeNotifier] — nothing watches this. The dashboard pulls when it
/// becomes visible, and everything it writes is either device-local or already
/// broadcast by the backend.
class VisitPromptController {
  VisitPromptController({
    VisitPromptCache cache = const VisitPromptCache(),
    SwipeRepository? swipes,
    LikesAuthEvents authEvents = const LikesAuthEvents(),
  })  : _cache = cache,
        _injectedSwipes = swipes,
        _authEvents = authEvents;

  static VisitPromptController instance = VisitPromptController();

  final VisitPromptCache _cache;
  final SwipeRepository? _injectedSwipes;
  final LikesAuthEvents _authEvents;

  /// Lazy for the same reason as [LikesController]'s: construction must not
  /// touch an uninitialised `Supabase.instance`.
  late final SwipeRepository _swipes = _injectedSwipes ?? SwipeRepository();

  /// Called when the maps app actually opened. A signed-out user is skipped:
  /// `mark_visited` needs an account, so there would be no way to answer.
  Future<void> recordDirections({
    required int restaurantId,
    required String name,
  }) async {
    final userId = _authEvents.currentUserId;
    if (userId == null) {
      return;
    }

    await _cache.recordDirections(
      userId: userId,
      restaurantId: restaurantId,
      name: name,
    );
  }

  /// The plan-shaped question, looked up once per run. Null once it has been
  /// answered, or when the backend had none to give.
  PendingVisit? _planPrompt;
  bool _planPromptLoaded = false;

  /// The trip to ask about now, or null when there is none ripe.
  ///
  /// The device's own trips come first — they are free to read and the
  /// freshest thing the user can answer for. A past plan (D147) is the
  /// fallback, fetched **once per app run**: `_maybeAskAboutVisit` runs on
  /// every resume, and a plan does not become askable between two of them.
  Future<PendingVisit?> next() async {
    final userId = _authEvents.currentUserId;
    if (userId == null) {
      return null;
    }

    final fromDevice = await _cache.nextPrompt(userId);
    if (fromDevice != null) {
      return fromDevice;
    }

    if (!_planPromptLoaded) {
      _planPromptLoaded = true;
      try {
        _planPrompt = await _swipes.nextVisitPrompt(
          userId: userId,
          today: DateTime.now(),
        );
      } on Object catch (error) {
        // No question is a fine outcome; an error here must not reach a launch.
        debugPrint('Visit prompt lookup failed: $error');
      }
    }

    return _planPrompt?.userId == userId ? _planPrompt : null;
  }

  /// The user says they went: stamp `visited_at`, keep the stars and the line
  /// if they left any (D147), and retire the question.
  ///
  /// The cache is cleared only after the write lands, so a failed call leaves
  /// the prompt to be asked again rather than losing the visit silently.
  Future<void> confirm(PendingVisit visit, {int? rating, String? note}) async {
    await _swipes.recordVisitAnswer(
      restaurantId: visit.restaurantId,
      went: true,
      rating: rating,
      body: note,
      planId: visit.planId,
    );
    await _retire(visit);
  }

  /// The user says they did not go. For a walk-in there is nothing to record —
  /// the trip simply stops being an open question. For a plan there is: D108
  /// flipped it to `kept` on an assumption, and this is the first evidence.
  Future<void> dismiss(PendingVisit visit) async {
    if (visit.planId != null) {
      await _swipes.recordVisitAnswer(
        restaurantId: visit.restaurantId,
        went: false,
        planId: visit.planId,
      );
    }
    await _retire(visit);
  }

  Future<void> _retire(PendingVisit visit) async {
    if (identical(visit, _planPrompt)) {
      _planPrompt = null;
    }
    await _cache.clear(
      userId: visit.userId,
      restaurantId: visit.restaurantId,
    );
  }
}
