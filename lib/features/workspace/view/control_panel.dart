import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/piano_roll_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/widgets/background_jobs_indicator.dart';
import 'package:karbeat/core/widgets/fine_grained_input.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/transport.dart';
import 'package:karbeat/core/utils/formatter.dart';
import 'package:karbeat/core/utils/logger.dart';

/// How much of the control dock fits the width it is given.
enum DockDensity {
  /// Large screens: every control and readout field is shown with labels.
  wide,

  /// Tablets and large phones: segments show icons, the selected view keeps
  /// its label, and the toggles sit behind "more".
  compact,

  /// Small phones: the views and tools collapse into one popover button each.
  narrow;

  /// Narrowest width that shows every control in line.
  static const double wideMinWidth = 1180;

  /// Narrowest width that fits both segments.
  static const double compactMinWidth = 720;

  static DockDensity forWidth(double width) {
    if (width >= wideMinWidth) return DockDensity.wide;
    if (width >= compactMinWidth) return DockDensity.compact;
    return DockDensity.narrow;
  }
}

/// Height of the control dock at the bottom of the workspace.
const double kControlDockHeight = 58;

/// One choice of a dock segment.
class _DockChoice<T> {
  const _DockChoice(this.value, this.icon, this.label, {this.color});

  final T value;
  final IconData icon;
  final String label;

  /// Overrides the segment color, as the Delete tool does.
  final Color? color;
}

List<_DockChoice<WorkspaceView>> _viewChoices() => [
  _DockChoice(
    WorkspaceView.trackList,
    Icons.view_list,
    tr('workspace-view-tracks'),
  ),
  _DockChoice(
    WorkspaceView.pianoRoll,
    Icons.piano,
    tr('workspace-view-piano-roll'),
  ),
  _DockChoice(WorkspaceView.mixer, Icons.tune, tr('workspace-view-mixer')),
  _DockChoice(
    WorkspaceView.source,
    Icons.group_work,
    tr('workspace-view-source'),
  ),
];

List<_DockChoice<ToolSelection>> _toolChoices(ColorScheme colors) => [
  _DockChoice(
    ToolSelection.panSelect,
    Icons.pan_tool_alt,
    tr('workspace-tool-pan-select'),
  ),
  _DockChoice(ToolSelection.slice, Icons.content_cut, tr('workspace-tool-cut')),
  _DockChoice(ToolSelection.draw, Icons.edit, tr('workspace-tool-draw')),
  _DockChoice(ToolSelection.move, Icons.open_with, tr('workspace-tool-move')),
  _DockChoice(
    ToolSelection.delete,
    Icons.delete,
    tr('workspace-tool-delete'),
    color: colors.error,
  ),
  _DockChoice(
    ToolSelection.select,
    Icons.crop_free,
    tr('workspace-tool-range-select'),
  ),
  _DockChoice(
    ToolSelection.resize,
    MdiIcons.arrowLeftRight,
    tr('workspace-tool-resize'),
  ),
];

/// The workspace controls, docked along the bottom edge: views on the left,
/// the transport in the middle, and the editing tools on the right, where the
/// thumbs rest on a phone held sideways.
///
/// Every view and tool is one tap away. The layout follows the width it is
/// given (see [DockDensity]).
class WorkspaceControlDock extends ConsumerWidget {
  const WorkspaceControlDock({super.key});

  void _navigateTo(WidgetRef ref, WorkspaceView view) {
    if (view != WorkspaceView.pianoRoll) {
      ref.read(workspaceStateProvider.notifier).navigateTo(view);
      return;
    }

    final selection = ref.read(trackListStateProvider);
    final trackId = selection.selectedTrackId;
    final clipId = selection.focusClipId;
    final track = trackId == null
        ? null
        : ref.read(projectProvider).value?.tracks[trackId];
    final clip = clipId == null
        ? null
        : track?.clips.where((clip) => clip.id == clipId).firstOrNull;

    if (clip?.source case UiClipSource_Midi(:final patternId)) {
      ref
          .read(pianoRollProvider.notifier)
          .openPattern(patternId, previewGeneratorId: track?.generatorId);
      ref.read(workspaceStateProvider.notifier).openPattern(patternId);
      return;
    }

    ref.read(pianoRollProvider.notifier).clearEditingPattern();
    ref.read(workspaceStateProvider.notifier).openPianoRoll();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    // Only the fields the dock shows, so other workspace changes do not rebuild it.
    final workspace = ref.watch(
      workspaceStateProvider.select(
        (state) =>
            (currentView: state.currentView, selectedTool: state.selectedTool),
      ),
    );
    final toolChoices = _toolChoices(colors);

    return LayoutBuilder(
      builder: (context, constraints) {
        final density = DockDensity.forWidth(constraints.maxWidth);
        final Widget views;
        final Widget tools;
        if (density == DockDensity.narrow) {
          views = _DockMenuButton<WorkspaceView>(
            tooltip: tr('workspace-dock-switch-view'),
            choices: _viewChoices(),
            selected: workspace.currentView,
            color: colors.primary,
            onSelected: (view) => _navigateTo(ref, view),
          );
          tools = _DockMenuButton<ToolSelection>(
            tooltip: tr('workspace-dock-pick-tool'),
            choices: toolChoices,
            selected: workspace.selectedTool,
            color: colors.secondary,
            onSelected: (tool) =>
                ref.read(workspaceStateProvider.notifier).selectTool(tool),
          );
        } else {
          views = _DockSegment<WorkspaceView>(
            choices: _viewChoices(),
            selected: workspace.currentView,
            color: colors.primary,
            labels: density == DockDensity.wide
                ? _SegmentLabels.all
                : _SegmentLabels.selected,
            onSelected: (view) => _navigateTo(ref, view),
          );
          tools = _DockSegment<ToolSelection>(
            choices: toolChoices,
            selected: workspace.selectedTool,
            color: colors.secondary,
            labels: density == DockDensity.wide
                ? _SegmentLabels.selected
                : _SegmentLabels.none,
            onSelected: (tool) =>
                ref.read(workspaceStateProvider.notifier).selectTool(tool),
          );
        }

        return Container(
          height: kControlDockHeight,
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              views,
              const SizedBox(width: 12),
              Expanded(
                // Shrinks rather than overflows when a translation runs long.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _DockTransport(density: density),
                ),
              ),
              const SizedBox(width: 12),
              tools,
            ],
          ),
        );
      },
    );
  }
}

enum _SegmentLabels { all, selected, none }

/// A row of mutually exclusive choices in one rounded track.
class _DockSegment<T> extends StatelessWidget {
  const _DockSegment({
    required this.choices,
    required this.selected,
    required this.color,
    required this.labels,
    required this.onSelected,
  });

  final List<_DockChoice<T>> choices;
  final T selected;
  final Color color;
  final _SegmentLabels labels;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final choice in choices)
            _segmentButton(context, choice, choice.value == selected),
        ],
      ),
    );
  }

  Widget _segmentButton(
    BuildContext context,
    _DockChoice<T> choice,
    bool isSelected,
  ) {
    final colors = Theme.of(context).colorScheme;
    final accent = choice.color ?? color;
    final foreground = isSelected ? accent : colors.onSurfaceVariant;
    final showLabel = switch (labels) {
      _SegmentLabels.all => true,
      _SegmentLabels.selected => isSelected,
      _SegmentLabels.none => false,
    };
    return Tooltip(
      message: choice.label,
      child: Semantics(
        selected: isSelected,
        button: true,
        label: choice.label,
        child: InkWell(
          onTap: () => onSelected(choice.value),
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 42,
            constraints: const BoxConstraints(minWidth: 38),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(choice.icon, size: 20, color: foreground),
                if (showLabel) ...[
                  const SizedBox(width: 6),
                  Text(
                    choice.label,
                    maxLines: 1,
                    style: TextStyle(color: foreground, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The current choice as one button that opens every choice above it. Used
/// where a whole segment does not fit.
class _DockMenuButton<T> extends StatelessWidget {
  const _DockMenuButton({
    required this.tooltip,
    required this.choices,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  final String tooltip;
  final List<_DockChoice<T>> choices;
  final T selected;
  final Color color;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current =
        choices.where((choice) => choice.value == selected).firstOrNull ??
        choices.first;
    final accent = current.color ?? color;
    return PopupMenuButton<T>(
      tooltip: tooltip,
      position: PopupMenuPosition.over,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final choice in choices)
          PopupMenuItem<T>(
            value: choice.value,
            child: ListTile(
              leading: Icon(choice.icon, color: choice.color ?? color),
              title: Text(choice.label),
              selected: choice.value == selected,
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(current.icon, size: 20, color: accent),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 88),
              child: Text(
                current.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurface, fontSize: 12),
              ),
            ),
            Icon(Icons.arrow_drop_up, size: 18, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// The middle of the dock: position readout, loop, play and stop, and the
/// workspace toggles, which sit behind "more" unless the dock is wide.
class _DockTransport extends ConsumerWidget {
  const _DockTransport({required this.density});

  final DockDensity density;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isLooping = ref.watch(
      transportProvider.select((s) => s.value?.isLooping ?? false),
    );
    // _TransportReadout shows the moving position; the dock only needs the play state.
    final isSongPlaying = ref.watch(
      transportPositionStreamProvider.select((position) {
        final pos = position.value;
        return pos != null && pos.isPlaying && !pos.isPatternMode;
      }),
    );
    final wide = density == DockDensity.wide;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DockReadout(full: wide),
        const SizedBox(width: 10),
        _RoundToggle(
          tooltip: tr('workspace-transport-loop'),
          icon: Icons.loop,
          color: colors.tertiary,
          isActive: isLooping,
          onTap: () => ref.read(transportProvider.notifier).toggleLoop(),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: isSongPlaying
              ? tr('workspace-transport-pause')
              : tr('workspace-transport-play'),
          child: Material(
            color: colors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _togglePlayback(ref),
              child: SizedBox.square(
                dimension: 46,
                child: Icon(
                  isSongPlaying ? Icons.pause : Icons.play_arrow,
                  color: colors.onPrimary,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _RoundToggle(
          tooltip: tr('workspace-transport-stop'),
          icon: Icons.stop,
          color: colors.error,
          isActive: false,
          onTap: () => ref.read(transportProvider.notifier).stop(),
        ),
        const SizedBox(width: 10),
        if (wide)
          const _WorkspaceToggles()
        else ...[
          const _WorkspaceTogglesMenu(),
          // The info bar that shows background jobs is hidden below wide.
          const BackgroundJobsIndicator(),
        ],
      ],
    );
  }

  void _togglePlayback(WidgetRef ref) {
    // The FFI call can throw; report it instead of crashing the gesture.
    try {
      final ctx = ref.read(projectProvider.notifier).dawContext;
      togglePlaybackWithMode(
        ctx: ctx,
        playbackMode: const PlaybackModeDto.song(),
      );
    } catch (e) {
      AppLogger.error("Failed to toggle playback: $e");
      ref.read(notificationProvider.notifier).error(e);
    }
  }
}

/// A round transport or workspace toggle.
class _RoundToggle extends StatelessWidget {
  const _RoundToggle({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        toggled: isActive,
        button: true,
        child: Material(
          color: isActive
              ? color.withValues(alpha: 0.24)
              : colors.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: 38,
              child: Icon(
                icon,
                size: 20,
                color: isActive ? color : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Snap, follow, metronome and keyboard state, and their toggles.
typedef _ToggleSpec = ({
  String label,
  IconData icon,
  bool isActive,
  VoidCallback onToggle,
});

List<_ToggleSpec> _workspaceToggles(WidgetRef ref) {
  final workspace = ref.watch(
    workspaceStateProvider.select(
      (state) => (
        snapToGrid: state.snapToGrid,
        followPlayhead: state.followPlayhead,
        showMidiKeyboard: state.floatingMidiKeyboardState.showed,
      ),
    ),
  );
  final metronome = ref.watch(
    transportProvider.select((s) => s.value?.isMetronomeActive ?? false),
  );
  final workspaceNotifier = ref.read(workspaceStateProvider.notifier);
  return [
    (
      label: tr('workspace-snap-to-grid'),
      icon: Icons.grid_on,
      isActive: workspace.snapToGrid,
      onToggle: workspaceNotifier.toggleSnapToGrid,
    ),
    (
      label: tr('workspace-follow-playhead'),
      icon: Icons.keyboard_double_arrow_right,
      isActive: workspace.followPlayhead,
      onToggle: workspaceNotifier.toggleFollowPlayhead,
    ),
    (
      label: tr('workspace-metronome'),
      icon: MdiIcons.metronome,
      isActive: metronome,
      onToggle: () =>
          ref.read(transportProvider.notifier).toggleMetronomeActive(),
    ),
    (
      label: tr('workspace-midi-keyboard'),
      icon: Icons.piano,
      isActive: workspace.showMidiKeyboard,
      onToggle: workspaceNotifier.toggleFloatingMidiKeyboard,
    ),
  ];
}

/// The workspace toggles in line, for a wide dock.
class _WorkspaceToggles extends ConsumerWidget {
  const _WorkspaceToggles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final toggle in _workspaceToggles(ref)) ...[
          const SizedBox(width: 6),
          _RoundToggle(
            tooltip: toggle.label,
            icon: toggle.icon,
            color: colors.secondary,
            isActive: toggle.isActive,
            onTap: toggle.onToggle,
          ),
        ],
      ],
    );
  }
}

/// The workspace toggles behind one "more" button, for compact docks.
class _WorkspaceTogglesMenu extends ConsumerWidget {
  const _WorkspaceTogglesMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final toggles = _workspaceToggles(ref);
    final anyActive = toggles.any((toggle) => toggle.isActive);
    return PopupMenuButton<int>(
      tooltip: tr('workspace-dock-more'),
      position: PopupMenuPosition.over,
      onSelected: (index) => toggles[index].onToggle(),
      itemBuilder: (context) => [
        for (final (index, toggle) in toggles.indexed)
          CheckedPopupMenuItem<int>(
            value: index,
            checked: toggle.isActive,
            child: Row(
              children: [
                Icon(toggle.icon, size: 18, color: colors.secondary),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    toggle.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: SizedBox.square(
        dimension: 38,
        child: Icon(
          Icons.more_horiz,
          color: anyActive ? colors.secondary : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Position and tempo. A full readout shows bar, beat, time, tempo and
/// signature; a short one shows time and tempo.
class _DockReadout extends StatelessWidget {
  const _DockReadout({required this.full});

  final bool full;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dividerWidth = full ? 20.0 : 10.0;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TransportReadout(full: full, dividerWidth: dividerWidth),
          VerticalDivider(color: colors.outlineVariant, width: dividerWidth),
          const SizedBox(width: 48, child: BpmControl()),
          if (full) ...[
            VerticalDivider(color: colors.outlineVariant, width: dividerWidth),
            _ReadoutField(
              label: tr('workspace-readout-signature'),
              value: '4/4',
              width: 36,
            ),
          ],
        ],
      ),
    );
  }
}

/// One labelled readout value.
class _ReadoutField extends StatelessWidget {
  const _ReadoutField({
    required this.label,
    required this.value,
    required this.width,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            // Translated labels can be longer than the English abbreviations.
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(color: colors.primary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// The bar, beat, and time fields, which change on every position update. Kept in their own
/// widget so playback rebuilds only these and not the whole dock.
class _TransportReadout extends ConsumerWidget {
  const _TransportReadout({required this.full, required this.dividerWidth});

  /// Whether bar and beat are shown next to the time.
  final bool full;
  final double dividerWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final pos = ref.watch(transportPositionStreamProvider).value;
    final bar = pos?.bar ?? 0;
    final beat = pos?.beat ?? 0;
    final samples = pos?.samples ?? 0;
    final sampleRate = pos?.sampleRate ?? 44100;

    final time = _ReadoutField(
      label: tr('workspace-readout-time'),
      value: formatTimeFromSamples(samples, sampleRate),
      width: 72,
    );
    if (!full) return time;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ReadoutField(
          label: tr('workspace-readout-bar'),
          value: bar.toString(),
          width: 36,
        ),
        const SizedBox(width: 10),
        _ReadoutField(
          label: tr('workspace-readout-beat'),
          value: beat.toString(),
          width: 36,
        ),
        VerticalDivider(color: colors.outlineVariant, width: dividerWidth),
        time,
      ],
    );
  }
}

/// Phase of a tempo drag on [BpmControl]. A drag only previews the tempo; the
/// engine receives one change, when the drag is released.
sealed class _TempoDrag {
  const _TempoDrag();
}

/// No drag in progress; the control shows the transport tempo.
final class _TempoDragIdle extends _TempoDrag {
  const _TempoDragIdle();
}

/// The pointer is dragging. [preview] is shown but not sent yet.
final class _TempoDragActive extends _TempoDrag {
  const _TempoDragActive({required this.start, required this.preview});

  final double start;
  final double preview;
}

/// The released tempo is being stored. New edits wait until it lands, so
/// requests never overlap.
final class _TempoDragCommitting extends _TempoDrag {
  const _TempoDragCommitting(this.bpm);

  final double bpm;
}

class BpmControl extends ConsumerStatefulWidget {
  const BpmControl({super.key});

  static const double minBpm = 10.0;
  static const double maxBpm = 999.0;

  @override
  ConsumerState<BpmControl> createState() => _BpmControlState();
}

class _BpmControlState extends ConsumerState<BpmControl> {
  _TempoDrag _drag = const _TempoDragIdle();

  double _clamp(double bpm) => bpm.clamp(BpmControl.minBpm, BpmControl.maxBpm);

  /// Sends a tempo outside a drag, such as from the wheel or the exact value
  /// dialog. Ignored while a drag owns the tempo.
  void _setBpm(double bpm) {
    if (_drag is! _TempoDragIdle) return;
    ref.read(transportProvider.notifier).setBpm(_clamp(bpm));
  }

  void _startDrag(double currentBpm) {
    if (_drag is! _TempoDragIdle) return;
    setState(
      () => _drag = _TempoDragActive(start: currentBpm, preview: currentBpm),
    );
  }

  void _updateDrag(double delta) {
    final drag = _drag;
    if (drag is! _TempoDragActive) return;
    final preview = _clamp(drag.preview + delta * -0.5);
    if (preview == drag.preview) return;
    setState(
      () => _drag = _TempoDragActive(start: drag.start, preview: preview),
    );
  }

  Future<void> _endDrag() async {
    final drag = _drag;
    if (drag is! _TempoDragActive) return;
    if (drag.preview == drag.start) {
      setState(() => _drag = const _TempoDragIdle());
      return;
    }
    setState(() => _drag = _TempoDragCommitting(drag.preview));
    await ref.read(transportProvider.notifier).setBpm(drag.preview);
    if (mounted) setState(() => _drag = const _TempoDragIdle());
  }

  void _cancelDrag() {
    if (_drag is! _TempoDragActive) return;
    setState(() => _drag = const _TempoDragIdle());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final transportBpm = ref.watch(
      transportProvider.select((s) => s.value?.state?.bpm ?? 120.0),
    );
    final bpm = switch (_drag) {
      _TempoDragIdle() => transportBpm,
      _TempoDragActive(:final preview) => preview,
      _TempoDragCommitting(bpm: final committing) => committing,
    };
    final isSmallScreen = MediaQuery.sizeOf(context).width < 600;

    return FineGrainedInputWrapper<double>(
      value: bpm,
      min: BpmControl.minBpm,
      max: BpmControl.maxBpm,
      step: 1.0,
      onChanged: _setBpm,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final dy = event.scrollDelta.dy;
            final change = dy < 0 ? 0.1 : -0.1;
            _setBpm(bpm + change);
          }
        },
        child: GestureDetector(
          onVerticalDragStart: (_) => _startDrag(bpm),
          onVerticalDragUpdate: (details) => _updateDrag(details.primaryDelta!),
          onVerticalDragEnd: (_) => _endDrag(),
          onVerticalDragCancel: _cancelDrag,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: Container(
              color: Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "BPM",
                    maxLines: 1,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: isSmallScreen ? 6 : 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // One line that shrinks, like the other readout fields.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      bpm.toStringAsFixed(1),
                      maxLines: 1,
                      style: TextStyle(
                        color: colors.tertiary,
                        fontSize: isSmallScreen ? 11 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
