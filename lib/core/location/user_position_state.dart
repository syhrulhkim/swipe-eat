import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import 'user_location.dart';

/// Holds the device fix for a screen that shows distances.
///
/// [resolveUserPosition] is session-cached, so several screens mixing this in
/// share one permission prompt and one GPS fix; each simply rebuilds when its
/// own copy arrives.
mixin UserPositionState<T extends StatefulWidget> on State<T> {
  Position? userPosition;

  void loadUserPosition() {
    resolveUserPosition().then((position) {
      if (!mounted) {
        return;
      }

      setState(() {
        userPosition = position;
      });
    });
  }
}
