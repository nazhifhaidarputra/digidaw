import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/recording_state.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/utils/color.dart';
import 'package:karbeat/core/widgets/color_picker_dialog.dart';
// import 'package:karbeat/core/utils/color.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/math.dart';
import 'package:karbeat/core/widgets/channel_toggle_button.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/core/widgets/db_level_meter.dart';
import 'package:karbeat/features/plugins/services/plugin_ui_launcher.dart';
import 'package:karbeat/features/plugins/widgets/plugin_browser_dialog.dart';
import 'package:karbeat/features/setting/services/host_devices_settings_provider.dart';
import 'package:karbeat/features/source/services/source_actions.dart';
import 'package:karbeat/features/track/view/plugin_automation_parameter_dialog.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';

/// Track identity, controls, metering, and track-level context actions.
class TrackHeader extends ConsumerWidget {
  final int trackId;
  final double itemHeight;
  final VoidCallback onDragStarted;
  final ValueChanged<bool> onDragEnded;

  /// Whether this track is the one shown in the mixer channel panel.
  final bool isSelected;

  /// Called when the header body is tapped.
  final VoidCallback? onSelect;

  const TrackHeader({
    super.key,
    required this.trackId,
    required this.itemHeight,
    required this.onDragStarted,
    required this.onDragEnded,
    this.isSelected = false,
    this.onSelect,
  });

  Color _getContrastColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
  }

  IconData _getTrackIcon(UiTrackType type) {
    switch (type) {
      case UiTrackType.audio:
        return Icons.graphic_eq;
      case UiTrackType.midi:
        return Icons.piano;
      case UiTrackType.automation:
        return Icons.show_chart;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    // Select only this track (and its generator below) so unrelated project
    // publishes don't rebuild the header. The meter magnitude is watched by
    // the [_TrackLevelMeter] leaf, not here, so meter ticks don't rebuild it.
    final track = ref.watch(
      projectProvider.select((s) => s.value?.tracks[trackId]),
    );
    final generatorInstanceType = ref.watch(
      projectProvider.select((s) {
        final generatorId = s.value?.tracks[trackId]?.generatorId;
        return generatorId == null
            ? null
            : s.value?.generators[generatorId]?.instanceType;
      }),
    );

    final channelFlags = ref.watch(
      projectProvider.select((s) {
        final channel = s.value?.mixer.channels[trackId];
        return (mute: channel?.mute ?? false, solo: channel?.solo ?? false);
      }),
    );
    final isMuted = channelFlags.mute;
    final isSoloed = channelFlags.solo;
    final collapsed = ref.watch(
      trackListStateProvider.select(
        (s) => s.collapsedTrackIds.contains(trackId),
      ),
    );
    void toggleCollapsed() => ref
        .read(trackListStateProvider.notifier)
        .toggleTrackCollapsed(trackId: trackId);

    final take = ref.watch(
      recordingProvider.select((state) => state.takes[trackId]),
    );
    final inputChannels =
        ref.watch(
          hostDevicesSettingsProvider.select(
            (state) => state.runtimeSettings?.actualInput?.channels,
          ),
        ) ??
        2;

    if (track == null) return const SizedBox();
    final isAudioTrack = track.trackType == UiTrackType.audio;

    final trackColor = track.color.fromRGBorRGBAtoColor();
    final trackForeground = _getContrastColor(trackColor);
    final generatorId = track.generatorId;
    final generatorPlugin = switch (generatorInstanceType) {
      UiGeneratorInstanceType_Plugin(:final field0) => field0,
      _ => null,
    };

    return ContextMenuWrapper(
      title: track.name,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('track-info-name', {'name': track.name}),
            style: TextStyle(color: colors.onSurface, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            tr('track-info-type', {'type': track.trackType.name}),
            style: TextStyle(color: colors.onSurface, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            tr('mixer-effect-id', {'id': track.id}),
            style: TextStyle(color: colors.onSurface, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                tr('mixer-color'),
                style: TextStyle(color: colors.onSurface, fontSize: 13),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: track.color.fromRGBorRGBAtoColor(),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (track.trackType == UiTrackType.midi &&
            generatorId != null &&
            generatorPlugin != null)
          DawContextAction(
            title: tr('track-go-to-plugin-screen'),
            icon: Icons.open_in_new,
            onTap: () async {
              await openPluginInterface(
                context: context,
                ref: ref,
                target: UiPluginTarget.generator(generatorId),
                registryId: generatorPlugin.registryId,
                instanceId: generatorId,
                pluginName: generatorPlugin.label,
              );
            },
          ),
        if (generatorId != null && generatorPlugin != null)
          DawContextAction(
            title: tr('track-rename-instrument'),
            icon: Icons.edit,
            onTap: () => renameGeneratorWithDialog(
              context,
              ref,
              generatorId,
              generatorPlugin,
            ),
          ),
        if (track.trackType == UiTrackType.midi)
          DawContextAction(
            title: tr('track-change-instrument'),
            icon: Icons.swap_horiz,
            onTap: () => showPluginBrowserDialog(
              context: context,
              pluginType: KarbeatPluginType.generator,
              actionLabel: tr('track-replace'),
              onAdd: (plugin) => ref
                  .read(trackListStateProvider.notifier)
                  .replaceTrackGenerator(
                    trackId: trackId,
                    registryId: plugin.registryId,
                  ),
            ),
          ),
        if (track.generatorId != null)
          DawContextAction(
            title: tr('track-add-automation-on'),
            icon: Icons.timeline,
            onTap: () => showPluginAutomationParameterDialog(
              context: context,
              target: UiPluginTarget.generator(track.generatorId!),
              ownerName: track.name,
            ),
          ),
        if (isAudioTrack) ...[
          DawContextAction.submenu(
            title: tr('track-input-channel'),
            icon: Icons.input,
            subtitle: _inputLabel(track.input),
            children: [
              for (final input in _inputChoices(track.input, inputChannels))
                DawContextAction(
                  title: _inputLabel(input),
                  icon: input == track.input ? Icons.check : null,
                  onTap: () => ref
                      .read(trackListStateProvider.notifier)
                      .setTrackInput(trackId, input),
                ),
            ],
          ),
          DawContextAction(
            title: track.input.monitor
                ? tr('track-monitor-stop')
                : tr('track-monitor-start'),
            icon: track.input.monitor ? Icons.hearing_disabled : Icons.hearing,
            onTap: () => ref
                .read(trackListStateProvider.notifier)
                .setTrackInput(
                  trackId,
                  track.input.copyWith(monitor: !track.input.monitor),
                ),
          ),
        ],
        DawContextAction(
          title: collapsed ? tr('track-lane-expand') : tr('track-lane-shrink'),
          icon: collapsed ? Icons.unfold_more : Icons.unfold_less,
          onTap: toggleCollapsed,
        ),
        DawContextAction(
          title: tr('common-rename'),
          icon: Icons.edit,
          onTap: () {
            final textController = TextEditingController(text: track.name);

            showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(tr('track-rename-track')),
                content: TextField(
                  controller: textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: tr('track-new-track-name'),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    Navigator.pop(ctx, value);
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr('common-cancel')),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, textController.text),
                    child: Text(tr('common-rename')),
                  ),
                ],
              ),
            ).then((newName) {
              if (newName != null &&
                  newName.trim().isNotEmpty &&
                  newName != track.name) {
                AppLogger.info(
                  "Rename track requested for ID: ${track.id} with name [${newName.trim()}]",
                );
                ref
                    .read(trackListStateProvider.notifier)
                    .changeTrackName(trackId, newName.trim());
              }
            });
          },
        ),
        DawContextAction(
          title: tr('track-change-color'),
          icon: Icons.color_lens,
          onTap: () {
            final currentColor = track.color.fromRGBorRGBAtoColor();

            showColorPickerDialog(
              context,
              currentColor,
              title: tr('track-select-track-color'),
            ).then((selectedColor) {
              if (selectedColor != null &&
                  selectedColor.toARGB32() != currentColor.toARGB32()) {
                AppLogger.info(
                  "Change color requested for track ID: ${track.id}",
                );
                ref
                    .read(trackListStateProvider.notifier)
                    .changeTrackColor(trackId, selectedColor);
              }
            });
          },
        ),
        DawContextAction(
          title: tr('track-move-up'),
          icon: Icons.arrow_upward,
          onTap: () async {
            AppLogger.info("Move Up requested for track ID: ${track.id}");
            ref
                .read(trackListStateProvider.notifier)
                .handleUpdateTrackOrder(
                  trackId: trackId,
                  newIdx: (track.orderIdx - 1).complyU32(),
                );
          },
        ),
        DawContextAction(
          title: tr('track-move-down'),
          icon: Icons.arrow_downward,
          onTap: () async {
            AppLogger.info("Move Down requested for track ID: ${track.id}");
            ref
                .read(trackListStateProvider.notifier)
                .handleUpdateTrackOrder(
                  trackId: trackId,
                  newIdx: (track.orderIdx + 1).complyU32(),
                );
          },
        ),
        DawContextAction(
          title: tr('track-delete-track'),
          icon: Icons.delete,
          isDestructive: true,
          onTap: () async {
            AppLogger.info("Delete track requested for ID: ${track.id}");
            await ref
                .read(trackListStateProvider.notifier)
                .deleteTrack(trackId: trackId);
          },
        ),
      ],
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelect,
        child: SizedBox(
          height: itemHeight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: trackColor,
              border: Border(
                bottom: BorderSide(color: colors.outlineVariant, width: 1),
                right: BorderSide(color: colors.outlineVariant, width: 1),
              ),
            ),
            foregroundDecoration: isSelected
                ? BoxDecoration(
                    border: Border.all(color: trackForeground, width: 2),
                  )
                : null,
            // The meter runs along the bottom edge, from border to border.
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: collapsed ? 6 : 10),
                    child: Row(
                      children: [
                        Draggable<int>(
                          data: trackId,
                          dragAnchorStrategy: pointerDragAnchorStrategy,
                          rootOverlay: true,
                          onDragStarted: onDragStarted,
                          onDragEnd: (details) =>
                              onDragEnded(details.wasAccepted),
                          feedback: Material(
                            color: Colors.transparent,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.drag_indicator,
                                  size: 18,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: const SizedBox(width: 20),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: Semantics(
                              label: tr('track-reorder', {'track': track.name}),
                              button: true,
                              child: SizedBox(
                                width: 20,
                                child: Icon(
                                  Icons.drag_indicator,
                                  size: 16,
                                  color: trackForeground.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        LaneCollapseToggle(
                          collapsed: collapsed,
                          color: trackForeground.withValues(alpha: 0.72),
                          onPressed: toggleCollapsed,
                        ),
                        Expanded(
                          child: collapsed
                              ? Text(
                                  track.name,
                                  style: TextStyle(
                                    color: trackForeground,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Row(
                                  children: [
                                    Icon(
                                      _getTrackIcon(track.trackType),
                                      color: trackForeground.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.name,
                                            style: TextStyle(
                                              color: trackForeground,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            track.trackType.name.toUpperCase(),
                                            style: TextStyle(
                                              color: trackForeground.withValues(
                                                alpha: 0.8,
                                              ),
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        if (!collapsed) ...[
                          const SizedBox(width: 8),
                          if (isAudioTrack) ...[
                            _ScaleDownColumn(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  ChannelToggleButton(
                                    label: 'R',
                                    tooltip: switch (take) {
                                      null => tr('track-arm'),
                                      TrackTake(startSamples: null) => tr(
                                        'track-armed',
                                      ),
                                      _ => tr('track-recording-active'),
                                    },
                                    isActive: take != null,
                                    // A take waiting for playback shows lighter than one recording.
                                    activeColor: take?.startSamples == null
                                        ? colors.error.withValues(alpha: 0.5)
                                        : colors.error,
                                    onTap: () => ref
                                        .read(recordingProvider.notifier)
                                        .toggleTrack(trackId),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          _ScaleDownColumn(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ChannelToggleButton(
                                  label: 'M',
                                  tooltip: isMuted
                                      ? tr('mixer-unmute')
                                      : tr('mixer-mute'),
                                  isActive: isMuted,
                                  activeColor: colors.error,
                                  onTap: () => ref
                                      .read(mixerStateProvider.notifier)
                                      .setMixerChannelParam(
                                        trackId: trackId,
                                        param: UiMixerChannelParams.mute(
                                          !isMuted,
                                        ),
                                      ),
                                ),
                                ChannelToggleButton(
                                  label: 'S',
                                  tooltip: isSoloed
                                      ? tr('mixer-unsolo')
                                      : tr('mixer-solo'),
                                  isActive: isSoloed,
                                  activeColor: colors.tertiary,
                                  onTap: () => ref
                                      .read(mixerStateProvider.notifier)
                                      .setMixerChannelParam(
                                        trackId: trackId,
                                        param: UiMixerChannelParams.solo(
                                          !isSoloed,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!collapsed)
                  SizedBox(
                    height: _meterHeight,
                    child: _TrackLevelMeter(
                      trackId: trackId,
                      trackName: track.name,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thickness of the output meter along the bottom of the header.
const double _meterHeight = 6;

/// A column of header buttons, 50 px tall when the header has room and scaled
/// down to fit a shorter header.
class _ScaleDownColumn extends StatelessWidget {
  const _ScaleDownColumn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(height: 50, child: child),
    );
  }
}

/// Small shrink/expand button shared by track and automation lane headers.
/// Display name of a track input, with channels counted from 1.
String _inputLabel(UiTrackInput input) {
  final first = input.firstChannel + 1;
  return input.channels >= 2
      ? tr('track-input-stereo', {'first': first, 'second': first + 1})
      : tr('track-input-mono', {'channel': first});
}

/// Inputs a track can take from a device with [deviceChannels] channels: each
/// channel alone, then each odd/even pair. [current] keeps its monitor flag.
List<UiTrackInput> _inputChoices(UiTrackInput current, int deviceChannels) {
  final channels = deviceChannels.clamp(1, 64);
  return [
    for (var channel = 0; channel < channels; channel++)
      current.copyWith(firstChannel: channel, channels: 1),
    for (var channel = 0; channel + 1 < channels; channel += 2)
      current.copyWith(firstChannel: channel, channels: 2),
  ];
}

/// The header's output meter. It is the only part of the header that watches
/// the meter magnitude, so a telemetry tick rebuilds this leaf alone.
class _TrackLevelMeter extends ConsumerWidget {
  const _TrackLevelMeter({required this.trackId, required this.trackName});

  final int trackId;
  final String trackName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final magnitude = ref.watch(
      mixerStateProvider.select(
        (state) => state.trackMagnitudes[trackId] ?? 0.0,
      ),
    );
    return Semantics(
      label: tr('track-output-level', {'trackName': trackName}),
      value: '${magnitudeToDb(magnitude).toStringAsFixed(1)} dB',
      child: DbLevelMeter(magnitude: magnitude, axis: Axis.horizontal),
    );
  }
}

class LaneCollapseToggle extends StatelessWidget {
  const LaneCollapseToggle({
    super.key,
    required this.collapsed,
    required this.color,
    required this.onPressed,
  });

  final bool collapsed;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? tr('track-lane-expand') : tr('track-lane-shrink'),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 20,
          height: 20,
          child: Icon(
            collapsed ? Icons.unfold_more : Icons.unfold_less,
            size: 14,
            color: color,
          ),
        ),
      ),
    );
  }
}

class HeaderResizeHandle extends StatefulWidget {
  const HeaderResizeHandle({
    super.key,
    required this.onDelta,
    required this.onReset,
    this.hitExtent = 6.0,
  });

  /// Positive values grow the header, negative values shrink it.
  final ValueChanged<double> onDelta;

  /// Double-click resets the height to the default.
  final VoidCallback onReset;

  /// Height of the draggable strip along the bottom border.
  final double hitExtent;

  @override
  State<HeaderResizeHandle> createState() => HeaderResizeHandleState();
}

class HeaderResizeHandleState extends State<HeaderResizeHandle> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highlight = _hovering || _dragging;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => setState(() => _dragging = true),
        onVerticalDragEnd: (_) => setState(() => _dragging = false),
        onVerticalDragCancel: () => setState(() => _dragging = false),
        onVerticalDragUpdate: (details) => widget.onDelta(details.delta.dy),
        onDoubleTap: widget.onReset,
        child: Container(
          height: widget.hitExtent,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 1,
                color: highlight
                    ? colors.primary
                    : colors.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
