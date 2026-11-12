import 'dart:async';

import 'package:karbeat/core/l10n/localizer.dart';

import 'helpers/ftl_test_localizer.dart';

/// Formats every message from the English Fluent files, so widget tests see
/// the text the app shows without loading the Rust library.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  L10n.localizer = FtlTestLocalizer();
  await testMain();
}
