import 'package:flutter/foundation.dart';

import '../models/restaurant.dart';

/// The one way another screen can put cards in the deck.
///
/// The Nearby map's "Swipe all 6" has to do two things at once — replace the
/// deck's cards and bring the deck forward — and the two live in different
/// widgets that never see each other: [DeckController] is built inside
/// `SwipeDeck`, and the tab index lives in the dashboard shell. Rather than
/// thread one through the other, both listen here: the deck deals the list,
/// the dashboard switches to it.
///
/// Nothing is consumed on read. A hand-off is a fact ("these are the cards
/// now"), not a queue, so a listener that rebuilds twice does the same thing
/// twice and lands in the same place.
class DeckHandoff extends ChangeNotifier {
  DeckHandoff();

  /// The shared instance the app wires up. Swappable for the same reason
  /// [LikesController.instance] is: a widget test needs its own.
  static DeckHandoff instance = DeckHandoff();

  /// Swaps [instance] for a test's own. There is no restore — every test that
  /// depends on the hand-off installs its own.
  @visibleForTesting
  static void debugSetInstance(DeckHandoff handoff) {
    instance = handoff;
  }

  List<Restaurant> _restaurants = const [];

  /// The cards the deck should be showing. Empty until something hands over.
  List<Restaurant> get restaurants => _restaurants;

  String? _label;

  /// Where the cards came from, e.g. "Nearby · 6 places". Null before the
  /// first hand-off.
  String? get label => _label;

  /// Bumped on every hand-off, so a listener can tell "the same six places,
  /// handed over again" from "nothing has happened yet" — tapping Swipe all
  /// twice must re-deal, and comparing lists would say nothing changed.
  int _revision = 0;
  int get revision => _revision;

  /// Hands [restaurants] to the deck and asks whoever owns the tabs to show
  /// it. Ignores an empty list: a deck with nothing in it is not a hand-off,
  /// it is a bug arriving on the wrong screen.
  void handOff(List<Restaurant> restaurants, {String? label}) {
    if (restaurants.isEmpty) {
      return;
    }

    _restaurants = List<Restaurant>.unmodifiable(restaurants);
    _label = label;
    _revision += 1;
    notifyListeners();
  }
}
