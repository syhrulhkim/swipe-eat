import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/ui/app_spacing.dart';
import '../../auth/state/auth_controller.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authController,
      builder: (context, _) {
        final scaffoldStyle = context.theme.scaffoldStyle.copyWith(
          footerDecoration: const DecorationDelta.value(
            BoxDecoration(color: Colors.transparent),
          ),
        );

        return FScaffold(
          scaffoldStyle: scaffoldStyle,
          childPad: false,
          footer: const SizedBox(height: 96),
          child: Stack(
            children: [
              const Positioned.fill(child: _SwipeDeck()),
            ],
          ),
        );
      },
    );
  }
}

class _SwipeDeck extends StatefulWidget {
  const _SwipeDeck();

  @override
  State<_SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<_SwipeDeck> with SingleTickerProviderStateMixin {
  final List<_SwipeCardData> _cards = const [
    _SwipeCardData(
      title: 'Mak Limah Asam Pedas',
      tag: 'Asam Pedas',
      details:
          'A Batu Pahat asam pedas spot known for its rich, spicy, and tangy comfort food. The card uses the actual storefront photo from the Batu Pahat food guide.',
      color: Color(0xFFF6D365),
      rating: 4.3,
      latitude: 1.8522138,
      longitude: 102.9253991,
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/Mak-Limah-Asam-Pedas.jpg',
        'https://tempatcuti.my/wp-content/uploads/2023/12/Asam-Pedas-Generation-Tambak-Batu-Pahat.jpg',
      ],
    ),
    _SwipeCardData(
      title: 'Warung Wak Jaferi',
      tag: 'Breakfast',
      details:
          'A Batu Pahat breakfast stop with a relaxed morning feel and traditional local dishes. The photo is pulled from the Batu Pahat dining guide for a more authentic look.',
      color: Color(0xFFB7E4C7),
      rating: 4.4,
      latitude: 1.8406831,
      longitude: 102.9430163,
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Wak-Jaferi.jpg',
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Zai-Kak-Zai-Nasi-Lemak.jpg',
      ],
    ),
    _SwipeCardData(
      title: 'Selera Izzati',
      tag: 'Breakfast',
      details:
          'A Batu Pahat morning food spot that keeps the deck varied with another local breakfast option. The card uses the actual restaurant photo instead of a generic food image.',
      color: Color(0xFFF4A261),
      rating: 4.1,
      latitude: 1.8471209,
      longitude: 102.9334028,
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Selera-Izzati.jpg',
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Gerai-Makan-Hidayah.jpg',
      ],
    ),
    _SwipeCardData(
      title: 'Warung Madu 3 Parit Besar',
      tag: 'Breakfast',
      details:
          'A Batu Pahat breakfast spot with a warm, local feel and a photo that matches the actual restaurant frontage from the guide.',
      color: Color(0xFFE76F51),
      rating: 4.1,
      latitude: 1.8683906,
      longitude: 102.957791,
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Madu-3-Parit-Besar.jpg',
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Hans-Nasi-Lemak-Ayam-Kamung-Benteng-BP.jpg',
      ],
    ),
    _SwipeCardData(
      title: 'Warung Ahmad Nasi Lemak',
      tag: 'Nasi Lemak',
      details:
          'A Batu Pahat nasi lemak stop with a familiar local breakfast vibe and an actual restaurant photo from the guide.',
      color: Color(0xFFEE9B00),
      rating: 4.2,
      latitude: 1.8740357,
      longitude: 102.9415007,
      imageUrls: [
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Ahmad-Nasi-Lemak.jpg',
        'https://tempatcuti.my/wp-content/uploads/2023/12/sarapan-pagi-di-Batu-Pahat-Warung-Zai-Kak-Zai-Nasi-Lemak.jpg',
      ],
    ),
  ];

  int _index = 0;
  Offset _dragOffset = Offset.zero;
  bool _infoExpanded = false;
  Position? _userPosition;
  String? _distanceStatus;

  Offset _animationStartOffset = Offset.zero;
  Offset _animationEndOffset = Offset.zero;
  _SwipeMotionType _motionType = _SwipeMotionType.idle;

  late final AnimationController _motionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  )..addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) {
        return;
      }

      setState(() {
        if (_motionType == _SwipeMotionType.swipeOut) {
          _index += 1;
        }

        _dragOffset = Offset.zero;
        _infoExpanded = false;
        _motionType = _SwipeMotionType.idle;
      });

      _motionController.reset();
    });

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    try {
      setState(() {
        _distanceStatus = 'Getting location...';
      });

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _distanceStatus = 'Location off';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _distanceStatus = 'Permission needed';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      );

      if (!mounted) return;
      setState(() {
        _userPosition = position;
        _distanceStatus = null;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _distanceStatus = 'Restart app';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _distanceStatus = 'Distance unavailable';
      });
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  void _handleLike() => _animateOut(true);
  void _handleDislike() => _animateOut(false);

  void _animateOut(bool liked) {
    if (_index >= _cards.length || _motionType != _SwipeMotionType.idle) {
      return;
    }

    setState(() {
      _motionType = _SwipeMotionType.swipeOut;
      _animationStartOffset = _dragOffset;
      _animationEndOffset = Offset(liked ? 460 : -460, -220);
    });

    _motionController.forward(from: 0);
  }

  String _ratingText(_SwipeCardData data) {
    return data.rating.toStringAsFixed(1);
  }

  String _distanceLabelFor(_SwipeCardData data) {
    final userPosition = _userPosition;
    if (userPosition == null) {
      return _distanceStatus ?? 'Distance loading';
    }

    final meters = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      data.latitude,
      data.longitude,
    );
    final km = meters / 1000;
    if (km > 100) {
      return '100+ km';
    }

    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _cards.length) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: FCard(
            title: const Text('No more cards'),
            subtitle: const Text('Restart to keep swiping.'),
            child: FButton(
              variant: FButtonVariant.outline,
              onPress: () {
                setState(() {
                  _index = 0;
                  _dragOffset = Offset.zero;
                  _infoExpanded = false;
                  _motionType = _SwipeMotionType.idle;
                  _animationStartOffset = Offset.zero;
                  _animationEndOffset = Offset.zero;
                  _motionController.reset();
                });
              },
              child: const Text('Restart deck'),
            ),
          ),
        ),
      );
    }

    final current = _cards[_index];
    final next = _index + 1 < _cards.length ? _cards[_index + 1] : null;
    final motionProgress = Curves.easeInOutCubic.transform(_motionController.value);
    final currentOffset = _motionType == _SwipeMotionType.idle
        ? _dragOffset
        : ui.Offset.lerp(
            _animationStartOffset,
            _animationEndOffset,
            motionProgress,
          ) ??
            _dragOffset;
    final dragPercentage = (currentOffset.dx.abs() / 260).clamp(0.0, 1.0);
    final rotation = currentOffset.dx / 900;
    final showLike = currentOffset.dx > 20;
    final showNope = currentOffset.dx < -20;
    final nextLift = Curves.easeOutCubic.transform(dragPercentage);
    final currentRating = _ratingText(current);
    final currentDistance = _distanceLabelFor(current);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (next != null)
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: 0.88 + (nextLift * 0.12),
                    child: Transform.translate(
                      offset: Offset(0, 16 - (nextLift * 16)),
                      child: Transform.scale(
                        scale: 0.94 + (nextLift * 0.06),
                        child: _SwipeCard(
                          key: ValueKey(next.title),
                          data: next,
                          isBehind: true,
                          infoExpanded: _infoExpanded,
                          ratingText: _ratingText(next),
                          distanceText: _distanceLabelFor(next),
                          onInfoTap: () {
                            setState(() {
                              _infoExpanded = !_infoExpanded;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: GestureDetector(
                  onPanUpdate: _motionType != _SwipeMotionType.idle
                      ? null
                      : (details) {
                          setState(() {
                            _motionController.stop();
                            _motionType = _SwipeMotionType.idle;
                            _dragOffset += details.delta;
                          });
                        },
                  onPanEnd: _motionType != _SwipeMotionType.idle
                      ? null
                      : (details) {
                          if (_dragOffset.dx > 110) {
                            _handleLike();
                            return;
                          }

                          if (_dragOffset.dx < -110) {
                            _handleDislike();
                            return;
                          }

                          setState(() {
                            _motionType = _SwipeMotionType.settleBack;
                            _animationStartOffset = _dragOffset;
                            _animationEndOffset = Offset.zero;
                            _motionController.forward(from: 0);
                            _dragOffset = Offset.zero;
                          });
                        },
                  child: AnimatedBuilder(
                    animation: _motionController,
                    builder: (context, child) {
                      final scale = _motionType == _SwipeMotionType.swipeOut
                          ? ui.lerpDouble(1, 0.98, motionProgress) ?? 1
                          : ui.lerpDouble(1, 0.995, motionProgress) ?? 1;
                      final opacity = _motionType == _SwipeMotionType.swipeOut
                          ? ui.lerpDouble(1, 0.92, motionProgress) ?? 1
                          : 1.0;

                      return Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: currentOffset,
                          child: Transform.rotate(
                            angle: rotation,
                            child: Transform.scale(
                              scale: scale,
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        _SwipeCard(
                          key: ValueKey(current.title),
                          data: current,
                          likeOpacity: showLike ? dragPercentage : 0,
                          nopeOpacity: showNope ? dragPercentage : 0,
                          infoExpanded: _infoExpanded,
                          ratingText: currentRating,
                          distanceText: currentDistance,
                          onInfoTap: () {
                            setState(() {
                              _infoExpanded = !_infoExpanded;
                            });
                          },
                          showActions: true,
                          onPass: _handleDislike,
                          onLike: _handleLike,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _SwipeMotionType {
  idle,
  settleBack,
  swipeOut,
}

class _SwipeCard extends StatefulWidget {
  const _SwipeCard({
    super.key,
    required this.data,
    required this.infoExpanded,
    required this.ratingText,
    required this.distanceText,
    required this.onInfoTap,
    this.showActions = false,
    this.onPass,
    this.onLike,
    this.isBehind = false,
    this.likeOpacity = 0,
    this.nopeOpacity = 0,
  });

  final _SwipeCardData data;
  final bool infoExpanded;
  final String ratingText;
  final String distanceText;
  final VoidCallback onInfoTap;
  final bool showActions;
  final VoidCallback? onPass;
  final VoidCallback? onLike;
  final bool isBehind;
  final double likeOpacity;
  final double nopeOpacity;

  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard> {
  int _imageIndex = 0;
  Offset? _imagePointerStart;
  bool _imagePointerMoved = false;

  @override
  void didUpdateWidget(covariant _SwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.title != widget.data.title) {
      _imageIndex = 0;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _changeImage(int delta) {
    final nextIndex = (_imageIndex + delta).clamp(0, widget.data.imageUrls.length - 1);
    if (nextIndex == _imageIndex) {
      return;
    }

    setState(() {
      _imageIndex = nextIndex;
    });
  }

  void _handleImageTap(Offset localPosition, double width) {
    if (widget.data.imageUrls.length <= 1) {
      return;
    }

    final isLeftSide = localPosition.dx < width / 2;
    _changeImage(isLeftSide ? -1 : 1);
  }

  @override
  Widget build(BuildContext context) {
    const bottomRadius = Radius.circular(40);
    final hasMultipleImages = widget.data.imageUrls.length > 1;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        bottomLeft: bottomRadius,
        bottomRight: bottomRadius,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            bottomLeft: bottomRadius,
            bottomRight: bottomRadius,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        _imagePointerStart = event.localPosition;
                        _imagePointerMoved = false;
                      },
                      onPointerMove: (event) {
                        final start = _imagePointerStart;
                        if (start == null || _imagePointerMoved) {
                          return;
                        }

                        if ((event.localPosition - start).distance > 12) {
                          _imagePointerMoved = true;
                        }
                      },
                      onPointerUp: (event) {
                        final start = _imagePointerStart;
                        final moved = _imagePointerMoved;
                        _imagePointerStart = null;
                        _imagePointerMoved = false;

                        if (start == null || moved) {
                          return;
                        }

                        final local = event.localPosition;
                        _handleImageTap(local, constraints.maxWidth);
                      },
                      onPointerCancel: (_) {
                        _imagePointerStart = null;
                        _imagePointerMoved = false;
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: SizedBox.expand(
                          key: ValueKey(widget.data.imageUrls[_imageIndex]),
                          child: Image.network(
                            widget.data.imageUrls[_imageIndex],
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }

                              return const SizedBox.expand(
                                child: Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const SizedBox.expand();
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: AppSpacing.screenPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RestaurantInfoPanel(
                    data: widget.data,
                    expanded: widget.infoExpanded,
                    ratingText: widget.ratingText,
                    distanceText: widget.distanceText,
                    imageIndex: _imageIndex,
                    hasMultipleImages: hasMultipleImages,
                    onTap: widget.onInfoTap,
                  ),
                  if (widget.showActions) ...[
                    const SizedBox(height: 2),
                    _SwipeActionBar(
                      onPass: widget.onPass!,
                      onLike: widget.onLike!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantInfoPanel extends StatefulWidget {
  const _RestaurantInfoPanel({
    required this.data,
    required this.expanded,
    required this.ratingText,
    required this.distanceText,
    required this.imageIndex,
    required this.hasMultipleImages,
    required this.onTap,
  });

  final _SwipeCardData data;
  final bool expanded;
  final String ratingText;
  final String distanceText;
  final int imageIndex;
  final bool hasMultipleImages;
  final VoidCallback onTap;

  @override
  State<_RestaurantInfoPanel> createState() => _RestaurantInfoPanelState();
}

class _RestaurantInfoPanelState extends State<_RestaurantInfoPanel>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.black.withValues(alpha: 0.24),
          child: InkWell(
            onTap: widget.onTap,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.hasMultipleImages) ...[
                      _ImageProgressDots(
                        count: widget.data.imageUrls.length,
                        activeIndex: widget.imageIndex,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      widget.data.tag,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.data.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          icon: Icons.star_rounded,
                          label: widget.ratingText,
                        ),
                        _InfoPill(
                          icon: Icons.place_rounded,
                          label: widget.distanceText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.data.details,
                      maxLines: widget.expanded ? null : 2,
                      overflow: widget.expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.35,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeActionBar extends StatelessWidget {
  const _SwipeActionBar({
    required this.onPass,
    required this.onLike,
  });

  final VoidCallback onPass;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _ConnectedActionButton(
                    icon: Icons.close_rounded,
                    label: 'Pass',
                    color: const Color(0xFFE25555),
                    onTap: onPass,
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                Expanded(
                  child: _ConnectedActionButton(
                    icon: Icons.favorite_rounded,
                    label: 'Like',
                    color: const Color(0xFF1F9D55),
                    onTap: onLike,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectedActionButton extends StatelessWidget {
  const _ConnectedActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ImageProgressDots extends StatelessWidget {
  const _ImageProgressDots({
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: isActive ? 18 : 6,
          height: 3,
          margin: EdgeInsets.only(right: index == count - 1 ? 0 : 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isActive ? 0.95 : 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

/*
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FloatingIconButton(
          icon: icon,
          onTap: onTap,
          color: label == 'Like'
              ? const Color(0xFF1F9D55)
              : const Color(0xFFE25555),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _FloatingIconButton extends StatelessWidget {
  const _FloatingIconButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final background = color ?? Colors.white.withValues(alpha: 0.16);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: background,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
*/

class _SwipeCardData {
  const _SwipeCardData({
    required this.title,
    required this.tag,
    required this.details,
    required this.color,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.imageUrls,
  });

  final String title;
  final String tag;
  final String details;
  final Color color;
  final double rating;
  final double latitude;
  final double longitude;
  final List<String> imageUrls;
}
