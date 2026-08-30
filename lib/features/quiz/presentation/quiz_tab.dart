import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_lottie.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../../core/ui/preference_tile.dart';
import '../../dashboard/presentation/dashboard_widgets.dart';
import '../state/quiz_controller.dart';

/// One question, four answers, and the restaurant the answer suggests.
class QuizTab extends StatefulWidget {
  const QuizTab({super.key, this.controller});

  /// Injected by tests; in the app the tab builds its own.
  final QuizController? controller;

  @override
  State<QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<QuizTab> {
  late final QuizController _quiz = widget.controller ?? QuizController();
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
    if (_ownsController) {
      unawaited(_quiz.load());
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _quiz.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _quiz,
      builder: (context, _) => DashboardTabShell(
        eyebrow: 'One question a day',
        title: 'Quiz',
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            14,
            AppSpacing.screenPadding,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildBody(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context) {
    if (_quiz.loading) {
      // Transient, so it may loop: the tab replaces it the moment the
      // question arrives.
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: AppLottie(motion: AppMotion.spinner, size: 64)),
        ),
      ];
    }

    final error = _quiz.error;
    if (error != null) {
      return [
        EmptyTabMessage(
          eyebrow: 'Quiz unavailable',
          title: 'Something went wrong',
          subtitle: error,
          actionLabel: 'Try again',
          onAction: () => unawaited(_quiz.load()),
        ),
      ];
    }

    final question = _quiz.question;
    if (question == null || question.options.isEmpty) {
      return const [
        EmptyTabMessage(
          eyebrow: 'Nothing today',
          title: 'No quiz available',
          subtitle: 'Check back soon.',
        ),
      ];
    }

    final selected = _quiz.selectedOption;

    return [
      // The question is the name of what is on this screen, so it carries the
      // display face rather than sitting under the header as body copy.
      Text(question.prompt, style: appSectionTitleStyle(context)),
      const SizedBox(height: 16),
      ...question.options.map(
        (option) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _QuizAnswerTile(
            label: option.label,
            selected: option.id == _quiz.selectedOptionId,
            onTap: () => _quiz.select(option.id),
          ),
        ),
      ),
      const SizedBox(height: 14),
      if (selected != null)
        _QuizResultCard(
          eyebrow: selected.resultTitle,
          name: selected.recommendedRestaurantName ?? 'None',
          body: selected.resultBody,
          accent: selected.resultAccent,
        )
      else
        Text(
          'Select an answer above to get a suggestion.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: kTextOnPhotoMuted,
              ),
        ),
    ];
  }
}

class _QuizAnswerTile extends StatelessWidget {
  const _QuizAnswerTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusPanel),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kSurfacePanel,
            borderRadius: BorderRadius.circular(kRadiusPanel),
            border: Border.all(
              color: selected ? kAccentEmber : kHairline,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? kAccentEmber : Colors.transparent,
                  border: Border.all(
                    color: selected ? kAccentEmber : kTextOnPhotoMuted,
                  ),
                  shape: BoxShape.circle,
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: kOnAccent,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: selected ? kTextOnPhoto : kTextOnPhotoSecondary,
                        fontWeight: FontWeight.w600,
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

/// The answer: the same eyebrow-over-name stack the deck and the detail page
/// use, so the suggestion reads as a restaurant rather than as a verdict.
class _QuizResultCard extends StatelessWidget {
  const _QuizResultCard({
    required this.eyebrow,
    required this.name,
    required this.body,
    required this.accent,
  });

  final String eyebrow;
  final String name;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      accent: accent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppEyebrow(label: eyebrow, color: accent),
            const SizedBox(height: 8),
            Text(name, style: appTitleStyle(context)),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kTextOnPhotoSecondary,
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
