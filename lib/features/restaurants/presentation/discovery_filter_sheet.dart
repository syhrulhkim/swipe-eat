import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/radius_options.dart';
import '../../auth/state/auth_controller.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/models/taste_option.dart';

/// The minimum-rating steps the sheet offers. Null is "any rating".
const List<double?> kMinRatingOptions = [null, 3.0, 3.5, 4.0, 4.5];

/// Writes the sheet's state to the profile and reports whether it landed.
///
/// Matched by `DeckController.applyDiscoveryFilters` and
/// `NearbyController.applyDiscoveryFilters`: the sheet is opened from the deck
/// and from the map, and neither screen owns the other's controller. Taking
/// the write as a function is what lets one sheet serve both.
typedef DiscoveryFilterWriter = Future<bool> Function({
  required List<int> cuisineIds,
  required List<int> dietaryTagIds,
  double? minRating,
  int? searchRadiusKm,
});

/// Opens the discovery filter sheet. The sheet edits a local copy of the
/// profile's filter state and writes it in one shot on Apply — the same
/// full-overwrite contract as `set_discovery_filters`.
Future<void> showDiscoveryFilterSheet(
  BuildContext context, {
  required AuthController authController,
  required DiscoveryFilterWriter onApply,
  OnboardingRepository? catalog,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurfacePanel,
    // Material's own handle, so the grab affordance is also a real Dismiss
    // action for a screen reader rather than a decorative pill.
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
    ),
    builder: (sheetContext) => DiscoveryFilterSheet(
      authController: authController,
      onApply: onApply,
      catalog: catalog ?? OnboardingRepository(),
    ),
  );
}

/// Cuisine, dietary and minimum-rating limits on discovery — Tinder's
/// discovery settings, restated for restaurants. Shared by the deck and the
/// Nearby map, so a filter means the same thing on both.
class DiscoveryFilterSheet extends StatefulWidget {
  const DiscoveryFilterSheet({
    super.key,
    required this.authController,
    required this.onApply,
    required this.catalog,
  });

  final AuthController authController;
  final DiscoveryFilterWriter onApply;
  final OnboardingRepository catalog;

  @override
  State<DiscoveryFilterSheet> createState() => _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends State<DiscoveryFilterSheet> {
  TasteCatalog? _catalog;
  bool _loadFailed = false;
  bool _saving = false;

  late final Set<int> _cuisineIds = {
    ...widget.authController.user?.filterCuisineIds ?? const <int>[],
  };
  late final Set<int> _dietaryTagIds = {
    ...widget.authController.user?.filterDietaryTagIds ?? const <int>[],
  };
  late double? _minRating = widget.authController.user?.filterMinRating;

  /// How far the deck may look. It is not a `set_discovery_filters` field —
  /// it has its own RPC — but it is the same question the rest of this sheet
  /// asks ("what may reach me?"), so it is answered in the same place.
  late int? _radiusKm = widget.authController.user?.searchRadiusKm;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalog());
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadFailed = false;
    });

    try {
      final catalog = await widget.catalog.loadCatalog();
      if (!mounted) {
        return;
      }
      setState(() {
        _catalog = catalog;
      });
    } on Object catch (error) {
      debugPrint('Filter catalog load failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _loadFailed = true;
      });
    }
  }

  Future<void> _apply() async {
    setState(() {
      _saving = true;
    });

    final saved = await widget.onApply(
      cuisineIds: _cuisineIds.toList()..sort(),
      dietaryTagIds: _dietaryTagIds.toList()..sort(),
      minRating: _minRating,
      searchRadiusKm: _radiusKm,
    );
    if (!mounted) {
      return;
    }

    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    // The caller already raised its toast; the sheet keeps the edits so the
    // user can retry.
    setState(() {
      _saving = false;
    });
  }

  /// How many limits are on, counted the way `AppUser.activeFilterCount`
  /// counts them — by kind — so the Apply button and the header badge that
  /// follows it never disagree about the same selection.
  int get _activeCount =>
      (_cuisineIds.isEmpty ? 0 : 1) +
      (_dietaryTagIds.isEmpty ? 0 : 1) +
      (_minRating == null ? 0 : 1) +
      (_radiusKm == null ? 0 : 1);

  void _clearAll() {
    setState(() {
      _cuisineIds.clear();
      _dietaryTagIds.clear();
      _minRating = null;
      _radiusKm = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A sheet with no handle reads as a screen that arrived by
              // accident. This one is dragged away as often as it is applied.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Both sides give way: at twice the text size the title and
                  // the button do not fit a 320 pt phone side by side.
                  Flexible(
                    child: Text(
                      'Discovery',
                      style: appPanelTitleStyle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    // Nothing on means nothing to clear, and a live button
                    // that does nothing is a button the user stops trusting.
                    onPressed:
                        _saving || _activeCount == 0 ? null : _clearAll,
                    child: Text(
                      'Clear all',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: _activeCount == 0
                                ? kTextOnPhotoMuted
                                : kAccentEmber,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              Text(
                'Hard limits on discovery — only places that pass are shown.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kTextOnPhotoMuted,
                    ),
              ),
              const SizedBox(height: 12),
              if (catalog == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: _loadFailed
                        ? AppSecondaryButton(
                            label: 'Could not load options — retry',
                            onPressed: () => unawaited(_loadCatalog()),
                          )
                        : const AppLottie(motion: AppMotion.spinner, size: 56),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SheetSectionLabel(
                          label: 'Search radius',
                          trailing: radiusLabel(_radiusKm),
                        ),
                        _RadiusSlider(
                          km: _radiusKm,
                          onChanged: (km) => setState(() {
                            _radiusKm = km;
                          }),
                        ),
                        const _SliderAnchors(
                          start: '1 km',
                          end: 'Any distance',
                        ),
                        const SizedBox(height: 20),
                        _SheetSectionLabel(
                          label: 'Cuisines',
                          trailing: _chosenLabel(_cuisineIds.length),
                        ),
                        _OptionWrap(
                          options: catalog.cuisines,
                          isSelected: _cuisineIds.contains,
                          onToggle: (id) => setState(() {
                            if (!_cuisineIds.remove(id)) {
                              _cuisineIds.add(id);
                            }
                          }),
                        ),
                        const SizedBox(height: 20),
                        _SheetSectionLabel(
                          label: 'Dietary needs',
                          trailing: _chosenLabel(_dietaryTagIds.length),
                        ),
                        _OptionWrap(
                          options: catalog.dietaryTags,
                          isSelected: _dietaryTagIds.contains,
                          onToggle: (id) => setState(() {
                            if (!_dietaryTagIds.remove(id)) {
                              _dietaryTagIds.add(id);
                            }
                          }),
                        ),
                        const SizedBox(height: 20),
                        const _SheetSectionLabel(label: 'Minimum rating'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in kMinRatingOptions)
                              _FilterPill(
                                label: option == null
                                    ? 'Any'
                                    : '★ ${option.toStringAsFixed(1)}+',
                                selected: _minRating == option,
                                onTap: () => setState(() {
                                  _minRating = option;
                                }),
                              ),
                          ],
                        ),
                        if (_minRating != null) ...[
                          const SizedBox(height: 8),
                          // Almost nothing in the catalogue is rated, so this
                          // one silently empties the deck. Saying so beats
                          // letting the user conclude the app is broken.
                          const _SectionCaution(
                            message: 'Barely any place here is rated yet — a '
                                'rating limit will empty the deck.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              AppPrimaryButton(
                // The count travels with the button: the user is about to
                // throw away the deck they can see, and should know how much
                // is doing it.
                label: _activeCount == 0
                    // Not "show me everything": halal, vegetarian and budget
                    // live in Settings (D105) and still narrow the deck.
                    ? 'Apply with no limits'
                    : 'Apply $_activeCount ${_activeCount == 1 ? 'limit' : 'limits'}',
                expand: true,
                busy: _saving,
                onPressed: catalog == null || _saving
                    ? null
                    : () => unawaited(_apply()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel({required this.label, this.trailing});

  final String label;

  /// The section's current answer, shown on the same line — the radius reads
  /// as a number, not as a slider position.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    final style = Theme.of(context).textTheme.labelMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(
                color: kTextOnPhotoSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(
                color: kAccentCream,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// How many chips a section has on, or null when it has none — the section
/// label's trailing slot stays empty rather than saying "0 chosen".
String? _chosenLabel(int count) => count == 0 ? null : '$count chosen';

/// The grab bar every modal sheet in the app is dragged by.
/// The two ends of a slider, named. Without them the thumb's position means
/// nothing until it is moved.
class _SliderAnchors extends StatelessWidget {
  const _SliderAnchors({required this.start, required this.end});

  final String start;
  final String end;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: kTextOnPhotoMuted,
        );

    return ExcludeSemantics(
      // The slider next door already announces its own range.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(start, style: style, maxLines: 1)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                end,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A warning attached to one section — for a limit that is legal but will
/// disappoint.
class _SectionCaution extends StatelessWidget {
  const _SectionCaution({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: kAccentEmber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kTextOnPhotoSecondary,
                ),
          ),
        ),
      ],
    );
  }
}

/// The radius stops as a slider, the same one Settings offers.
///
/// Discrete: the stops coarsen as they grow (see `kRadiusStops`), so the
/// slider walks their indices rather than kilometres.
class _RadiusSlider extends StatelessWidget {
  const _RadiusSlider({required this.km, required this.onChanged});

  final int? km;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = kRadiusStops.indexOf(km);

    return Semantics(
      slider: true,
      label: 'Search radius',
      value: radiusLabel(km),
      child: Slider(
        value: (index < 0 ? kRadiusStops.length - 1 : index).toDouble(),
        max: (kRadiusStops.length - 1).toDouble(),
        divisions: kRadiusStops.length - 1,
        label: radiusLabel(km),
        onChanged: (value) => onChanged(kRadiusStops[value.round()]),
      ),
    );
  }
}

/// The pickable catalog chips, shared by the cuisine and dietary sections.
class _OptionWrap extends StatelessWidget {
  const _OptionWrap({
    required this.options,
    required this.isSelected,
    required this.onToggle,
  });

  final List<TasteOption> options;
  final bool Function(int id) isSelected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Text(
        'No options available.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: kTextOnPhotoMuted,
            ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _FilterPill(
            label: option.label,
            selected: isSelected(option.id),
            onTap: () => onToggle(option.id),
          ),
      ],
    );
  }
}

/// One selectable chip: cream fill when picked, hairline outline otherwise —
/// the same selected-state grammar as the Liked screen's segments.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? kAccentCream : Colors.transparent,
            borderRadius: BorderRadius.circular(kRadiusPill),
            border: Border.all(color: selected ? kAccentCream : kHairline),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? kOnAccent : kTextOnPhotoSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
