import '../../restaurants/domain/opening_hours.dart';

/// The radii the stepper walks. Coarser as they get bigger, because the
/// difference between 12 and 13 km is not a decision anyone makes — the
/// difference between 0.5 and 1 km is.
const List<double> kNearbyRadiusSteps = [0.5, 1, 2, 3, 5, 8, 12, 20];

/// What the map opens at when the profile has no `search_radius_km`.
const double kNearbyDefaultRadiusKm = 3;

/// Snaps an arbitrary radius (the profile stores whole km; the steps do not)
/// to the nearest step, so the stepper always starts on a value it can leave.
///
/// A tie goes to the smaller step — 10 km lands on 8, not 12. The radius is a
/// promise about how far the user is willing to go, and rounding it up would
/// put places outside that promise on the map.
double nearestNearbyRadiusStep(double km) {
  var best = kNearbyRadiusSteps.first;
  for (final step in kNearbyRadiusSteps) {
    if ((step - km).abs() < (best - km).abs()) {
      best = step;
    }
  }
  return best;
}

/// A distance split into the number and its unit, because the radius stepper
/// sets the two at different sizes — display 30/w800 against 14/w600 — and a
/// single pre-joined string cannot be styled apart.
class NearbyDistance {
  const NearbyDistance(this.value, this.unit);

  final String value;
  final String unit;

  /// The badge form: one string, "450 m" or "1.2 km".
  String get label => '$value $unit';
}

/// How far, phrased the way the map's distance badge and radius stepper both
/// want it: metres under a kilometre, one decimal above.
///
/// Metres are rounded to the nearest 10 — a pin that claims 447 m is claiming
/// an accuracy no phone fix has.
NearbyDistance formatNearbyDistance(double km) {
  if (km.isNaN || km < 0) {
    return const NearbyDistance('0', 'm');
  }

  if (km < 1) {
    final metres = (km * 1000 / 10).round() * 10;
    // 0.9996 km rounds to 1000 m, which should read as a kilometre.
    if (metres >= 1000) {
      return const NearbyDistance('1.0', 'km');
    }
    return NearbyDistance('$metres', 'm');
  }

  return NearbyDistance(km.toStringAsFixed(1), 'km');
}

/// Which colour the open line takes. Fresh is the app's one non-orange accent
/// and means exactly "open right now"; everything else is muted cream.
enum NearbyOpenTone { fresh, muted }

/// The line under a pin's name: whether the place is open, and what happens
/// next.
class NearbyOpenLine {
  const NearbyOpenLine(this.text, this.tone);

  final String text;
  final NearbyOpenTone tone;
}

/// Minutes of warning before closing time that turn "Open" into "Closes 10 pm".
const int kNearbyClosingSoonMinutes = 60;

/// The pin's open line, or null when the caption never said when the place
/// opens — a pin that guesses is worse than a pin that stays quiet.
///
/// Four cases, in the order the design states them:
///   * open, all day        → "Open · 24 h", fresh
///   * open, closing soon   → "Closes 10 pm", muted
///   * open                 → "Open", fresh
///   * closed               → "Opens 5:30 pm", or "Closed today", muted
NearbyOpenLine? nearbyOpenLine(OpeningHours hours, DateTime now) {
  final open = hours.isOpenAt(now);
  if (open == null) {
    return null;
  }

  if (open) {
    if (hours.isAllDay) {
      return const NearbyOpenLine('Open · 24 h', NearbyOpenTone.fresh);
    }

    final closes = hours.closesAtMinutes!;
    final minute = now.hour * 60 + now.minute;
    // An overnight span closes after midnight, so the remaining minutes wrap.
    final remaining = closes >= minute ? closes - minute : closes + 1440 - minute;
    if (remaining <= kNearbyClosingSoonMinutes) {
      return NearbyOpenLine(
        'Closes ${OpeningHours.formatClock(closes)}',
        NearbyOpenTone.muted,
      );
    }

    return const NearbyOpenLine('Open', NearbyOpenTone.fresh);
  }

  final opens = hours.opensAtMinutes!;
  final minute = now.hour * 60 + now.minute;
  final opensLaterToday =
      !hours.closedWeekdays.contains(now.weekday) && minute < opens;
  if (opensLaterToday) {
    return NearbyOpenLine(
      'Opens ${OpeningHours.formatClock(opens)}',
      NearbyOpenTone.muted,
    );
  }

  return const NearbyOpenLine('Closed today', NearbyOpenTone.muted);
}
