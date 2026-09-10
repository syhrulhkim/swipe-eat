import 'package:flutter/foundation.dart';

/// The one way a screen can ask the dashboard to show a different tab.
///
/// It used to sit beside `DeckHandoff`, which did the same job for the Nearby
/// map's "Swipe all" but could only ever mean tab 0 and insisted on carrying a
/// list of restaurants with it. The map is gone and so is the hand-off; this
/// is now the only route. The Calendar tab needs it in both directions: its
/// "New plan" button sends the user to the deck, and "Lock it in" sends them
/// back to the calendar from a route pushed over the dashboard.
///
/// Nothing is consumed on read, so a listener that rebuilds twice asks for the
/// same tab twice and lands in the same place. The counter is what separates
/// "show tab 3 again" from "nothing has been asked for yet" — asking for the
/// tab you are already on has to be a no-op, but asking twice in a row after
/// navigating away must still work.
class DashboardTabRequest extends ChangeNotifier {
  DashboardTabRequest();

  /// The shared instance the app wires up. Swappable so a widget test can
  /// watch what a screen asked for.
  static DashboardTabRequest instance = DashboardTabRequest();

  /// Swaps [instance] for a test's own. There is no restore — every test that
  /// depends on tab switching installs its own.
  @visibleForTesting
  static void debugSetInstance(DashboardTabRequest request) {
    instance = request;
  }

  int _index = 0;

  /// The tab last asked for. Meaningless until [revision] moves off zero.
  int get index => _index;

  int _revision = 0;
  int get revision => _revision;

  void show(int index) {
    _index = index;
    _revision += 1;
    notifyListeners();
  }
}
