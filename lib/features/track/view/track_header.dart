import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/core/utils/color.dart';
// import 'package:karbeat/core/utils/color.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/math.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/core/widgets/db_level_meter.dart';
import 'package:karbeat/src/rust/api/project.dart';

class TrackHeader extends ConsumerWidget {
  final int trackId;
  final double itemHeight;
  final VoidCallback onDragStarted;
  final ValueChanged<bool> onDragEnded;

  const TrackHeader({
    super.key,
    required this.trackId,
    required this.itemHeight,
    required this.onDragStarted,
    required this.onDragEnded,
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

  Future<Color?> _showColorPickerDialog(
    BuildContext context,
    Color currentColor,
  ) {
    var selectedColor = currentColor;

    return showDialog<Color>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Select Track Color"),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: ColorPicker(
                  color: selectedColor,
                  onColorChanged: (color) {
                    setDialogState(() => selectedColor = color);
                  },
                  pickersEnabled: const {
                    ColorPickerType.both: true,
                    ColorPickerType.primary: false,
                    ColorPickerType.accent: false,
                    ColorPickerType.bw: true,
                    ColorPickerType.custom: false,
                    ColorPickerType.customSecondary: false,
                    ColorPickerType.wheel: true,
                  },
                  enableShadesSelection: true,
                  enableOpacity: true,
                  showMaterialName: true,
                  showColorName: true,
                  showColorCode: true,
                  showEditIconButton: true,
                  colorCodeHasColor: true,
                  wheelDiameter: 220,
                  width: 36,
                  height: 36,
                  borderRadius: 18,
                  hasBorder: true,
                  heading: Text(
                    'Choose a color',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subheading: Text(
                    'Choose a shade',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  wheelSubheading: Text(
                    'Fine tune',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  opacitySubheading: Text(
                    'Opacity',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(selectedColor),
                child: const Text("Select"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    // Only rebuilds this specific header if the track's name/color/type changes
    final track = ref.watch(projectProvider).value?.tracks[trackId];
    final magnitude = ref.watch(
      mixerStateProvider.select(
        (state) => state.trackMagnitudes[trackId] ?? 0.0,
      ),
    );

    if (track == null) return const SizedBox();

    final trackColor = track.color.fromRGBorRGBAtoColor();
    final trackForeground = _getContrastColor(trackColor);

    return ContextMenuWrapper(
      title: track.name,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Name: ${track.name}",
            style: TextStyle(color: colors.onSurface, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            "Type: ${track.trackType.name.toUpperCase()}",
            style: TextStyle(color: colors.onSurface, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            "ID: ${track.id}",
            style: TextStyle(color: colors.onSurface, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                "Color: ",
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
        DawContextAction(
          title: "Rename",
          icon: Icons.edit,
          onTap: () {
            final textController = TextEditingController(text: track.name);

            showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Rename Track"),
                content: TextField(
                  controller: textController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: "New track name",
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    Navigator.pop(ctx, value);
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, textController.text),
                    child: const Text("Rename"),
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
          title: "Change Color",
          icon: Icons.color_lens,
          onTap: () {
            final currentColor = track.color.fromRGBorRGBAtoColor();

            _showColorPickerDialog(context, currentColor).then((selectedColor) {
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
          title: "Move Up",
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
          title: "Move Down",
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
          title: "Delete Track",
          icon: Icons.delete,
          isDestructive: true,
          onTap: () {
            AppLogger.info("Delete track requested for ID: ${track.id}");
            ref
                .read(trackListStateProvider.notifier)
                .deleteTrack(trackId: trackId);
          },
        ),
      ],
      child: SizedBox(
        height: itemHeight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: trackColor,
            border: Border(
              bottom: BorderSide(color: colors.outlineVariant, width: 1),
              right: BorderSide(color: colors.outlineVariant, width: 1),
            ),
          ),
          child: Row(
            children: [
              Draggable<int>(
                data: trackId,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                rootOverlay: true,
                onDragStarted: onDragStarted,
                onDragEnd: (details) => onDragEnded(details.wasAccepted),
                feedback: Material(
                  color: Colors.transparent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 6),
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
                    label: 'Reorder ${track.name}',
                    button: true,
                    child: SizedBox(
                      width: 20,
                      child: Icon(
                        Icons.drag_indicator,
                        size: 16,
                        color: trackForeground.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _getTrackIcon(track.trackType),
                            color: trackForeground.withValues(alpha: 0.72),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  "ID: ${track.id} | ${track.trackType.name.toUpperCase()}",
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
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () {},
                                child: Icon(
                                  Icons.mic_off,
                                  size: 16,
                                  color: trackForeground.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () {},
                                child: Icon(
                                  Icons.volume_up,
                                  size: 16,
                                  color: trackForeground.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 7,
                      child: Semantics(
                        label: '${track.name} output level',
                        value:
                            '${magnitudeToDb(magnitude).toStringAsFixed(1)} dB',
                        child: DbLevelMeter(
                          magnitude: magnitude,
                          axis: Axis.horizontal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
