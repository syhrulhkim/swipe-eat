import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/design_tokens.dart';
import '../../auth/state/auth_controller.dart';
import '../../plans/presentation/calendar_tab.dart';
import '../../plans/state/plans_controller.dart';
import '../../profile/presentation/profile_tab.dart';
import '../../restaurants/data/likes_migration.dart';
import '../../restaurants/data/visit_prompt_cache.dart';
import '../../nearby/presentation/nearby_tab.dart';
import '../../restaurants/presentation/swipe_deck.dart';
import '../../restaurants/presentation/visit_prompt_sheet.dart';
import '../../restaurants/state/deck_handoff.dart';
import '../../restaurants/state/likes_controller.dart';
import '../../restaurants/state/visit_prompt_controller.dart';
import '../state/dashboard_tab_request.dart';
import 'dashboard_bottom_nav.dart';
import 'likes_tab.dart';

/// The signed-in home: five tabs behind one bottom bar.
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.authController,
    this.handoff,
    this.visitPrompts,
    this.tabRequests,
    this.plans,
  });

  final AuthController authController;

  /// Which deck hand-off to listen to, and which the map publishes to and the
  /// deck deals from. Defaults to the shared instance; injecting one wires all
  /// three sides to a test's own.
  final DeckHandoff? handoff;

  /// Injected by tests; in the app the shared instance is used.
  final VisitPromptController? visitPrompts;

  /// Which tab-switch requests to listen to. Defaults to the shared instance.
  final DashboardTabRequest? tabRequests;

  /// The plans cache the You tab's figures and the Bites chips read.
  final PlansController? plans;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authController,
      builder: (context, _) => _DashboardShell(
        authController: authController,
        handoff: handoff,
        visitPrompts: visitPrompts,
        tabRequests: tabRequests,
        plans: plans,
      ),
    );
  }
}

class _DashboardShell extends StatefulWidget {
  const _DashboardShell({
    required this.authController,
    this.handoff,
    this.visitPrompts,
    this.tabRequests,
    this.plans,
  });

  final AuthController authController;
  final DeckHandoff? handoff;
  final VisitPromptController? visitPrompts;
  final DashboardTabRequest? tabRequests;
  final PlansController? plans;

  @override
  State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;

  late final VisitPromptController _visitPrompts =
      widget.visitPrompts ?? VisitPromptController.instance;


  late final DeckHandoff _handoff = widget.handoff ?? DeckHandoff.instance;
  late int _handoffRevision = _handoff.revision;

  late final DashboardTabRequest _tabRequests =
      widget.tabRequests ?? DashboardTabRequest.instance;

  /// The revision this shell has already acted on, so a rebuild cannot drag
  /// the user back to a tab they have since left. Seeded eagerly in
  /// `initState`: a `late` initialiser would not run until the first request
  /// arrived, by which time the revision has already moved and the very first
  /// request would compare equal and be dropped.
  int _tabRequestRevision = 0;

  late final PlansController _plans = widget.plans ?? PlansController.instance;

  /// The hand-off revision this shell has already reacted to, so a rebuild
  /// cannot pull the user back to the deck they just navigated away from.

  /// One question at a time. The prompt is triggered from two places that can
  /// both fire around a resume, and two sheets over each other would be a bug
  /// the user has to dismiss twice.
  bool _askingAboutVisit = false;

  /// Fades the newly selected tab in. Starts completed so the first tab is
  /// simply there — the dashboard has just crossfaded in from the splash, and
  /// a second fade on top of that reads as a stutter.
  ///
  /// One shot per selection: the tabs are all mounted at once behind an
  /// IndexedStack, so anything that kept running would animate a resting
  /// screen.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: kMotionDuration,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabRequestRevision = _tabRequests.revision;
    _handoff.addListener(_onHandoff);
    _tabRequests.addListener(_onTabRequested);
    _plans.addListener(_onPlansChanged);
    // The calendar feeds four surfaces that are not the calendar — the Bites
    // chips, the Bites tiles, the wishlist rows and the You tab's figures — so
    // it loads with the dashboard rather than waiting for tab 3 to be opened.
    unawaited(_plans.ensureLoaded().catchError((Object error) {
      debugPrint('Plans load failed: $error');
    }));
    // One-time move of pre-auth device likes into the swipes table. Never
    // blocks the dashboard; a failed run retries on the next launch.
    unawaited(migrateDeviceLikes().then((migrated) {
      if (migrated) {
        LikesController.instance.refresh().catchError((Object error) {
          debugPrint('Post-migration likes refresh failed: $error');
        });
      }
    }));
    // A cold launch is the other way back into the app; the lifecycle callback
    // below only fires for a resume. After the first frame, so the sheet has a
    // laid-out route to open over.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeAskAboutVisit());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _handoff.removeListener(_onHandoff);
    _tabRequests.removeListener(_onTabRequested);
    _plans.removeListener(_onPlansChanged);
    _tabFade.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Coming back from the maps app lands here. The cache's own age rule
    // decides whether enough time has passed to be worth asking.
    if (state == AppLifecycleState.resumed) {
      unawaited(_maybeAskAboutVisit());
    }
  }

  /// Asks about the most recent place the app sent the user to, if one is ripe.
  ///
  /// Silent about everything except a failed write: there is no error worth
  /// interrupting a launch for when the app merely could not think of a
  /// question to ask.
  Future<void> _maybeAskAboutVisit() async {
    if (_askingAboutVisit) {
      return;
    }
    _askingAboutVisit = true;

    try {
      final pending = await _visitPrompts.next();
      if (pending == null || !mounted) {
        return;
      }

      // Not while a restaurant page or a sheet is on top: the question would
      // arrive over something the user is in the middle of.
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) {
        return;
      }

      final answer = await showVisitPromptSheet(context, visit: pending);
      if (answer == null || !mounted) {
        // Dismissed without answering: the trip stays pending and the question
        // comes back next time.
        return;
      }

      await _recordVisitAnswer(pending, answer);
    } finally {
      _askingAboutVisit = false;
    }
  }

  Future<void> _recordVisitAnswer(
    PendingVisit pending,
    VisitAnswer answer,
  ) async {
    try {
      if (answer == VisitAnswer.went) {
        await _visitPrompts.confirm(pending);
      } else {
        await _visitPrompts.dismiss(pending);
      }
      // No refresh of the Liked tab's Visited segment: it loads lazily, so an
      // unopened one already fetches this visit on its first open. One the user
      // has opened this run stays as it was until they pull to refresh — the
      // same launch-snapshot behaviour the IndexedStack gives every tab.
    } on Object catch (error) {
      // The cache is only cleared after the write lands, so the question
      // survives to be asked again.
      debugPrint('Visit answer failed: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark that place visited.')),
      );
      return;
    }

    if (!mounted || answer != VisitAnswer.went) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${pending.name} marked as visited.')),
    );
  }

  /// "Swipe all N" on the map: the deck deals the handed-over list itself
  /// (see [DeckController]); the only thing left is to bring it forward.
  void _onHandoff() {
    if (_handoff.revision == _handoffRevision) {
      return;
    }
    _handoffRevision = _handoff.revision;
    _setSelectedIndex(0);
  }

  /// The Calendar tab's "New plan", and the landing after "Lock it in".
  void _onTabRequested() {
    if (_tabRequests.revision == _tabRequestRevision) {
      return;
    }
    _tabRequestRevision = _tabRequests.revision;
    _setSelectedIndex(_tabRequests.index);
  }

  void _onPlansChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setSelectedIndex(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
    _tabFade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      bottomNavigationBar: DashboardBottomNav(
        selectedIndex: _selectedIndex,
        onSelected: _setSelectedIndex,
      ),
      // An IndexedStack, not a swap: rebuilding a tab on every visit would
      // re-deal the deck and refetch the map each time the user glanced at
      // another tab. The switch itself is instant, so the fade below is what
      // makes it read as a change of screen rather than as a repaint.
      // No ScreenGlow here: Bites, Calendar and You paint their own, and a
      // second one underneath doubled the ember on those three tabs.
      body: Stack(
        children: [
          FadeTransition(
            opacity: CurvedAnimation(parent: _tabFade, curve: kMotionEase),
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                SwipeDeck(
                  authController: widget.authController,
                  handoff: widget.handoff,
                  // Every tab stays mounted behind the IndexedStack, so the
                  // deck has to be told when it is no longer the one on
                  // screen — otherwise an unmuted clip plays on from behind
                  // the map.
                  isActive: _selectedIndex == 0,
                ),
                NearbyTab(
                  authController: widget.authController,
                  handoff: widget.handoff,
                ),
                LikesTab(plans: _plans),
                CalendarTab(controller: _plans, tabRequests: _tabRequests),
                ProfileTab(
                  authController: widget.authController,
                  stats: ProfileStats(
                    plansKept: _plans.stats.plansKept,
                    streakWeeks: _plans.stats.streakWeeks,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
