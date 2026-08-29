import 'package:flutter/material.dart';

import '../core/ui/design_tokens.dart';
import '../core/ui/lunar/sparkles.dart';
import '../core/ui/lunar/spotlight.dart';
import '../core/ui/lunar/spotlight_button.dart';
import '../core/ui/lunar/spotlight_card.dart';
import '../core/ui/lunar/star_grid.dart';

/// Standalone gallery for the Lunar UI ports.
///
/// Not part of the app: run it on its own with
/// `flutter run -t lib/dev/lunar_gallery.dart` to see the four components
/// without wiring them into a screen first.
void main() => runApp(const LunarGalleryApp());

class LunarGalleryApp extends StatelessWidget {
  const LunarGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lunar UI gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'packages/forui/Inter',
        scaffoldBackgroundColor: kBackgroundDeep,
      ),
      home: const LunarGalleryPage(),
    );
  }
}

class LunarGalleryPage extends StatelessWidget {
  const LunarGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
          children: const [
            _SectionTitle('Spotlight Card'),
            _SpotlightCardDemo(),
            SizedBox(height: 32),
            _SectionTitle('Sparkles'),
            _SparklesDemo(),
            SizedBox(height: 32),
            _SectionTitle('Star Grid'),
            _StarGridDemo(),
            SizedBox(height: 32),
            _SectionTitle('Spotlight Button'),
            _SpotlightButtonDemo(),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SpotlightCardDemo extends StatelessWidget {
  const _SpotlightCardDemo();

  @override
  Widget build(BuildContext context) {
    return SpotlightCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Download app',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Drag a finger across the card to move the light along its border.',
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          SpotlightButton(
            onPressed: () {},
            child: const Text(r'Download app  ·  $49'),
          ),
        ],
      ),
    );
  }
}

class _SparklesDemo extends StatelessWidget {
  const _SparklesDemo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: const SizedBox(
        height: 200,
        child: Sparkles(
          background: kSurfaceDark,
          density: 260,
          size: 1.6,
          speed: 12,
          child: Center(
            child: Text(
              'Sparkles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarGridDemo extends StatelessWidget {
  const _StarGridDemo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: const ColoredBox(
        color: kSurfaceDark,
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: StarGrid(),
        ),
      ),
    );
  }
}

class _SpotlightButtonDemo extends StatelessWidget {
  const _SpotlightButtonDemo();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SpotlightButton(onPressed: () {}, child: const Text('Get started')),
        SpotlightButton(
          onPressed: () {},
          from: kSpotlightFrom,
          via: kSpotlightVia,
          child: const Text('Teal to blue'),
        ),
        const SpotlightButton(child: Text('Disabled')),
      ],
    );
  }
}
