import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/empty_state.dart';
import '../../auth/state/auth_controller.dart';
import '../../restaurants/models/restaurant_card.dart';
import '../../restaurants/models/restaurant_detail_data.dart';
import '../../restaurants/presentation/discovery_filter_sheet.dart';
import '../../restaurants/state/likes_controller.dart';
import '../data/nearby_repository.dart' show NearbyOrigin;
import '../domain/nearby_format.dart';
import '../domain/pin_spread.dart';
import '../models/nearby_place.dart';
import '../state/nearby_controller.dart';
import 'nearby_pin.dart';
import 'nearby_radius_stepper.dart';
import 'nearby_results_bar.dart';

/// The public OpenStreetMap tile server.
///
/// **Development only.** OSM's tile usage policy forbids a released app from
/// pointing at it: no heavy use, no bulk downloading, and it may be cut off
/// without notice. Shipping means a tile account (MapTiler, Stadia, Mapbox,
/// Thunderforest, or a self-hosted renderer) and swapping this template plus
/// its attribution — see `docs/Features/Nearby-Map.md`.
const String kOsmTileUrlTemplate =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Sent as the `User-Agent`, as OSM's policy requires. The app's real
/// application id, so a blocked client is identifiable rather than anonymous.
const String kTileUserAgentPackageName = 'com.swipeeat.app';

/// The Nearby map: what is actually around you right now, at a radius you set
/// with your thumb.
///
/// Replaces the Explore cuisine grid. A grid of cravings answered "what kinds
/// of food exist"; a hungry person is asking "what is near me and open", and
/// only a map answers that in one look.
class NearbyTab extends StatefulWidget {
  const NearbyTab({
    super.key,
    required this.authController,
    this.controller,
    this.tileProvider,
    this.likes,
  });

  final AuthController authController;

  /// Injected by tests; in the app the tab builds its own.
  final NearbyController? controller;

  /// The tiles. Defaults to the network provider, which is why it is injected
  /// at all: a widget test hands over one that serves a transparent pixel and
  /// never opens a socket.
  final TileProvider? tileProvider;

  /// Which places are already bitten. Defaults to the shared instance.
  final LikesController? likes;

  @override
  State<NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends State<NearbyTab> {
  late final NearbyController _nearby = widget.controller ??
      NearbyController(authController: widget.authController);
  late final bool _ownsController = widget.controller == null;
  late final LikesController _likes = widget.likes ?? LikesController.instance;

  final MapController _map = MapController();

  /// The camera only follows the radius once the map has been laid out —
  /// `fitCamera` before that has no viewport to fit into.
  bool _mapReady = false;

  /// What the camera was last fitted to, so a rebuild that changes none of it
  /// does not fight the user's own panning.
  double? _fittedRadiusKm;
  double? _fittedLatitude;
  double? _fittedLongitude;
  List<int> _fittedPinIds = const [];

  @override
  void initState() {
    super.initState();
    if (_ownsController) {
      unawaited(_nearby.load());
    }
    _nearby.addListener(_onNearbyChanged);
  }

  @override
  void dispose() {
    _nearby.removeListener(_onNearbyChanged);
    if (_ownsController) {
      _nearby.dispose();
    }
    _map.dispose();
    super.dispose();
  }

  void _onNearbyChanged() {
    if (!_mapReady) {
      return;
    }
    // After the frame: the notification can arrive mid-build, and moving the
    // camera during a build is a setState during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fitToPins();
      }
    });
  }

  /// Fits the camera to the pins on show and the user's own dot, so the
  /// default view is those five places at the largest size that fits them.
  /// With nothing to pin it falls back to the circle the stepper names.
  void _fitToPins() {
    final origin = _nearby.origin;
    if (origin == null) {
      return;
    }
    final pinIds = [for (final place in _nearby.pins) place.id];
    if (_fittedRadiusKm == _nearby.radiusKm &&
        _fittedLatitude == origin.latitude &&
        _fittedLongitude == origin.longitude &&
        listEquals(_fittedPinIds, pinIds)) {
      return;
    }

    _fittedRadiusKm = _nearby.radiusKm;
    _fittedLatitude = origin.latitude;
    _fittedLongitude = origin.longitude;
    _fittedPinIds = pinIds;
    _map.fitCamera(_fitFor(origin, _nearby.pins, _nearby.radiusKm));
    // The pins' screen positions changed with the camera; lay them out again.
    if (mounted) {
      setState(() {});
    }
  }

  static CameraFit _fitFor(
    NearbyOrigin origin,
    List<NearbyPlace> pins,
    double radiusKm,
  ) {
    if (pins.isEmpty) {
      return _cameraFit(origin.latitude, origin.longitude, radiusKm);
    }
    final points = [
      LatLng(origin.latitude, origin.longitude),
      for (final place in pins)
        LatLng(place.restaurant.latitude, place.restaurant.longitude),
    ];
    return CameraFit.coordinates(
      coordinates: points,
      // Room for the biggest pin's blob and caption around the outermost
      // coordinates, and for the floating controls at top and bottom.
      padding: const EdgeInsets.fromLTRB(64, 120, 64, 200),
      maxZoom: 17,
    );
  }

  /// Where each pin is drawn: its true coordinate, nudged in screen space
  /// until no two pins overlap. Read from the live camera, so a pan or zoom
  /// lays them out afresh; before the map is ready every pin sits where it is.
  Map<int, LatLng> _displayPoints(List<NearbyPlace> pins) {
    final display = <int, LatLng>{
      for (final place in pins)
        place.id: LatLng(place.restaurant.latitude, place.restaurant.longitude),
    };
    if (!_mapReady || pins.length < 2) {
      return display;
    }
    final camera = _map.camera;
    final boxes = [
      for (final place in pins)
        PinBox(
          id: place.id,
          anchor: camera.latLngToScreenOffset(display[place.id]!),
          width: kNearbyPinWidth,
          height: NearbyPin.heightFor(size: _nearby.pinSizeFor(place)),
          blobSize: _nearby.pinSizeFor(place),
        ),
    ];
    final shifts = spreadPins(boxes, gap: kNearbyPinGap);
    for (final box in boxes) {
      final shift = shifts[box.id]!;
      if (shift != Offset.zero) {
        display[box.id] = camera.screenOffsetToLatLng(box.anchor + shift);
      }
    }
    return display;
  }

  static CameraFit _cameraFit(double latitude, double longitude, double km) {
    // A degree of latitude is ~111 km everywhere; a degree of longitude
    // shrinks with the cosine of the latitude. Malaysia sits near the equator,
    // so the two are almost equal here — the cosine is kept anyway because the
    // app should not be wrong the day the catalogue leaves the tropics.
    final deltaLatitude = km / 111.0;
    final cosine = math.cos(latitude * math.pi / 180).abs();
    final deltaLongitude = km / (111.0 * math.max(cosine, 0.01));

    return CameraFit.bounds(
      bounds: LatLngBounds(
        LatLng(latitude - deltaLatitude, longitude - deltaLongitude),
        LatLng(latitude + deltaLatitude, longitude + deltaLongitude),
      ),
      // Room for the pins, which hang below their coordinate, and for the
      // floating controls at the top and bottom of the map.
      padding: const EdgeInsets.fromLTRB(48, 96, 48, 120),
    );
  }

  Future<void> _openFilters() {
    return showDiscoveryFilterSheet(
      context,
      authController: widget.authController,
      onApply: _applyFilters,
    );
  }

  /// The sheet only reports whether the write landed; the toast is the
  /// screen's job, the same way the deck raises its own.
  Future<bool> _applyFilters({
    required List<int> cuisineIds,
    required List<int> dietaryTagIds,
    double? minRating,
  }) async {
    final saved = await _nearby.applyDiscoveryFilters(
      cuisineIds: cuisineIds,
      dietaryTagIds: dietaryTagIds,
      minRating: minRating,
    );
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your filters.')),
      );
    }
    return saved;
  }

  void _openPlace(NearbyPlace place) {
    context.push(
      '/restaurant/${place.id}',
      extra:
          RestaurantCard.fromRestaurant(place.restaurant).toDetailPayload(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_nearby, _likes, widget.authController]),
      builder: (context, _) {
        return ColoredBox(
          color: kBackgroundDark,
          child: Column(
            children: [
              Expanded(child: _buildMapArea(context)),
              if (!_nearby.needsLocation &&
                  _nearby.error == null &&
                  _nearby.places.isNotEmpty)
                NearbyResultsBar(
                  resultCount: _nearby.places.length,
                  openNowCount: _nearby.openNowCount,
                  minPriceFrom: _nearby.minPriceFrom,
                  onSwipeAll: _nearby.swipeAll,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapArea(BuildContext context) {
    if (_nearby.needsLocation) {
      return _buildEmptyState();
    }

    final origin = _nearby.origin;
    if (origin == null) {
      return _nearby.error != null
          ? _buildError(_nearby.error!)
          : const Center(child: AppLottie(motion: AppMotion.pin, size: 88));
    }

    final now = _nearby.now;
    final centre = LatLng(origin.latitude, origin.longitude);
    final pins = _nearby.pins;
    final points = _displayPoints(pins);

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: centre,
              initialCameraFit: _fitFor(origin, pins, _nearby.radiusKm),
              // Rotation off: every label on this map is upright type, and a
              // tilted "Closes 10 pm" is unreadable for no gain.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              backgroundColor: kBackgroundDark,
              onMapReady: () {
                _mapReady = true;
                _fittedRadiusKm = _nearby.radiusKm;
                _fittedLatitude = origin.latitude;
                _fittedLongitude = origin.longitude;
                _fittedPinIds = [for (final place in pins) place.id];
                // Now there is a camera to project through: spread the pins.
                if (mounted) {
                  setState(() {});
                }
              },
              // Every pan and zoom moves the pins' screen positions, so their
              // spread is recomputed on each one. Five boxes; it is cheap.
              onPositionChanged: (camera, hasGesture) {
                if (_mapReady && mounted && pins.length > 1) {
                  setState(() {});
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: kOsmTileUrlTemplate,
                userAgentPackageName: kTileUserAgentPackageName,
                tileProvider: widget.tileProvider,
                // The tiles are somebody else's raster; fading them in over
                // the app's own motion timing keeps the screen from flashing.
                tileDisplay: const TileDisplay.fadeIn(
                  duration: kMotionDuration,
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: kNearbyMapScrim),
                ),
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: centre,
                    width: kNearbyMeDotSize + kNearbyMeHaloSpread * 2,
                    height: kNearbyMeDotSize + kNearbyMeHaloSpread * 2,
                    child: const NearbyMeDot(),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final place in pins)
                    _markerFor(place, at: points[place.id]!, now: now),
                ],
              ),
            ],
          ),
        ),
        _buildAttribution(context),
        _buildTopBar(context),
        _buildStepper(context),
        if (_nearby.error != null) _buildOverlayMessage(_nearby.error!),
        if (!_nearby.loading &&
            _nearby.error == null &&
            _nearby.places.isEmpty)
          _buildOverlayMessage(
            // The same string the stepper shows, so the sentence names the
            // circle the thumb just set rather than a rounded cousin of it.
            'Nothing within ${formatNearbyDistance(_nearby.radiusKm).label}. '
            'Widen the circle.',
          ),
      ],
    );
  }

  Marker _markerFor(
    NearbyPlace place, {
    required LatLng at,
    required DateTime now,
  }) {
    final size = _nearby.pinSizeFor(place);

    return Marker(
      key: ValueKey<int>(place.id),
      point: at,
      width: kNearbyPinWidth,
      height: NearbyPin.heightFor(size: size),
      alignment: NearbyPin.alignmentFor(size: size),
      child: NearbyPin(
        place: place,
        saved: _likes.isLiked(place.id),
        size: size,
        ringed: _nearby.isProminent(place),
        now: now,
        onTap: () => _openPlace(place),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 20,
      right: 20,
      // No Back button: the prototype draws Nearby as a pushed screen, but
      // here it is a tab and the nav bar is already the way out.
      child: Align(
        alignment: Alignment.centerRight,
        child: AppIconButton(
          icon: Icons.tune_rounded,
          size: kUtilityButtonSize,
          iconSize: 20,
          onPhoto: false,
          background: kGlass,
          semanticLabel: 'Filters',
          badgeCount: widget.authController.user?.activeFilterCount ?? 0,
          onTap: () => unawaited(_openFilters()),
        ),
      ),
    );
  }

  Widget _buildStepper(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 20,
      child: NearbyRadiusStepper(
        radiusKm: _nearby.radiusKm,
        canNarrow: _nearby.canNarrow,
        canWiden: _nearby.canWiden,
        onNarrow: () => unawaited(_nearby.narrow()),
        onWiden: () => unawaited(_nearby.widen()),
      ),
    );
  }

  /// OSM's licence requires the credit, wherever the tiles come from.
  Widget _buildAttribution(BuildContext context) {
    return const Positioned(
      left: 20,
      bottom: 20,
      child: IgnorePointer(
        child: Text(
          '© OpenStreetMap',
          style: TextStyle(
            fontFamily: kTextFontFamily,
            fontSize: kFontSizeMicro,
            color: kCreamMuted,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayMessage(String message) {
    return Positioned(
      left: 20,
      right: 20,
      top: MediaQuery.paddingOf(context).top + 72,
      child: IgnorePointer(
        child: Align(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kSurfaceDark,
              borderRadius: BorderRadius.circular(kRadiusPill),
              border: Border.all(color: kHairline),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeSmall,
                color: kCreamSecondary,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return AppEmptyState(
      eyebrow: 'Map unavailable',
      title: 'Something went wrong',
      message: message,
      actionLabel: 'Try again',
      onAction: () => unawaited(_nearby.load()),
    );
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      eyebrow: 'Nearby',
      title: 'Where are you eating?',
      message:
          'The map draws itself around you, so it needs to know where "around" is.',
      actionLabel: 'Use my location',
      onAction: () => unawaited(_nearby.load()),
      secondaryActionLabel: 'Not now',
      onSecondaryAction: _dismissEmptyState,
    );
  }

  /// "Not now" does not navigate: the nav bar is already the way off this
  /// screen. It says what the consequence is instead, so a user who declines
  /// is not left staring at the same page wondering whether the tap landed.
  void _dismissEmptyState() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The map stays empty until you share your location.'),
      ),
    );
  }
}
