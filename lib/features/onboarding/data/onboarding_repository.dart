import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/single_row.dart';
import '../../auth/models/app_user.dart';
import '../models/onboarding_draft.dart';
import '../models/taste_option.dart';

class OnboardingRepository {
  OnboardingRepository({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// Resolved per call rather than in the constructor: the wizard is built by
  /// the router, so constructing it must not assert on an uninitialised
  /// `Supabase.instance` — the failure belongs to the request, where it can be
  /// caught and retried, not to the page's existence.
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  static const _timeout = Duration(seconds: 15);

  /// Loads both pick lists. They are independent selects, so they go out
  /// together — the wizard cannot render step 2 until both are in.
  Future<TasteCatalog> loadCatalog() async {
    final results = await Future.wait([
      _client
          .from('cuisines')
          .select('id, slug, label, emoji')
          .eq('is_active', true)
          .order('position')
          .timeout(_timeout),
      _client
          .from('dietary_tags')
          .select('id, slug, label')
          .order('position')
          .timeout(_timeout),
    ]);

    return TasteCatalog(
      cuisines: results[0].map(TasteOption.fromJson).toList(),
      dietaryTags: results[1].map(TasteOption.fromJson).toList(),
    );
  }

  /// Writes the whole wizard in one transactional RPC and returns the profile
  /// it produced, so the caller can update the session without a second read.
  Future<AppUser> complete(OnboardingDraft draft) async {
    final response = await _client
        .rpc<dynamic>('complete_onboarding', params: draft.toRpcParams())
        .timeout(_timeout);

    return AppUser.fromProfile(
      asSingleRow(response),
      authUser: _client.auth.currentUser,
    );
  }
}
