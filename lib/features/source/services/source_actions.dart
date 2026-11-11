import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/clip_placement_state.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/track.dart';

// Source actions shared by the Source screen and the track list's source
// panel, so both ask the same questions before changing the project.

/// Asks for the name a plugin generator is shown under. Leaving the field empty
/// goes back to the plugin's own name.
Future<void> renameGeneratorWithDialog(
  BuildContext context,
  WidgetRef ref,
  int generatorId,
  UiPluginInstance plugin,
) async {
  final current = plugin.displayName ?? '';
  var pendingName = current;
  final newName = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text("Rename ${plugin.name}"),
      content: TextFormField(
        initialValue: current,
        autofocus: true,
        decoration: InputDecoration(
          labelText: "Instrument name",
          helperText: "Empty shows ${plugin.name}",
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => pendingName = value,
        onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, pendingName),
          child: const Text("Rename"),
        ),
      ],
    ),
  );
  if (newName == null || newName.trim() == current) return;
  await ref
      .read(projectProvider.notifier)
      .renameGenerator(generatorId, newName.trim());
}

Future<void> renamePatternWithDialog(
  BuildContext context,
  WidgetRef ref,
  int patternId,
  String currentName,
) async {
  var pendingName = currentName;
  final newName = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Rename Pattern"),
      content: TextFormField(
        initialValue: currentName,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: "New pattern name",
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => pendingName = value,
        onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, pendingName),
          child: const Text("Rename"),
        ),
      ],
    ),
  );

  final trimmedName = newName?.trim();
  if (!context.mounted ||
      trimmedName == null ||
      trimmedName.isEmpty ||
      trimmedName == currentName) {
    return;
  }

  await ref
      .read(pianoRollProvider.notifier)
      .renamePattern(patternId: patternId, newName: trimmedName);
}

/// Number of timeline clips that play the audio source [sourceId].
int audioSourceClipCount(Iterable<UiTrack> tracks, int sourceId) => tracks
    .expand((track) => track.clips)
    .where(
      (clip) => switch (clip.source) {
        UiClipSource_Audio(sourceId: final id) => id == sourceId,
        _ => false,
      },
    )
    .length;

/// Asks before deleting an audio source, naming how many clips go with it.
Future<void> deleteAudioSourceWithConfirm(
  BuildContext context,
  WidgetRef ref,
  int sourceId,
  String name,
) async {
  final tracks =
      ref.read(projectProvider).value?.tracks.values ?? const <UiTrack>[];
  final clipCount = audioSourceClipCount(tracks, sourceId);
  final clipText = switch (clipCount) {
    0 => 'No clip on the timeline uses it.',
    1 => '1 clip that plays it will be removed from the timeline.',
    _ => '$clipCount clips that play it will be removed from the timeline.',
  };

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete audio source?'),
      content: Text(
        '“$name” will be removed from the project. $clipText\n\n'
        'The audio file on disk is not deleted, and you can undo this.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  // A placement of this source would create a clip with nothing to play.
  final placement = ref.read(clipPlacementProvider);
  if (placement.sourceType == UiSourceType.audio &&
      placement.sourceId == sourceId) {
    ref.read(clipPlacementProvider.notifier).cancelPlacement();
  }
  await ref.read(projectProvider.notifier).removeAudioSource(sourceId);
}

/// Number of timeline clips that play the MIDI pattern [patternId].
int patternClipCount(Iterable<UiTrack> tracks, int patternId) => tracks
    .expand((track) => track.clips)
    .where(
      (clip) => switch (clip.source) {
        UiClipSource_Midi(patternId: final id) => id == patternId,
        _ => false,
      },
    )
    .length;

/// Asks before deleting a pattern, naming how many clips go with it.
Future<void> deletePatternWithConfirm(
  BuildContext context,
  WidgetRef ref,
  int patternId,
  String name,
) async {
  final tracks =
      ref.read(projectProvider).value?.tracks.values ?? const <UiTrack>[];
  final clipCount = patternClipCount(tracks, patternId);
  final clipText = switch (clipCount) {
    0 => 'No clip on the timeline uses it.',
    1 => '1 clip that plays it will be removed from the timeline.',
    _ => '$clipCount clips that play it will be removed from the timeline.',
  };

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete pattern?'),
      content: Text(
        '“$name” will be removed from the project. $clipText\n\n'
        'You can undo this.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  // A placement of this pattern would create a clip with nothing to play.
  final placement = ref.read(clipPlacementProvider);
  if (placement.sourceType == UiSourceType.midi &&
      placement.sourceId == patternId) {
    ref.read(clipPlacementProvider.notifier).cancelPlacement();
  }

  // The editor would otherwise keep a pattern that no longer exists open.
  if (ref.read(pianoRollProvider).editingPatternId == patternId) {
    ref.read(pianoRollProvider.notifier).clearEditingPattern();
  }

  await ref.read(projectProvider.notifier).removePattern(patternId);
}
