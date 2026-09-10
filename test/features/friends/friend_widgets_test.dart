import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe_eat/core/ui/design_tokens.dart';
import 'package:swipe_eat/features/friends/presentation/friend_avatar.dart';
import 'package:swipe_eat/features/friends/presentation/person_row.dart';

import '../../support/widget_test_support.dart';
import 'fake_friends_repository.dart';

const Size _phoneViewport = Size(390, 844);
const Size _narrowViewport = Size(320, 568);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size viewport = _phoneViewport,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  useViewport(tester, viewport);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: inner!,
      ),
      home: Scaffold(
        backgroundColor: kSurfaceDark,
        body: Center(child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => HttpOverrides.global = ImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  group('FriendAvatar', () {
    testWidgets('a friend with no photo wears their initials', (tester) async {
      await _pump(
        tester,
        FriendAvatar(profile: testFriend('a', name: 'Mei Kee Tan'), size: 44),
      );

      expect(find.text('MK'), findsOneWidget);
    });

    testWidgets('a friend with a photo wears the photo, not letters',
        (tester) async {
      await _pump(
        tester,
        FriendAvatar(
          profile: testFriend(
            'a',
            name: 'Mei Kee Tan',
            avatarUrl: 'https://example.test/mei.jpg',
          ),
          size: 44,
        ),
      );

      expect(find.text('MK'), findsNothing);
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(FriendAvatar),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.image, isNotNull);
    });

    testWidgets('initials keep their size when the system text does not',
        (tester) async {
      // The avatar is a fixed circle. Letting its two letters grow with the
      // system scale makes them spill out of it rather than say more.
      await _pump(
        tester,
        FriendAvatar(profile: testFriend('a', name: 'Aiman'), size: 32),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text('AI'));
      expect(text.textScaler, TextScaler.noScaling);
    });

    testWidgets('the same person always gets the same ground', (tester) async {
      // A face that changes colour between screens reads as a different
      // person, so the ground is a function of the id and nothing else.
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FriendAvatar(
                profile: testFriend('same-id', name: 'Aiman'), size: 32),
            FriendAvatar(
                profile: testFriend('same-id', name: 'Aiman'), size: 32),
          ],
        ),
      );

      final grounds = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(FriendAvatar),
              matching: find.byType(Container),
            ),
          )
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toSet();
      expect(grounds.length, 1);
    });
  });

  group('FriendAvatarStack', () {
    testWidgets('shows at most the cap, however many are passed',
        (tester) async {
      await _pump(
        tester,
        FriendAvatarStack(
          people: [
            for (var i = 0; i < 9; i++) testFriend('f$i', name: 'Friend $i'),
          ],
          size: kAvatarSizeCompact,
        ),
      );

      expect(find.byType(FriendAvatar), findsNWidgets(kAvatarStackMax));
    });

    testWidgets('says nothing to a screen reader', (tester) async {
      // The caption beside a stack already names the people. Reading three
      // sets of initials first is noise in front of the sentence.
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Row(
          children: [
            FriendAvatarStack(
              people: [
                testFriend('a', name: 'Aiman'),
                testFriend('b', name: 'Mei Kee'),
              ],
              size: kAvatarSizeCompact,
            ),
            const Expanded(child: Text('Aiman, Mei Kee and 4 friends')),
          ],
        ),
      );

      expect(find.bySemanticsLabel('AA'), findsNothing);
      expect(
        find.bySemanticsLabel('Aiman, Mei Kee and 4 friends'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('an empty stack draws nothing at all', (tester) async {
      await _pump(
        tester,
        const FriendAvatarStack(people: [], size: kAvatarSizeCompact),
      );

      expect(find.byType(FriendAvatar), findsNothing);
    });
  });

  group('PersonRow as a choice', () {
    testWidgets('reads as a button that knows whether it is picked',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        PersonRow(
          profile: testFriend('a', name: 'Aiman Zulkifli'),
          subtitle: '142 bites · Bangsar',
          selected: true,
          onTap: () {},
        ),
      );

      expect(
        tester.getSemantics(find.byType(PersonRow)),
        matchesSemantics(
          label: 'Aiman Zulkifli',
          value: '142 bites · Bangsar',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('excluding the texts does not cost it its tap (D83)',
        (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pump(
        tester,
        PersonRow(
          profile: testFriend('a', name: 'Aiman'),
          selected: false,
          onTap: () => taps++,
        ),
      );

      final node = tester.getSemantics(find.byType(PersonRow));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(find.byType(PersonRow));
      await tester.pumpAndSettle();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('a row with no subtitle offers no empty second line',
        (tester) async {
      await _pump(
        tester,
        PersonRow(
          profile: testFriend('a', name: 'Aiman'),
          selected: false,
          onTap: () {},
        ),
      );

      expect(find.text('Aiman'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PersonRow),
          matching: find.byType(Text),
        ),
        // The name, plus the avatar's one initial.
        findsNWidgets(2),
      );
    });
  });

  group('PersonRow with buttons on it', () {
    testWidgets('keeps its buttons in the tree', (tester) async {
      // The bug this exists to stop: excluding the row's semantics used to be
      // unconditional, which swallowed Accept and Decline whole and left a
      // screen reader with a name and nothing to do about it.
      final handle = tester.ensureSemantics();
      var accepted = 0;
      await _pump(
        tester,
        PersonRow(
          profile: testFriend('a', name: 'Aiman'),
          subtitle: 'Wants to be friends',
          selected: false,
          onTap: () {},
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: 'Accept Aiman',
                excludeSemantics: true,
                onTap: () => accepted++,
                child: GestureDetector(
                  onTap: () => accepted++,
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.bySemanticsLabel('Accept Aiman'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Accept Aiman'));
      await tester.pumpAndSettle();
      expect(accepted, 1);
      handle.dispose();
    });

    testWidgets('the row itself stops being a target', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        PersonRow(
          profile: testFriend('a', name: 'Aiman'),
          selected: false,
          onTap: () => taps++,
          trailing: const Text('Going'),
        ),
      );

      await tester.tap(find.text('Aiman'));
      await tester.pumpAndSettle();
      expect(taps, 0);
    });
  });

  group('narrow and large', () {
    testWidgets('a person row survives 320 pt at double text', (tester) async {
      await _pump(
        tester,
        PersonRow(
          profile: testFriend('a', name: 'Nurul Ain Binti Abdullah'),
          subtitle: 'Ngap\'d Kak Ros Nasi Kandar too',
          selected: true,
          onTap: () {},
        ),
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Nurul Ain Binti Abdullah'), findsOneWidget);
    });

    testWidgets('so does a full stack', (tester) async {
      await _pump(
        tester,
        FriendAvatarStack(
          people: [
            for (var i = 0; i < 5; i++) testFriend('f$i', name: 'Friend $i'),
          ],
          size: kAvatarSize,
        ),
        viewport: _narrowViewport,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
