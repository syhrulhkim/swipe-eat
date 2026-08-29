import 'package:swipe_eat/features/auth/models/app_user.dart';
import 'package:swipe_eat/features/onboarding/data/onboarding_repository.dart';
import 'package:swipe_eat/features/onboarding/models/onboarding_draft.dart';
import 'package:swipe_eat/features/onboarding/models/taste_option.dart';

/// Captures the RPC payload the wizard would send, so tests can assert on what
/// reaches the database rather than on the widgets that produced it.
class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({TasteCatalog? catalog})
      : catalog = catalog ??
            const TasteCatalog(
              cuisines: [
                TasteOption(id: 1, slug: 'malay', label: 'Malay', emoji: '🍛'),
                TasteOption(id: 2, slug: 'cafe', label: 'Cafe', emoji: '☕'),
              ],
              dietaryTags: [
                TasteOption(id: 7, slug: 'halal', label: 'Halal'),
              ],
            );

  final TasteCatalog catalog;

  bool failCatalog = false;
  bool failComplete = false;

  /// The parameter map from the last [complete] call.
  Map<String, dynamic>? sentParams;
  int completeCalls = 0;

  @override
  Future<TasteCatalog> loadCatalog() async {
    if (failCatalog) {
      throw Exception('offline');
    }
    return catalog;
  }

  @override
  Future<AppUser> complete(OnboardingDraft draft) async {
    completeCalls++;
    sentParams = draft.toRpcParams();
    if (failComplete) {
      throw Exception('write failed');
    }
    return AppUser(
      id: '39c39a30-c8fb-4e08-8e13-c90212f68e59',
      name: draft.name,
      email: 'demo@swipeeat.test',
      onboardedAt: DateTime(2026, 8, 23),
    );
  }
}
