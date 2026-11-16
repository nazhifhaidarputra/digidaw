import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/timeline_state.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/utils/clip_time_utils.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/core/widgets/rename_dialog.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/features/source/view/audio_properties_screen.dart';
import 'package:karbeat/features/track/view/clip_properties_dialog.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Actions for timeline items, split so each surface can order them: a
/// context menu lists [other] first and ends with [edit]; the quick action
/// panel leads with [edit].
typedef TimelineItemActions = ({
  /// Clipboard, duplicate and delete actions; delete comes last.
  List<DawContextAction> edit,

  /// Every other action.
  List<DawContextAction> other,
});

extension TimelineItemActionsOrder on TimelineItemActions {
  /// Order for a right-click menu: naming and navigation first, delete last.
  List<DawContextAction> get forContextMenu => [...other, ...edit];

  /// Order for the quick action panel: the clipboard and delete first, so they
  /// stay on the bar when the rest move behind "More…".
  List<DawContextAction> get forQuickMenu => [...edit, ...other];
}

/// Opens the pattern of a MIDI clip on [trackId] in the piano roll.
void openClipInPianoRoll(WidgetRef ref, int trackId, UiClip clip) {
  final patternId = switch (clip.source) {
    UiClipSource_Midi(:final patternId) => patternId,
    _ => null,
  };
  if (patternId == null) return;
  final generatorId = ref
      .read(projectProvider)
      .value
      ?.tracks[trackId]
      ?.generatorId;
  ref
      .read(trackListStateProvider.notifier)
      .selectClip(trackId: trackId, clipId: clip.id);
  ref
      .read(pianoRollProvider.notifier)
      .openPattern(patternId, previewGeneratorId: generatorId);
  ref.read(workspaceStateProvider.notifier).openPattern(patternId);
}

/// Opens the audio properties of the source an audio clip plays.
void openClipAudioProperties(
  BuildContext context,
  WidgetRef ref,
  int trackId,
  UiClip clip,
) {
  final sourceId = switch (clip.source) {
    UiClipSource_Audio(:final sourceId) => sourceId,
    _ => null,
  };
  if (sourceId == null) return;
  ref
      .read(trackListStateProvider.notifier)
      .selectClip(trackId: trackId, clipId: clip.id);
  final sourceName =
      ref.read(audioSourcesProvider).value?[sourceId]?.name ?? clip.name;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          AudioPropertiesScreen(sourceId: sourceId, sourceName: sourceName),
    ),
  );
}

/// Opens what a clip plays: the piano roll for a pattern, the audio
/// properties for an audio source.
void openClipParent(
  BuildContext context,
  WidgetRef ref,
  int trackId,
  UiClip clip,
) {
  switch (clip.source) {
    case UiClipSource_Midi():
      openClipInPianoRoll(ref, trackId, clip);
    case UiClipSource_Audio():
      openClipAudioProperties(context, ref, trackId, clip);
    case UiClipSource_None():
      break;
  }
}

/// Shows the clip information dialog of [clip].
void openClipInformation(
  BuildContext context,
  WidgetRef ref,
  int trackId,
  UiClip clip,
) {
  ref
      .read(trackListStateProvider.notifier)
      .selectClip(trackId: trackId, clipId: clip.id);
  showClipPropertiesDialog(
    context,
    trackId: trackId,
    clipId: clip.id,
    onGoToParent: () {
      if (context.mounted) openClipParent(context, ref, trackId, clip);
    },
  );
}

/// The clips a clip action works on: the selection of [trackId] when it holds
/// [clipId], else the clip alone.
List<int> clipActionTargets(WidgetRef ref, int trackId, int clipId) {
  final selected = ref.read(trackListStateProvider).clipsSelectedOn(trackId);
  return selected.contains(clipId) ? selected.toList() : [clipId];
}

/// Asks for a new name for [clip] and renames it.
Future<void> renameClipWithDialog(
  BuildContext context,
  WidgetRef ref,
  int trackId,
  UiClip clip,
) async {
  final name = await showRenameDialog(
    context,
    title: tr('track-rename-clip'),
    label: tr('track-new-clip-name'),
    currentName: clip.name,
  );
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == clip.name) return;
  await ref
      .read(trackListStateProvider.notifier)
      .renameClip(trackId, clip.id, trimmed);
}

/// Every action for [clip] on [trackId]. Batch actions apply to the selection
/// of the track when it holds the clip, else to the clip alone.
TimelineItemActions clipActions({
  required BuildContext context,
  required WidgetRef ref,
  required int trackId,
  required UiClip clip,
}) {
  final targets = clipActionTargets(ref, trackId, clip.id);
  final single = targets.length == 1;
  final trackList = ref.read(trackListStateProvider.notifier);
  final colors = Theme.of(context).colorScheme;
  final envelopeView = ref.read(workspaceStateProvider).clipEnvelopeView;

  /// Makes the targets the selection, for actions that work on it.
  void selectTargets() =>
      trackList.selectClips(trackId: trackId, clipIds: targets);

  DawContextAction envelopeViewAction(
    ClipEnvelopeView view,
    String title,
    IconData icon,
  ) {
    final shown = envelopeView == view;
    return DawContextAction(
      title: title,
      icon: shown ? Icons.check : icon,
      color: shown ? colors.primary : null,
      onTap: () => ref
          .read(workspaceStateProvider.notifier)
          .toggleClipEnvelopeView(view),
    );
  }

  return (
    edit: [
      DawContextAction(
        title: tr('track-copy'),
        icon: Icons.copy,
        onTap: () =>
            trackList.copySelectedClips(trackId: trackId, clipIds: targets),
      ),
      DawContextAction(
        title: tr('track-cut'),
        icon: Icons.cut,
        onTap: () async {
          await trackList.cutSelectedClips(trackId: trackId, clipIds: targets);
          trackList.deselectAllClips();
        },
      ),
      DawContextAction(
        title: tr('track-duplicate'),
        icon: Icons.control_point_duplicate,
        onTap: () {
          selectTargets();
          trackList.duplicateSelectedClips();
        },
      ),
      DawContextAction(
        title: tr('common-delete'),
        icon: Icons.delete,
        isDestructive: true,
        onTap: () async {
          await trackList.deleteClipBatch(trackId, targets);
          trackList.deselectAllClips();
        },
      ),
    ],
    other: [
      if (single)
        DawContextAction(
          title: tr('common-rename'),
          icon: Icons.edit,
          onTap: () => renameClipWithDialog(context, ref, trackId, clip),
        ),
      if (single && clip.source is! UiClipSource_None)
        DawContextAction(
          title: tr('track-go-to-clip-information'),
          icon: Icons.info_outline,
          onTap: () => openClipInformation(context, ref, trackId, clip),
        ),
      if (single && clip.source is UiClipSource_Midi)
        DawContextAction(
          title: tr('track-go-to-piano-roll'),
          icon: Icons.piano,
          onTap: () => openClipInPianoRoll(ref, trackId, clip),
        ),
      if (single && clip.source is UiClipSource_Audio)
        DawContextAction(
          title: tr('track-go-to-audio-properties'),
          icon: Icons.audio_file,
          onTap: () => openClipAudioProperties(context, ref, trackId, clip),
        ),
      DawContextAction(
        title: single
            ? tr('track-loop-to-clip')
            : tr('track-loop-to-selection'),
        icon: Icons.loop,
        onTap: () => _loopToClips(ref, trackId, targets),
      ),
      if (clip.source is! UiClipSource_None)
        DawContextAction(
          title: tr('track-make-unique'),
          icon: Icons.call_split,
          onTap: () =>
              trackList.makeClipsUnique(trackId: trackId, clipIds: targets),
        ),
      DawContextAction(
        title: tr('track-quantize-clips'),
        icon: Icons.grid_on,
        onTap: () {
          selectTargets();
          trackList.quantizeSelectedClips(
            ref.read(workspaceStateProvider).gridSize,
          );
        },
      ),
      DawContextAction(
        title: tr('track-quantize-clip-starts'),
        icon: Icons.start,
        onTap: () {
          selectTargets();
          trackList.quantizeSelectedClipStarts(
            ref.read(workspaceStateProvider).gridSize,
          );
        },
      ),
      if (!single)
        DawContextAction(
          title: tr('track-legato-clips'),
          icon: Icons.linear_scale,
          onTap: () {
            selectTargets();
            trackList.legatoSelectedClips();
          },
        ),
      if (clip.source is UiClipSource_Audio) ...[
        envelopeViewAction(
          ClipEnvelopeView.waveform,
          tr('track-show-waveform-envelope'),
          Icons.graphic_eq,
        ),
        envelopeViewAction(
          ClipEnvelopeView.clip,
          tr('track-show-clip-envelope'),
          Icons.show_chart,
        ),
      ],
    ],
  );
}

/// Sets the loop region to span [clipIds] of [trackId].
Future<void> _loopToClips(WidgetRef ref, int trackId, List<int> clipIds) async {
  final clips = ref.read(projectProvider).value?.tracks[trackId]?.clips;
  if (clips == null) return;
  final transport = ref.read(transportProvider).value;
  final bpm = transport?.state?.bpm ?? 120.0;
  final sampleRate = transport?.sampleRate ?? 48000;
  final spans = [
    for (final clip in clips)
      if (clipIds.contains(clip.id))
        (
          clip.startTimeInTicks,
          clip.startTimeInTicks + clip.loopLengthInTicks(bpm, sampleRate),
        ),
  ];
  if (spans.isEmpty) return;
  final start = spans.map((span) => span.$1).reduce(math.min);
  final end = spans.map((span) => span.$2).reduce(math.max);
  if (end <= start) return;
  await ref.read(timelineProvider.notifier).setLoopRegion(start, end);
}

/// Sets the loop region to span the whole timeline selection.
Future<void> loopToSelection(WidgetRef ref) async {
  final spans = ref.read(trackListStateProvider.notifier).selectionSpans();
  if (spans.isEmpty) return;
  final start = spans.map((span) => span.$1).reduce(math.min);
  final end = spans.map((span) => span.$2).reduce(math.max);
  if (end <= start) return;
  await ref.read(timelineProvider.notifier).setLoopRegion(start, end);
}
