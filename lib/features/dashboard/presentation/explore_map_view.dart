import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/ui/glass_ui.dart';
import '../../../core/ui/rating_label.dart';
import '../../restaurants/models/restaurant.dart';

/// Map-style Explore screen from the reference design: a stylised isometric
/// "city" canvas with the nearest restaurants as tappable photo pins, a lime
/// route from the user's marker to the selected pin, and a frosted info card
/// for the selection. The full catalog stays reachable through the top-right
/// browse button.
class ExploreMapView extends StatefulWidget {
  const ExploreMapView({
    super.key,
    required this.restaurants,
    required this.userPosition,
    required this.onOpenRestaurant,
  });

  final List<Restaurant> restaurants;
  final Position? userPosition;
  final void Function(Restaurant restaurant) onOpenRestaurant;

  @override
  State<ExploreMapView> createState() => _ExploreMapViewState();
}

class _ExploreMapViewState extends State<ExploreMapView> {
  static const _pinCount = 5;

  int _selectedIndex = 0;

  List<Restaurant> get _pinned {
    final geocoded = widget.restaurants
        .where((r) => r.latitude != 0 || r.longitude != 0)
        .toList();
    final source = geocoded.isEmpty ? widget.restaurants : geocoded;

    final position = widget.userPosition;
    final ranked = [...source];
    if (position != null) {
      ranked.sort(
        (a, b) => _distanceMeters(a, position)
            .compareTo(_distanceMeters(b, position)),
      );
    }
    return ranked.take(_pinCount).toList();
  }

  double _distanceMeters(Restaurant restaurant, Position position) {
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      restaurant.latitude,
      restaurant.longitude,
    );
  }

  String _distanceLabel(Restaurant restaurant) {
    final position = widget.userPosition;
    if (position == null ||
        (restaurant.latitude == 0 && restaurant.longitude == 0)) {
      return 'Johor Bahru';
    }

    final meters = _distanceMeters(restaurant, position);
    if (meters >= 100000) {
      return '100 km +';
    }
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  void _showAllRestaurants() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSurfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(kRadiusPill),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'All restaurants',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: widget.restaurants.length,
                    itemBuilder: (context, index) {
                      final restaurant = widget.restaurants[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        leading: _PinAvatar(restaurant: restaurant, size: 44),
                        title: Text(
                          restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          [
                            _distanceLabel(restaurant),
                            if (restaurant.tag.isNotEmpty) restaurant.tag,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onOpenRestaurant(restaurant);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _pinned;
    if (pinned.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedIndex = _selectedIndex.clamp(0, pinned.length - 1);
    final selected = pinned[selectedIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final pinPoints = _projectPins(pinned, size);
        final youPoint = Offset(size.width * 0.56, size.height - 268);

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _IsoCityPainter(),
            ),
            CustomPaint(
              painter: _RoutePainter(
                start: youPoint,
                end: pinPoints[selectedIndex] + const Offset(0, 34),
              ),
            ),
            Positioned(
              left: youPoint.dx - 40,
              top: youPoint.dy - 40,
              child: const IgnorePointer(child: _YouMarker()),
            ),
            for (var i = 0; i < pinned.length; i++)
              Positioned(
                left: pinPoints[i].dx - 32,
                top: pinPoints[i].dy - 34,
                child: _RestaurantPin(
                  restaurant: pinned[i],
                  selected: i == selectedIndex,
                  onTap: () {
                    setState(() {
                      _selectedIndex = i;
                    });
                  },
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _SelectedRestaurantCard(
                restaurant: selected,
                distanceLabel: _distanceLabel(selected),
                onOpen: () => widget.onOpenRestaurant(selected),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GlassCircleButton(
                        icon: Icons.my_location_rounded,
                        size: kUtilityButtonSize,
                        background: Colors.black.withValues(alpha: 0.34),
                        semanticLabel: 'Nearest restaurant',
                        onTap: () {
                          setState(() {
                            _selectedIndex = 0;
                          });
                        },
                      ),
                      GlassCircleButton(
                        icon: Icons.more_horiz_rounded,
                        size: kUtilityButtonSize,
                        background: Colors.black.withValues(alpha: 0.34),
                        semanticLabel: 'Browse all restaurants',
                        onTap: _showAllRestaurants,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Spreads the pins over the map area above the info card. Geocoded pins
  /// keep their relative geographic layout; a seeded scatter fills in when
  /// coordinates are missing or degenerate.
  List<Offset> _projectPins(List<Restaurant> pinned, Size size) {
    const left = 56.0;
    final right = size.width - 56.0;
    final top = 140.0 + MediaQuery.paddingOf(context).top;
    // Keep pins clear of the info card; never let the band collapse or
    // invert on very short viewports.
    final bottom = math.max(top + 60.0, size.height - 360.0);

    double? minLat, maxLat, minLng, maxLng;
    for (final r in pinned) {
      if (r.latitude == 0 && r.longitude == 0) continue;
      minLat = math.min(minLat ?? r.latitude, r.latitude);
      maxLat = math.max(maxLat ?? r.latitude, r.latitude);
      minLng = math.min(minLng ?? r.longitude, r.longitude);
      maxLng = math.max(maxLng ?? r.longitude, r.longitude);
    }

    final latSpan = (maxLat ?? 0) - (minLat ?? 0);
    final lngSpan = (maxLng ?? 0) - (minLng ?? 0);
    final geographic = latSpan > 0.0005 || lngSpan > 0.0005;

    final points = <Offset>[];
    final random = math.Random(7);
    for (var i = 0; i < pinned.length; i++) {
      final r = pinned[i];
      if (geographic && (r.latitude != 0 || r.longitude != 0)) {
        final tx = lngSpan == 0
            ? 0.5
            : ((r.longitude - minLng!) / lngSpan).clamp(0.0, 1.0);
        final ty = latSpan == 0
            ? 0.5
            : (1 - (r.latitude - minLat!) / latSpan).clamp(0.0, 1.0);
        points.add(
          Offset(
            left + tx * (right - left),
            top + ty * (bottom - top),
          ),
        );
      } else {
        points.add(
          Offset(
            left + random.nextDouble() * (right - left),
            top + random.nextDouble() * (bottom - top),
          ),
        );
      }
    }
    return points;
  }
}

class _RestaurantPin extends StatelessWidget {
  const _RestaurantPin({
    required this.restaurant,
    required this.selected,
    required this.onTap,
  });

  final Restaurant restaurant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ringColor = selected ? kAccentLime : const Color(0xFF262C36);

    return Semantics(
      label: restaurant.name,
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: ringColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child:
                  _PinAvatar(restaurant: restaurant, size: selected ? 56 : 48),
            ),
            CustomPaint(
              size: const Size(14, 9),
              painter: _PinTailPainter(color: ringColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinAvatar extends StatelessWidget {
  const _PinAvatar({required this.restaurant, required this.size});

  final Restaurant restaurant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFF1A202A),
      child: const Icon(
        Icons.restaurant_rounded,
        color: Colors.white54,
        size: 20,
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: restaurant.imageUrls.isEmpty
            ? fallback
            : Image.network(
                restaurant.imageUrls.first,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  const _PinTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTailPainter oldDelegate) => oldDelegate.color != color;
}

class _YouMarker extends StatelessWidget {
  const _YouMarker();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kAccentLime.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kOnAccentLime,
              border: Border.all(color: kAccentLime, width: 3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted info card for the selected pin, matching the reference: avatar,
/// name with muted rating, location line, chat button, and a chip row.
class _SelectedRestaurantCard extends StatelessWidget {
  const _SelectedRestaurantCard({
    required this.restaurant,
    required this.distanceLabel,
    required this.onOpen,
  });

  final Restaurant restaurant;
  final String distanceLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final rating = ratingLabel(restaurant.rating);

    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusSheet),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSurfaceDark.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(kRadiusSheet),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Column(
            key: ValueKey(restaurant.id),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PinAvatar(restaurant: restaurant, size: 54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: restaurant.name,
                            // One step down from glassTitleStyle: this card is
                            // a compact preview, not a hero.
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: kTextOnPhoto,
                                  fontWeight: FontWeight.w700,
                                ),
                            children: [
                              if (rating != '–')
                                TextSpan(
                                  text: '  $rating',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: kTextOnPhotoMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.place_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$distanceLabel away',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GlassCircleButton(
                    icon: Icons.chat_bubble_rounded,
                    size: kUtilityButtonSize,
                    // The info card behind it is a near-opaque fill, so there
                    // is nothing to blur — skip the render pass.
                    frosted: false,
                    semanticLabel: 'Open ${restaurant.name}',
                    onTap: onOpen,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // frosted: false throughout — these sit on the card's
                // near-opaque fill, so each BackdropFilter would blur nothing.
                child: Row(
                  children: [
                    GlassChip(
                      icon: Icons.route_rounded,
                      label: distanceLabel,
                      frosted: false,
                    ),
                    if (restaurant.tag.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GlassChip(
                        icon: Icons.local_dining_rounded,
                        label: restaurant.tag,
                        frosted: false,
                      ),
                    ],
                    if (rating != '–') ...[
                      const SizedBox(width: 8),
                      GlassChip(
                        icon: Icons.star_rounded,
                        label: rating,
                        frosted: false,
                      ),
                    ],
                    if (restaurant.videoUrl != null &&
                        restaurant.videoUrl!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const GlassChip(
                        icon: Icons.music_note_rounded,
                        label: 'TikTok',
                        frosted: false,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stylised isometric "city": scattered dark cubes on a near-black ground,
/// echoing the reference map without a real map dependency.
class _IsoCityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = kBackgroundDeep,
    );

    final random = math.Random(42);
    final topPaint = Paint()..color = const Color(0xFF1D232D);
    final leftPaint = Paint()..color = const Color(0xFF151A22);
    final rightPaint = Paint()..color = const Color(0xFF0E1218);

    const cell = 74.0;
    for (var y = -1; y < size.height / cell + 1; y++) {
      for (var x = -1; x < size.width / cell + 1; x++) {
        if (random.nextDouble() < 0.42) {
          // Leave streets between the blocks.
          random.nextDouble();
          random.nextDouble();
          continue;
        }
        final cx = x * cell +
            cell / 2 +
            (y.isEven ? cell / 3 : 0) +
            (random.nextDouble() - 0.5) * 18;
        final cy = y * cell + cell / 2 + (random.nextDouble() - 0.5) * 18;
        final s = 12 + random.nextDouble() * 18;
        final d = s * (0.8 + random.nextDouble() * 0.9);
        _drawCube(
            canvas, Offset(cx, cy), s, d, topPaint, leftPaint, rightPaint);
      }
    }
  }

  void _drawCube(
    Canvas canvas,
    Offset c,
    double s,
    double d,
    Paint top,
    Paint left,
    Paint right,
  ) {
    final topFace = Path()
      ..moveTo(c.dx, c.dy)
      ..lineTo(c.dx + s, c.dy + s * 0.5)
      ..lineTo(c.dx, c.dy + s)
      ..lineTo(c.dx - s, c.dy + s * 0.5)
      ..close();
    final rightFace = Path()
      ..moveTo(c.dx + s, c.dy + s * 0.5)
      ..lineTo(c.dx + s, c.dy + s * 0.5 + d)
      ..lineTo(c.dx, c.dy + s + d)
      ..lineTo(c.dx, c.dy + s)
      ..close();
    final leftFace = Path()
      ..moveTo(c.dx - s, c.dy + s * 0.5)
      ..lineTo(c.dx - s, c.dy + s * 0.5 + d)
      ..lineTo(c.dx, c.dy + s + d)
      ..lineTo(c.dx, c.dy + s)
      ..close();
    canvas.drawPath(rightFace, right);
    canvas.drawPath(leftFace, left);
    canvas.drawPath(topFace, top);
  }

  @override
  bool shouldRepaint(_IsoCityPainter oldDelegate) => false;
}

/// Lime zigzag route from the user's marker to the selected pin.
class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.start, required this.end});

  final Offset start;
  final Offset end;

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[start];
    const elbows = 3;
    for (var i = 1; i <= elbows; i++) {
      final t = i / (elbows + 1);
      final y = start.dy + (end.dy - start.dy) * t;
      final baseX = start.dx + (end.dx - start.dx) * t;
      final wobble = (1 - t) * 70 * (i.isOdd ? 1 : -1);
      points.add(Offset(baseX + wobble, y));
    }
    points.add(end);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = kAccentLime.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = kAccentLime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
}
