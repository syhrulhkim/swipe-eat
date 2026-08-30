import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/design_tokens.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/models/taste_option.dart';
import '../state/deck_controller.dart';

/// The minimum-rating steps the sheet offers. Null is "any rating".
const List<double?> kMinRatingOptions = [null, 3.0, 3.5, 4.0, 4.5];

/// Opens the discovery filter sheet over the deck. The sheet edits a local
/// copy of the profile's filter state and writes it in one shot on Apply —
/// the same full-overwrite contract as `set_discovery_filters`.
Future<void> showDiscoveryFilterSheet(
  BuildContext context, {
  required DeckController deck,
  OnboardingRepository? catalog,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurfacePanel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
    ),
    builder: (sheetContext) => DiscoveryFilterSheet(
      deck: deck,
      catalog: catalog ?? OnboardingRepository(),
    ),
  );
}

/// Cuisine, dietary and minimum-rating limits on the deck — Tinder's
/// discovery settings, restated for restaurants.
class DiscoveryFilterSheet extends StatefulWidget {
  const DiscoveryFilterSheet({
    super.key,
    required this.deck,
    required this.catalog,
  });

  final DeckController deck;
  final OnboardingRepository catalog;

  @override
  State<DiscoveryFilterSheet> createState() => _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends State<DiscoveryFilterSheet> {
  TasteCatalog? _catalog;
  bool _loadFailed = false;
  bool _saving = false;

  late final Set<int> _cuisineIds = {
    ...widget.deck.authController.user?.filterCuisineIds ?? const <int>[],
  };
  late final Set<int> _dietaryTagIds = {
    ...widget.deck.authController.user?.filterDietaryTagIds ?? const <int>[],
  };
  late double? _minRating = widget.deck.authController.user?.filterMinRating;

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

    final saved = await widget.deck.applyDiscoveryFilters(
      cuisineIds: _cuisineIds.toList()..sort(),
      dietaryTagIds: _dietaryTagIds.toList()..sort(),
      minRating: _minRating,
    );
    if (!mounted) {
      return;
    }

    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    // The controller already raised its toast; the sheet keeps the edits so
    // the user can retry.
    setState(() {
      _saving = false;
    });
  }

  void _clearAll() {
    setState(() {
      _cuisineIds.clear();
      _dietaryTagIds.clear();
      _minRating = null;
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Discovery filters', style: appPanelTitleStyle(context)),
                  TextButton(
                    onPressed: _saving ? null : _clearAll,
                    child: Text(
                      'Clear all',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: kAccentEmber,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              Text(
                'Hard limits on the deck — only places that pass are dealt.',
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
                        const _SheetSectionLabel(label: 'Cuisines'),
                        _OptionWrap(
                          options: catalog.cuisines,
                          isSelected: _cuisineIds.contains,
                          onToggle: (id) => setState(() {
                            if (!_cuisineIds.remove(id)) {
                              _cuisineIds.add(id);
                            }
                          }),
                        ),
                        const SizedBox(height: 16),
                        const _SheetSectionLabel(label: 'Dietary needs'),
                        _OptionWrap(
                          options: catalog.dietaryTags,
                          isSelected: _dietaryTagIds.contains,
                          onToggle: (id) => setState(() {
                            if (!_dietaryTagIds.remove(id)) {
                              _dietaryTagIds.add(id);
                            }
                          }),
                        ),
                        const SizedBox(height: 16),
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
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              AppPrimaryButton(
                label: 'Apply filters',
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
  const _SheetSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: kTextOnPhotoSecondary,
              fontWeight: FontWeight.w700,
            ),
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
            label: option.emoji == null
                ? option.label
                : '${option.emoji} ${option.label}',
            selected: isSelected(option.id),
            onTap: () => onToggle(option.id),
          ),
      ],
    );
  }
}

/// One selectable pill: cream fill when picked, hairline outline otherwise —
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
