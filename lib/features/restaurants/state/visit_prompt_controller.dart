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

  /// The trip to ask about now, or null when there is none ripe.
  Future<PendingVisit?> next() async {
    final userId = _authEvents.currentUserId;
    if (userId == null) {
      return null;
    }
    return _cache.nextPrompt(userId);
  }

  /// The user says they went: stamp `visited_at` and retire the question.
  ///
  /// The cache is cleared only after the write lands, so a failed call leaves
  /// the prompt to be asked again rather than losing the visit silently.
  Future<void> confirm(PendingVisit visit) async {
    await _swipes.markVisited(restaurantId: visit.restaurantId);
    await _cache.clear(
      userId: visit.userId,
      restaurantId: visit.restaurantId,
    );
  }

  /// The user says they did not go. Nothing to record — the trip simply stops
  /// being an open question.
  Future<void> dismiss(PendingVisit visit) {
    return _cache.clear(
      userId: visit.userId,
      restaurantId: visit.restaurantId,
    );
  }
}
