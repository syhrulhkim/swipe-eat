import 'dart:ui';

import '../../../core/ui/hex_color.dart';

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final options = (json['quiz_options'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(QuizOption.fromJson)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return QuizQuestion(
      id: (json['id'] as num).toInt(),
      prompt: json['prompt'] as String? ?? '',
      options: options,
    );
  }

  final int id;
  final String prompt;
  final List<QuizOption> options;
}

class QuizOption {
  const QuizOption({
    required this.id,
    required this.label,
    required this.position,
    required this.resultTitle,
    required this.resultBody,
    required this.resultAccent,
    this.recommendedRestaurantName,
  });

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    final recommended = json['recommended'] as Map<String, dynamic>?;

    return QuizOption(
      id: (json['id'] as num).toInt(),
      label: json['label'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      resultTitle: json['result_title'] as String? ?? '',
      resultBody: json['result_body'] as String? ?? '',
      resultAccent: parseHexColor(
        json['result_accent'] as String?,
        fallback: const Color(0xFFB7E4C7),
      ),
      recommendedRestaurantName: recommended?['name'] as String?,
    );
  }

  final int id;
  final String label;
  final int position;
  final String resultTitle;
  final String resultBody;
  final Color resultAccent;
  final String? recommendedRestaurantName;
}
