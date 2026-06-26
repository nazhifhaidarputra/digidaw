import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/src/rust/api/audio.dart';
import 'package:karbeat/src/rust/api/project.dart';

final audioSourcesProvider = FutureProvider.autoDispose<Map<int, AudioWaveformUiForSourceList>>((ref) async {
  // 1. Wait for DAW context to be ready
  final ctx = ref.watch(projectProvider.notifier).dawContext;

  // 2. Direct FFI call instead of routing through monolithic state
  final result = await getAudioSourceList(ctx: ctx); 
  
  return result ?? {};
});

  final audioPropertiesProvider = FutureProvider.autoDispose
      .family<AudioWaveformUiForAudioProperties, int>((ref, sourceId) async {
        
        final ctx = ref.read(projectProvider.notifier).dawContext;
        final result = await getAudioProperties(ctx: ctx, id: sourceId);

        if (result == null) {
          throw Exception("Failed to load audio properties");
        }

        return result;
      });