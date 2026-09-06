import 'package:flutter/material.dart';

import '../../../../core/ui/design_tokens.dart';

/// The caption the clip was scraped from, three lines at a time.
///
/// Not in the design, which assumes an editor wrote a description. It is the
/// only prose the catalogue has, and the screen it used to sit on is gone, so
/// it stays — collapsed, under everything the design does specify.
class AboutParagraph extends StatefulWidget {
  const AboutParagraph({super.key, required this.text});

  final String text;

  @override
  State<AboutParagraph> createState() => _AboutParagraphState();
}

class _AboutParagraphState extends State<AboutParagraph> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('About', style: appSectionTitleStyle(context)),
        const SizedBox(height: 6),
        AnimatedSize(
          duration: kMotionDuration,
          curve: kMotionEase,
          alignment: Alignment.topLeft,
          child: Text(
            text,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kTextFontFamily,
              fontSize: kFontSizeSmall,
              fontWeight: FontWeight.w400,
              color: kTextOnPhotoSecondary,
              height: 1.4,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: _expanded ? 'Less' : 'More',
          excludeSemantics: true,
          // Excluding drops the child's tap action along with its label, so
          // the action is re-declared here (D83).
          onTap: _toggle,
          child: GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: kMinTapTarget,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _expanded ? 'Less' : 'More',
                  style: const TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeSmall,
                    // Ember because it is tappable, which is the only reason
                    // anything in this app is ember.
                    color: kAccentEmber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _toggle() => setState(() => _expanded = !_expanded);
}
