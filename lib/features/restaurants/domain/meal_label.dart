/// Which meal the hour is closest to — the second line of the deck's header
/// ("within 3 km · dinner"). Malaysian mealtimes: supper runs late.
String mealLabel(DateTime now) {
  final hour = now.hour;
  if (hour < 5) {
    return 'supper';
  }
  if (hour < 11) {
    return 'breakfast';
  }
  if (hour < 15) {
    return 'lunch';
  }
  if (hour < 18) {
    return 'tea';
  }
  if (hour < 22) {
    return 'dinner';
  }
  return 'supper';
}
