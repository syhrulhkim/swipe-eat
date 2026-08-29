/// The radius stops offered by the onboarding and Settings sliders,
/// coarsening as they grow — the difference between 1 km and 2 km matters to
/// a walker; the difference between 100 km and 110 km does not. The trailing
/// null is "No limit", which is the default: the catalog is thin enough that
/// a tight radius can empty the deck, and a hard filter with nothing behind
/// it looks like a broken app.
const List<int?> kRadiusStops = [1, 2, 5, 10, 15, 20, 30, 50, 100, null];

String radiusLabel(int? km) => km == null ? 'No limit' : '$km km';
