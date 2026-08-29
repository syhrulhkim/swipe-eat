import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_config.dart';

/// Runs the app, reporting crashes to Sentry when a DSN was built in.
///
/// With no `SENTRY_DSN` — every local run, every test, any build made without
/// the define — Sentry is never initialised and [startApp] is simply called.
/// That is the point of routing everything through here: nothing else in the
/// app has to know whether reporting is on.
///
/// The release name is left to sentry_flutter, which reads it from the bundle,
/// so it always matches the `version` in pubspec.yaml without a second copy
/// drifting out of date.
Future<void> runWithCrashReporting(FutureOr<void> Function() startApp) async {
  if (!AppConfig.hasCrashReporting) {
    await startApp();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = AppConfig.sentryDsn;
      options.environment = AppConfig.sentryEnvironment;
      // The app knows who is signed in, and none of that belongs in a crash
      // report: no emails, no IP addresses, no request bodies.
      options.sendDefaultPii = false;
    },
    appRunner: startApp,
  );
}

/// Navigator observers that turn route changes into breadcrumbs, so a crash
/// report says which screens led to it. Empty when reporting is off.
List<NavigatorObserver> crashReportingObservers() {
  return AppConfig.hasCrashReporting
      ? <NavigatorObserver>[SentryNavigatorObserver()]
      : const <NavigatorObserver>[];
}
