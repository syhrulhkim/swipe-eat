import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Opens the platform maps app with driving directions to [latitude] /
/// [longitude].
///
/// The coordinates are the destination of record — [label] only names the pin,
/// so a restaurant whose name geocodes badly still routes to the right spot.
///
/// Returns false when no maps handler took the URL; callers show their own
/// message. A restaurant seeded without a fix sits at 0,0 (Null Island), which
/// is never a real destination, so that is refused up front.
Future<bool> openDirections({
  required double latitude,
  required double longitude,
  String? label,
}) async {
  if (!hasMapFix(latitude, longitude)) {
    return false;
  }

  final candidates = directionsUris(
    latitude: latitude,
    longitude: longitude,
    label: label,
    appleMaps: Platform.isIOS,
  );

  for (final uri in candidates) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // A platform that cannot handle the scheme throws rather than returning
      // false, so fall through to the next candidate.
    }
  }

  return false;
}

/// True when the coordinates name a real place.
///
/// Part of the catalog is seeded without a fix and lands on 0,0, so UI that
/// offers directions asks this first rather than showing a button that can
/// only fail.
bool hasMapFix(double latitude, double longitude) {
  return latitude != 0 || longitude != 0;
}

/// The URLs [openDirections] tries, best handler first, ending in a web map
/// that any device with a browser can open.
///
/// Split out from [openDirections] so the URL shapes are testable without a
/// platform channel.
List<Uri> directionsUris({
  required double latitude,
  required double longitude,
  String? label,
  required bool appleMaps,
}) {
  final destination = '$latitude,$longitude';
  final name = label?.trim();
  final encodedName =
      name == null || name.isEmpty ? null : Uri.encodeComponent(name);

  return <Uri>[
    if (appleMaps)
      Uri.parse(
        'https://maps.apple.com/?daddr=$destination&dirflg=d'
        '${encodedName == null ? '' : '&q=$encodedName'}',
      )
    else
      // geo: only drops a pin; google.navigation: is the Android scheme that
      // actually starts routing, and any navigation app registering it is
      // welcome to answer.
      Uri.parse('google.navigation:q=$destination&mode=d'),
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination',
    ),
  ];
}
