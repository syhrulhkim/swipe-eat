import 'package:flutter/material.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../../../core/ui/design_tokens.dart';
import '../../models/dish.dart';

/// "What people bite" — the design's `.dishes`.
///
/// Renders nothing at all when the restaurant has no dishes on file, which is
/// most of them today: an empty heading over an empty list would advertise a
/// section the catalogue cannot fill yet.
class DishList extends StatelessWidget {
  const DishList({super.key, required this.dishes});

  final List<Dish> dishes;

  @override
  Widget build(BuildContext context) {
    if (dishes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('What people bite', style: appSectionTitleStyle(context)),
        const SizedBox(height: 6),
        for (var i = 0; i < dishes.length; i++)
          _DishRow(dish: dishes[i], last: i == dishes.length - 1),
      ],
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({required this.dish, required this.last});

  final Dish dish;

  /// `.dish:last-child{border-bottom:0}`.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final price = dish.priceLabel;
    final description = dish.description.trim();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border:
            last ? null : const Border(bottom: BorderSide(color: kHairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Thumb(imageUrl: dish.imageUrl),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dish.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeBody,
                    fontWeight: FontWeight.w600,
                    color: kTextOnPhoto,
                    height: 1.25,
                  ),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: kTextFontFamily,
                      fontSize: kFontSizeSmall,
                      fontWeight: FontWeight.w400,
                      color: kTextOnPhotoSecondary,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
          if (price != null) ...[
            const SizedBox(width: AppSpacing.xs),
            // `.dish .price` is the display face at 16/700 — the same thing a
            // wishlist row's title is, so it shares that helper rather than
            // restating it.
            Text(price, style: appRowTitleStyle(context)),
          ],
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusWishThumb),
      child: SizedBox(
        width: kDishThumbSize,
        height: kDishThumbSize,
        child: url == null || url.isEmpty
            ? const ColoredBox(color: kSurfacePanel)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const ColoredBox(color: kSurfacePanel);
                },
              ),
      ),
    );
  }
}
