import 'package:flutter/foundation.dart';

import '../data/quiz_repository.dart';
import '../models/quiz_question.dart';

/// The active quiz question and which answer the user picked.
class QuizController extends ChangeNotifier {
  QuizController({QuizRepository? repository})
      : _repository = repository ?? QuizRepository();

  final QuizRepository _repository;

  QuizQuestion? _question;
  QuizQuestion? get question => _question;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  int _selectedOptionId = -1;
  int get selectedOptionId => _selectedOptionId;

  /// The picked answer, or null while none is picked — this is what turns the
  /// result card on.
  QuizOption? get selectedOption {
    final options = _question?.options;
    if (options == null) {
      return null;
    }
    for (final option in options) {
      if (option.id == _selectedOptionId) {
        return option;
      }
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _question = await _repository.fetchActiveQuestion();
      _loading = false;
      notifyListeners();
    } on Object catch (error) {
      debugPrint('Quiz load failed: $error');
      _loading = false;
      _error = 'Could not load the quiz.';
      notifyListeners();
    }
  }

  void select(int optionId) {
    if (_selectedOptionId == optionId) {
      return;
    }
    _selectedOptionId = optionId;
    notifyListeners();
  }
}
