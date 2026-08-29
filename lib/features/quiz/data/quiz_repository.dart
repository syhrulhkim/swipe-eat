import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quiz_question.dart';

class QuizRepository {
  QuizRepository({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// Lazy for the same reason as [RestaurantRepository]: construction must not
  /// assert on an uninitialised `Supabase.instance`.
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  Future<QuizQuestion?> fetchActiveQuestion() async {
    // Order by position with id as a deterministic tie-breaker; time out so a
    // stalled connection surfaces as an error instead of an endless spinner.
    final rows = await _client
        .from('quiz_questions')
        .select('id, prompt, quiz_options(id, label, position, result_title, '
            'result_body, result_accent, recommended:restaurants(name))')
        .eq('is_active', true)
        .order('position', ascending: true)
        .order('id', ascending: true)
        .limit(1)
        .timeout(const Duration(seconds: 15));

    if (rows.isEmpty) {
      return null;
    }

    return QuizQuestion.fromJson(rows.first);
  }
}
