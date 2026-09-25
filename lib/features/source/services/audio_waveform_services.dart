import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/src/rust/api/audio.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/waveform.dart';

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

/// Handle to one source's decoded buffer for the audio properties waveform.
///
/// The handle keeps the whole decoded buffer alive in Rust, so it is disposed
/// with this provider instead of waiting for GC, and refreshed when a full
/// backend fetch may have replaced the buffer.
final audioWaveformHandleProvider = Provider.autoDispose
    .family<WaveformHandle?, int>((ref, sourceId) {
      ref.watch(projectProvider.select((s) => s.value?.fullStateRevision));
      final ctx = ref.read(projectProvider.notifier).dawContext;
      final handle = getWaveformHandle(ctx: ctx, sourceId: sourceId);
      if (handle != null) ref.onDispose(handle.dispose);
      return handle;
    });
