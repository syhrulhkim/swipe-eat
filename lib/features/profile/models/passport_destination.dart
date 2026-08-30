/// A city the passport picker can pin the deck to.
///
/// A curated list rather than a map or a geocoder: the catalog is Malaysian
/// (plus Singapore), so a handful of city centres covers every place the deck
/// could actually deal. The coordinates are the city centre — the search
/// radius does the rest.
class PassportDestination {
  const PassportDestination({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

const List<PassportDestination> kPassportDestinations = [
  PassportDestination(
    name: 'Johor Bahru',
    latitude: 1.4927,
    longitude: 103.7414,
  ),
  PassportDestination(
    name: 'Kuala Lumpur',
    latitude: 3.1390,
    longitude: 101.6869,
  ),
  PassportDestination(
    name: 'George Town, Penang',
    latitude: 5.4141,
    longitude: 100.3288,
  ),
  PassportDestination(
    name: 'Malacca',
    latitude: 2.1896,
    longitude: 102.2501,
  ),
  PassportDestination(
    name: 'Ipoh',
    latitude: 4.5975,
    longitude: 101.0901,
  ),
  PassportDestination(
    name: 'Kota Kinabalu',
    latitude: 5.9804,
    longitude: 116.0735,
  ),
  PassportDestination(
    name: 'Kuching',
    latitude: 1.5533,
    longitude: 110.3592,
  ),
  PassportDestination(
    name: 'Singapore',
    latitude: 1.3521,
    longitude: 103.8198,
  ),
];
