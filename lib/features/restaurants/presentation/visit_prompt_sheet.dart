import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/design_tokens.dart';
import '../data/visit_prompt_cache.dart';

/// What the user said when asked whether they went, and what they thought of
/// it (D147).
///
/// [rating] is null when they went but did not rate — a real answer, and the
/// only one the app had before the stars existed.
@immutable
class VisitPromptResult {
  const VisitPromptResult({required this.went, this.rating, this.note});

  final bool went;
  final int? rating;
  final String? note;
}

/// Asks whether the user actually ate at the place this app routed them to —
/// or at the place they had a plan for — and, if they did, how it was.
///
/// Returns null when the sheet is dismissed without an answer: the question
/// stays open and comes back next time, which makes swiping the sheet away a
/// free "ask me later".
Future<VisitPromptResult?> showVisitPromptSheet(
  BuildContext context, {
  required PendingVisit visit,
}) {
  return showModalBottomSheet<VisitPromptResult>(
    context: context,
    backgroundColor: kSurfacePanel,
    // The note field brings the keyboard with it, and a sheet that is not
    // scroll-controlled cannot move out of its way.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
    ),
    builder: (sheetContext) => _VisitPromptSheet(visit: visit),
  );
}

class _VisitPromptSheet extends StatefulWidget {
  const _VisitPromptSheet({required this.visit});

  final PendingVisit visit;

  @override
  State<_VisitPromptSheet> createState() => _VisitPromptSheetState();
}

class _VisitPromptSheetState extends State<_VisitPromptSheet> {
  final TextEditingController _note = TextEditingController();
  int? _rating;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit(bool went) {
    final note = _note.text.trim();
    Navigator.of(context).pop(
      VisitPromptResult(
        went: went,
        rating: went ? _rating : null,
        note: went && note.isNotEmpty ? note : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;
    final fromPlan = visit.planId != null;
    final age = visitAgeLabel(visit.openedAt);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppEyebrow(label: fromPlan ? 'Your plan' : 'Welcome back'),
              const SizedBox(height: 8),
              Text(
                'Did you go to ${visit.name}?',
                style: appSectionTitleStyle(context),
              ),
              const SizedBox(height: 6),
              Text(
                fromPlan
                    ? 'You had a plan there $age. Stars go to your friends, '
                        'nobody else.'
                    : 'You opened directions $age. Saying yes files it under '
                        'Visited.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: kTextOnPhotoMuted),
              ),
              const SizedBox(height: 18),
              Text(
                'How was it?',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: kTextOnPhotoMuted),
              ),
              const SizedBox(height: 6),
              _Stars(
                value: _rating,
                onChanged: (value) => setState(() => _rating = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLength: 280,
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Say one thing about it (optional)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              AppPrimaryButton(
                label: _rating == null ? 'Yes, I went' : 'Post it',
                icon: Icons.check_rounded,
                expand: true,
                onPressed: () => _submit(true),
              ),
              const SizedBox(height: 10),
              AppSecondaryButton(
                label: "I didn't go",
                expand: true,
                onPressed: () => _submit(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Five stars, one tap. Tapping the lit star again clears the rating, because
/// the alternative is a user stuck with a number they did not mean.
class _Stars extends StatelessWidget {
  const _Stars({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var star = 1; star <= 5; star++)
          IconButton(
            onPressed: () => onChanged(value == star ? null : star),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: Icon(
              (value ?? 0) >= star ? Icons.star_rounded : Icons.star_outline_rounded,
              color: (value ?? 0) >= star ? kAccentEmber : kTextOnPhotoMuted,
              size: 32,
            ),
            tooltip: '$star star${star == 1 ? '' : 's'}',
          ),
      ],
    );
  }
}

/// How long ago the trip was, in the terms someone would use out loud. Coarse
/// on purpose: the exact minute is not what makes the question answerable, and
/// a precise stamp would only invite doubt.
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
