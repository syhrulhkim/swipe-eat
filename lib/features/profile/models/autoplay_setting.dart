/// When the deck's clips play on their own (D146).
///
/// A device answer, not a taste one: it is about somebody's data plan, so it
/// lives in `SharedPreferences` beside the deck cache rather than on
/// `profiles` with halal and spice. Two phones signed into one account can
/// reasonably disagree about this.
enum AutoplaySetting {
  /// The default, and deliberately so: this is a video app, and changing what
  /// it does on day one would be changing the product rather than offering a
  /// setting.
  always('always', 'Always'),

  /// Plays on Wi-Fi, shows a still with a play button on mobile data.
  wifiOnly('wifi', 'On Wi-Fi only'),

  /// Never plays by itself. A tap still plays the card in front.
  never('never', 'Never');

  const AutoplaySetting(this.slug, this.label);

  /// What is written to storage. Stable across renames of the enum value.
  final String slug;

  /// What the You tab shows.
  final String label;

  static AutoplaySetting fromSlug(String? slug) {
    for (final option in values) {
      if (option.slug == slug) {
        return option;
      }
    }
    return always;
  }

  /// Whether a clip may start on its own right now.
  bool playsOn({required bool wifi}) => switch (this) {
        AutoplaySetting.always => true,
        AutoplaySetting.wifiOnly => wifi,
        AutoplaySetting.never => false,
      };
}
