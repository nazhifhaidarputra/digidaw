// ============================================================
// Global Stream Providers (The FFI Pipeline)
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/src/rust/api/audio.dart';

final masterAudioFeedbackProvider = StreamProvider<UiAudioFeedback>((ref) async* {
  // Ensure the project provider has finished booting and creating the context
  final ctx = ref.watch(projectProvider.notifier).dawContext;

  // Yield the stream directly from FRB
  yield* createFeedbackStream(ctx: ctx);
});
