import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/design_tokens.dart';
import '../data/visit_prompt_cache.dart';

/// What the user said when asked whether they went.
enum VisitAnswer { went, didNot }

/// Asks whether the user actually ate at the place this app routed them to.
///
/// Returns null when the sheet is dismissed without an answer — the trip stays
/// pending and the question comes back next time, which makes swiping the
/// sheet away a free "ask me later".
Future<VisitAnswer?> showVisitPromptSheet(
  BuildContext context, {
  required PendingVisit visit,
}) {
  return showModalBottomSheet<VisitAnswer>(
    context: context,
    backgroundColor: kSurfacePanel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
    ),
    builder: (sheetContext) => _VisitPromptSheet(visit: visit),
  );
}

class _VisitPromptSheet extends StatelessWidget {
  const _VisitPromptSheet({required this.visit});

  final PendingVisit visit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppEyebrow(label: 'Welcome back'),
            const SizedBox(height: 8),
            Text(
              'Did you go to ${visit.name}?',
              style: appSectionTitleStyle(context),
            ),
            const SizedBox(height: 6),
            Text(
              'You opened directions ${visitAgeLabel(visit.openedAt)}. '
              'Saying yes files it under Visited.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: kTextOnPhotoMuted),
            ),
            const SizedBox(height: 18),
            AppPrimaryButton(
              label: 'Yes, I went',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: () => Navigator.of(context).pop(VisitAnswer.went),
            ),
            const SizedBox(height: 10),
            AppSecondaryButton(
              label: "I didn't go",
              expand: true,
              onPressed: () => Navigator.of(context).pop(VisitAnswer.didNot),
            ),
          ],
        ),
      ),
    );
  }
}

/// How long ago the directions were opened, in the terms someone would use out
/// loud. Coarse on purpose: the exact minute is not what makes the question
/// answerable, and a precise stamp would only invite doubt.
@visibleForTesting
String visitAgeLabel(DateTime openedAt, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(openedAt);

  if (difference.inHours < 1) {
    return 'less than an hour ago';
  }
  if (difference.inHours < 6) {
    return '${difference.inHours} hours ago';
  }
  if (difference.inHours < 24) {
    return 'earlier today';
  }
  if (difference.inDays == 1) {
    return 'yesterday';
  }
  return '${difference.inDays} days ago';
}
