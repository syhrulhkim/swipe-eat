/// Rating 0 means "no rating yet" (e.g. scraped restaurants have none),
/// rendered as a dash instead of a misleading "0.0".
String ratingLabel(double rating) {
  return rating > 0 ? rating.toStringAsFixed(1) : '–';
}
