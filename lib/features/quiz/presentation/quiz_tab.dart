import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/glass_ui.dart';
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
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ];
    }

    final error = _quiz.error;
    if (error != null) {
      return [
        EmptyTabMessage(
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
          title: 'No quiz available',
          subtitle: 'Check back soon.',
        ),
      ];
    }

    final selected = _quiz.selectedOption;

    return [
      Text(
        question.prompt,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.64),
              height: 1.35,
            ),
      ),
      const SizedBox(height: 12),
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
          title: selected.resultTitle,
          subtitle: selected.recommendedRestaurantName ?? 'None',
          body: selected.resultBody,
          accent: selected.resultAccent,
        )
      else
        Text(
          'Select an answer above to get a suggestion.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.60),
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
    final accent =
        selected ? const Color(0xFFB7E4C7) : Colors.white.withValues(alpha: 0.10);

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
            color: selected
                ? accent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(kRadiusPanel),
            border: Border.all(
              color: accent.withValues(alpha: selected ? 0.42 : 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  border: Border.all(
                    color:
                        selected ? accent : Colors.white.withValues(alpha: 0.24),
                  ),
                  shape: BoxShape.circle,
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: Colors.black,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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

class _QuizResultCard extends StatelessWidget {
  const _QuizResultCard({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      accent: accent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.12,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.74),
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
