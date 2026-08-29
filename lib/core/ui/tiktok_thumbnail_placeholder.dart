import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Fallback for a missing or no-longer-loading restaurant thumbnail
/// (plan.md "Expired Thumbnail UI"): a branded TikTok-review placeholder
/// instead of a blank box. Rendering it never retries the broken URL.
class TikTokThumbnailPlaceholder extends StatelessWidget {
  const TikTokThumbnailPlaceholder({super.key, this.creatorHandle});

  /// The @handle of the review's creator, when known.
  final String? creatorHandle;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kSurfaceDark,
      child: Center(
        // Thumbnail slots can be shorter than the badge + labels stack (small
        // cards, split-screen widths), so scale the content down instead of
        // overflowing the box.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white70,
                  size: 26,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'TikTok Review',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (creatorHandle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    creatorHandle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extracts the creator's @handle from a TikTok video URL, or null when the
/// URL is absent or has no handle segment.
String? tiktokCreatorHandle(String? videoUrl) {
  if (videoUrl == null) {
    return null;
  }
  return RegExp(r'@[A-Za-z0-9_.]+').firstMatch(videoUrl)?.group(0);
}
