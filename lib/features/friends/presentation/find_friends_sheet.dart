import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../../onboarding/presentation/onboarding_steps.dart';
import '../data/contacts_reader.dart';
import '../models/friend.dart';
import '../state/friends_controller.dart';
import 'person_row.dart';

/// Opens the find-friends sheet (D145).
///
/// Onboarding asks this question once and then tells a user who matched
/// nobody that they "can add friends later from the You tab" — where, until
/// now, nothing did. This makes that sentence true.
Future<void> showFindFriendsSheet(
  BuildContext context, {
  required FriendsController friends,
  ContactsReader? readContacts,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSurfacePanel,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
    ),
    builder: (sheetContext) => FindFriendsSheet(
      friends: friends,
      readContacts: readContacts ?? readContactPhoneNumbers,
    ),
  );
}

/// The onboarding step's sequence — read, match, tick, send — on a screen the
/// user can reach whenever they like.
///
/// Deliberately **not** a shared widget extracted from `OnboardingFriendsStep`
/// (D145): that step's three states are wired to a wizard draft and its
/// Continue button, and a widget that has to serve both would answer to two
/// owners. What is shared is the part worth sharing — `FriendsController`,
/// which hashes the numbers on the way past, and the privacy line, which has
/// to read the same here as it does there (D127, D128).
class FindFriendsSheet extends StatefulWidget {
  const FindFriendsSheet({
    super.key,
    required this.friends,
    required this.readContacts,
  });

  final FriendsController friends;

  /// Injected, because `flutter test` has no contacts permission sheet (D60).
  final ContactsReader readContacts;

  @override
  State<FindFriendsSheet> createState() => _FindFriendsSheetState();
}

class _FindFriendsSheetState extends State<FindFriendsSheet> {
  List<FriendProfile> _matches = const [];
  final Set<String> _selected = {};
  bool _searched = false;
  bool _searching = false;
  bool _sending = false;
  String? _error;

  /// Reads the address book, hashes what it finds, and asks the server which
  /// of those hashes it knows. The raw numbers never leave this method: the
  /// controller takes them and hashes them itself.
  ///
  /// A refusal at the permission sheet arrives as an empty list, which paints
  /// the same screen as "nobody matched" — being told you have no friends
  /// here because you said no would be a strange thing to read.
  Future<void> _find() async {
    if (_searching) {
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final numbers = await widget.readContacts();
      final matches = await widget.friends.matchContacts(numbers);
      if (!mounted) {
        return;
      }
      setState(() {
        _matches = matches;
        _searched = true;
        _searching = false;
        // Everybody who matched starts ticked: these are people already in
        // the user's phone, so this is a chance to take some off rather than
        // a form to fill in. The same choice onboarding makes.
        _selected
          ..clear()
          ..addAll(matches.map((person) => person.id));
      });
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searching = false;
        _error = 'Could not check your contacts. Try again in a moment.';
      });
    }
  }

  Future<void> _send() async {
    if (_sending || _selected.isEmpty) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      // Partial failure is already this call's contract: it returns how many
      // landed rather than throwing on the first one that did not.
      final sent = await widget.friends.sendRequests(_selected);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      final people = sent == 1 ? 'request' : 'requests';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$sent $people sent.')),
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sending = false;
        _error = 'Could not send those requests. Try again in a moment.';
      });
    }
  }

  String get _lede {
    if (!_searched) {
      return 'We can check which of your contacts are already here. '
          'Optional, always.';
    }
    if (_matches.isEmpty) {
      return 'Nobody in your contacts is on Ngap yet. Nothing is kept, so '
          'checking again later costs nothing.';
    }
    final count = _matches.length;
    final are = count == 1 ? 'is' : 'are';
    final contact = count == 1 ? 'contact' : 'contacts';
    return '$count of your $contact $are already on Ngap.';
  }

  @override
  Widget build(BuildContext context) {
    final failure = _error;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          0,
          AppSpacing.screenPadding,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Find friends', style: appTitleStyle(context)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _lede,
              style: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeSmall,
                color: kCreamSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!_searched)
              AppPrimaryButton(
                label: _searching ? 'Checking...' : 'Find friends from contacts',
                icon: Icons.contacts_rounded,
                expand: true,
                onPressed: _searching ? null : () => unawaited(_find()),
              ),
            if (failure != null) ...[
              Text(
                failure,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kAccentEmber,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (_matches.isNotEmpty) ...[
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    for (final person in _matches)
                      PersonRow(
                        key: ValueKey('match:${person.id}'),
                        profile: person,
                        selected: _selected.contains(person.id),
                        onTap: () => setState(() {
                          if (!_selected.remove(person.id)) {
                            _selected.add(person.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppPrimaryButton(
                label: _sending
                    ? 'Sending...'
                    : _selected.isEmpty
                        ? 'Nobody ticked'
                        : 'Send ${_selected.length} '
                            '${_selected.length == 1 ? 'request' : 'requests'}',
                expand: true,
                onPressed:
                    _sending || _selected.isEmpty ? null : () => unawaited(_send()),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            // Verbatim from the onboarding step, because a privacy promise
            // that is worded two ways is two promises (D127, D128).
            const Text(
              OnboardingFriendsStep.privacyLine,
              style: TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeMicro,
                color: kCreamSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
