import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:karbeat/app/providers/app_state.dart';
import 'package:karbeat/core/utils/color.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/math.dart';
import 'package:karbeat/core/widgets/context_menu.dart';
import 'package:karbeat/features/track/services/general_track_service.dart';
import 'package:karbeat/src/rust/api/project.dart';

class TrackHeader extends ConsumerWidget {
  final int trackId;
  final double itemHeight;

  const TrackHeader({required this.trackId, required this.itemHeight});

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
    return showDialog<Color>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Select Track Color"),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: dawColors.map((color) {
                final isSelected = currentColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: isSelected ? 3 : 0,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: color.withAlpha(100),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only rebuilds this specific header if the track's name/color/type changes
    final track = ref.watch(
      globalStateProvider.select((s) => s.tracks[trackId]),
    );

    if (track == null) return const SizedBox();

    return ContextMenuWrapper(
      title: track.name,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Name: ${track.name}",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            "Type: ${track.trackType.name.toUpperCase()}",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            "ID: ${track.id}",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "Color: ",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: track.color.toColor(),
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
                    .read(globalStateProvider)
                    .changeTrackName(trackId, newName.trim());
              }
            });
          },
        ),
        DawContextAction(
          title: "Change Color",
          icon: Icons.color_lens,
          onTap: () {
            final currentColor = track.color.toColor();

            _showColorPickerDialog(context, currentColor).then((selectedColor) {
              if (selectedColor != null &&
                  selectedColor.toARGB32() != currentColor.toARGB32()) {
                AppLogger.info(
                  "Change color requested for track ID: ${track.id}",
                );
                ref
                    .read(globalStateProvider)
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
            await handleUpdateTrackOrder(
              ref: ref,
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
            await handleUpdateTrackOrder(
              ref: ref,
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
            ref.read(globalStateProvider).deleteTrack(trackId);
          },
        ),
      ],
      child: SizedBox(
        height: itemHeight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: track.color.toColor(),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade400, width: 1),
              right: BorderSide(color: Colors.grey.shade400, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(_getTrackIcon(track.trackType), color: Colors.grey.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.name,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "ID: ${track.id} | ${track.trackType.name.toUpperCase()}",
                      style: TextStyle(
                        color: _getContrastColor(track.color.toColor()),
                        // color: Colors.grey.shade600, // use inverse color of track color for better contrast
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
                    child: const Icon(
                      Icons.mic_off,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {},
                    child: const Icon(
                      Icons.volume_up,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
